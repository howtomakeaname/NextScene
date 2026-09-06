// OpenHarmony platform implementation for krkr2-next.
//
// Mirrors environ/linux/Platform.cpp (the shared POSIX parts) and the
// android/AndroidUtils.cpp semantics, adapted to the OHOS app sandbox:
//  - writable paths are injected via env vars (KRKR_FILES_DIR / KRKR_HOME)
//    by the Flutter side before the engine boots (Dart FFI setenv)
//  - message boxes are no-ops (Flutter owns the UI layer)
//  - logging goes to hilog so `hdc hilog` surfaces engine diagnostics

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/sysinfo.h>

#include <dlfcn.h>
#include <malloc.h>

#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "EventIntf.h"
#include "Platform.h"
#include "StorageImpl.h"
#include "SysInitImpl.h"
#include "posix_memstat.h"

#include "krkr_egl_context.h"

#include <EGL/egl.h>
#include <hilog/log.h>

static void OHOSLog(LogLevel level, const char *str) {
    static constexpr unsigned int KRKR_DOMAIN = 0x0206;
    (void)OH_LOG_Print(LOG_APP, level, KRKR_DOMAIN, "krkr2", "%{public}s", str);
}

void TVPPrintLog(const char *str) { OHOSLog(LOG_INFO, str); }

void TVPGetMemoryInfo(TVPMemoryInfo &m) {
    /* to read /proc/meminfo */
    FILE *meminfo;
    char buffer[100] = { 0 };
    char *end;

    meminfo = fopen("/proc/meminfo", "r");
    if(!meminfo)
        return;

    static const char pszMemFree[] = "MemFree:", pszMemTotal[] = "MemTotal:",
                      pszSwapTotal[] = "SwapTotal:",
                      pszSwapFree[] = "SwapFree:";

    while(fgets(buffer, sizeof(buffer), meminfo)) {
        if(strstr(buffer, pszMemFree) == buffer) {
            m.MemFree = strtol(buffer + sizeof(pszMemFree), &end, 10);
        } else if(strstr(buffer, pszMemTotal) == buffer) {
            m.MemTotal = strtol(buffer + sizeof(pszMemTotal), &end, 10);
        } else if(strstr(buffer, pszSwapTotal) == buffer) {
            m.SwapTotal = strtol(buffer + sizeof(pszSwapTotal), &end, 10);
            break;
        } else if(strstr(buffer, pszSwapFree) == buffer) {
            m.SwapFree = strtol(buffer + sizeof(pszSwapFree), &end, 10);
            break;
        }
    }
    fclose(meminfo);
}

#include <sched.h>
void TVPRelinquishCPU() { sched_yield(); }

bool TVP_utime(const char *name, time_t modtime) {
    timeval mt[2];
    mt[0].tv_sec = modtime;
    mt[0].tv_usec = 0;
    mt[1].tv_sec = modtime;
    mt[1].tv_usec = 0;
    return utimes(name, mt) == 0;
}

tjs_int TVPGetSystemFreeMemory() {
    struct sysinfo info;
    if(sysinfo(&info) == -1) {
        return -1;
    }
    return (info.freeram * info.mem_unit) / (1024 * 1024); // MB
}

tjs_int TVPGetSelfUsedMemory() {
    std::ifstream statm{ "/proc/self/statm" };
    // Field 0 is total VIRTUAL size (huge with ANGLE/Metal mappings — tens
    // of GB, which permanently pinned the memory governor at pressure=3).
    // Field 1 is resident — the actual memory pressure signal.
    tjs_int total_pages = 0, resident_pages = 0;
    statm >> total_pages >> resident_pages;
    return (resident_pages * sysconf(_SC_PAGESIZE)) / (1024 * 1024); // MB RSS
}

// --- native heap introspection ------------------------------------------
// OHOS musl exposes mallinfo/mallinfo2 only from API 20, and the production
// allocator is jemalloc behind the mallopt dfx interface, so resolve the
// symbol at runtime and treat "absent or all-zero" as unknown (-1) rather
// than trusting a zero report.
namespace {

struct OhosMallinfo2 { // mirrors musl struct mallinfo2 (size_t fields)
    size_t arena, ordblks, smblks, hblks, hblkhd;
    size_t usmblks, fsmblks, uordblks, fordblks, keepcost;
};

using OhosMallinfo2Fn = OhosMallinfo2 (*)();

OhosMallinfo2Fn Mallinfo2Entry() {
    static OhosMallinfo2Fn fn = reinterpret_cast<OhosMallinfo2Fn>(
        dlsym(RTLD_DEFAULT, "mallinfo2"));
    return fn;
}

} // namespace

TVPNativeHeapStats TVPGetNativeHeapStats() {
    TVPNativeHeapStats out{ -1, -1 };
    OhosMallinfo2Fn mi2 = Mallinfo2Entry();
    if(mi2 == nullptr)
        return out;
    const OhosMallinfo2 mi = mi2();
    if(mi.uordblks == 0 && mi.arena == 0 && mi.hblkhd == 0)
        return out; // dfx interface present but not backed by the allocator
    out.in_use_mb = static_cast<tjs_int>(mi.uordblks / (1024ULL * 1024ULL));
    out.mapped_mb =
        static_cast<tjs_int>((mi.arena + mi.hblkhd) / (1024ULL * 1024ULL));
    return out;
}

void TVPPurgeNativeHeapForHost() {
    // OHOS has no malloc_trim; the documented closest equivalents are the
    // musl-compat mallopt knobs. M_FLUSH_THREAD_CACHE drops the calling
    // thread's jemalloc cache — on the teardown path the engine's big frees
    // happened on this same thread, so this is where retention unwinds.
    mallopt(M_FLUSH_THREAD_CACHE, 0);
}

void TVPDropSystemFontPagesForHost() {
    // The memory governor tracks RSS; ~500MB of it after a few game
    // sessions turned out to be the platform text stack's read-only mmaps
    // of /system/fonts (same 20MB font resident two dozen times), which
    // pushed session starts into kernel direct-reclaim stalls. The engine
    // itself loads fonts via heap-backed streams — these mappings are not
    // ours to unmap, but their pages are clean file pages, so dropping
    // them is free.
    unsigned long mappings = 0;
    const unsigned long dropped_kb = TVPDropSystemFontPages(&mappings);
    spdlog::info("dropped {}MB resident font pages ({} system-font mappings)",
                 dropped_kb / 1024, mappings);
}

void TVPLogNativeMemoryBreakdown(const char *tag) {
    char detail[192] = "";
    OhosMallinfo2Fn mi2 = Mallinfo2Entry();
    if(mi2 != nullptr) {
        const OhosMallinfo2 mi = mi2();
        snprintf(detail, sizeof(detail),
                 "mi2 uord=%zu ford=%zu arena=%zu hblkhd=%zu keep=%zu",
                 mi.uordblks, mi.fordblks, mi.arena, mi.hblkhd, mi.keepcost);
    }
    TVPLogPosixMemoryBreakdown(tag, TVPGetNativeHeapStats(), detail);
}

std::string TVPGetPackageVersionString() { return "ohos"; }

bool TVPCheckStartupPath(const std::string &path) { return true; }

void TVPControlAdDialog(int adType, int arg1, int arg2) {}

void TVPForceSwapBuffer() {
    // Same semantics as android/AndroidUtils.cpp: only swap when an
    // OHNativeWindow-backed EGL surface is attached (Flutter SurfaceTexture
    // mode on OHOS) AND UpdateDrawBuffer() rendered new content (dirty flag).
    // Without this the engine blits into the window surface's back buffer but
    // the embedder texture never receives a buffer — the Flutter Texture
    // widget stays black while the game loop keeps running.
    auto& egl = krkr::GetEngineEGLContext();
    if (egl.HasNativeWindow()) {
        if (!egl.ConsumeFrameDirty()) {
            // No new content — skip swap to avoid double-buffer flicker.
            return;
        }
        const EGLBoolean ok =
            eglSwapBuffers(egl.GetDisplay(), egl.GetWindowSurface());
        if (ok != EGL_TRUE) {
            OHOSLog(LOG_WARN,
                    (std::string("TVPForceSwapBuffer: eglSwapBuffers failed "
                                 "err=0x") +
                     std::to_string(static_cast<int>(eglGetError())))
                        .c_str());
        }
    }
    // In Pbuffer mode, swap is a no-op — engine_tick handles readback.
}

std::string TVPGetDeviceID() {
    // Stable per-boot device id; a persistent one needs a system API that is
    // not reachable from native code on OHOS. The engine only uses it for
    // diagnostics, so a constant is acceptable.
    return "ohos-device";
}

std::string TVPGetCurrentLanguage() {
    // Injected by the Flutter side (context.resourceManager) before engine
    // boot; "zh_cn"/"ja_jp"/"en_us" style, matching the linux implementation.
    const char *lang_env = std::getenv("KRKR_LANG");
    if(!lang_env || !*lang_env) {
        return "zh_cn";
    }

    std::string locale(lang_env);
    size_t dot_pos = locale.find('.');
    if(dot_pos != std::string::npos) {
        locale = locale.substr(0, dot_pos);
    }

    size_t underscore_pos = locale.find('_');
    if(underscore_pos != std::string::npos) {
        std::string language = locale.substr(0, underscore_pos);
        std::string country = locale.substr(underscore_pos + 1);
        for(char &c : country) {
            if(c >= 'A' && c <= 'Z') {
                c += 'a' - 'A';
            }
        }
        return language + "_" + country;
    }

    return locale;
}

std::string TVPGetDeviceLanguage() { return TVPGetCurrentLanguage(); }

int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption,
                            const std::vector<ttstr> &vecButtons) {
    // Flutter owns the UI; surface the text through hilog and answer "OK".
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0206, "krkr2",
                 "message box: %{public}s / %{public}s",
                 caption.AsStdString().c_str(), text.AsStdString().c_str());
    return 0;
}


extern "C" int TVPShowSimpleMessageBox(const char *pszText,
                                       const char *pszTitle, u_int nButton,
                                       const char **btnText) {
    std::vector<ttstr> vecButtons{};
    for(u_int i = 0; i < nButton; ++i) {
        vecButtons.emplace_back(btnText[i]);
    }
    return TVPShowSimpleMessageBox(pszText, pszTitle, vecButtons);
}

int TVPShowSimpleInputBox(ttstr &text, const ttstr &caption,
                          const ttstr &prompt,
                          const std::vector<ttstr> &vecButtons) {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0206, "krkr2",
                 "input box not supported on ohos: %{public}s",
                 caption.AsStdString().c_str());
    return 0;
}

bool TVPCreateFolders(const ttstr &folder);

static bool _TVPCreateFolders(const ttstr &folder) {
    if(folder.IsEmpty())
        return true;

    if(TVPCheckExistentLocalFolder(folder))
        return true; // already created

    const tjs_char *p = folder.c_str();
    tjs_int i = folder.GetLen() - 1;

    if(p[i] == TJS_W(':'))
        return true;

    while(i >= 0 && (p[i] == TJS_W('/') || p[i] == TJS_W('\\')))
        i--;

    if(i >= 0 && p[i] == TJS_W(':'))
        return true;

    for(; i >= 0; i--) {
        if(p[i] == TJS_W(':') || p[i] == TJS_W('/') || p[i] == TJS_W('\\'))
            break;
    }

    ttstr parent(p, i + 1);
    if(!_TVPCreateFolders(parent))
        return false;

    std::error_code ec;
    std::filesystem::create_directory(folder.AsStdString(), ec);
    return !ec || ec == std::errc::file_exists;
}

bool TVPCreateFolders(const ttstr &folder) {
    if(folder.IsEmpty())
        return true;

    const tjs_char *p = folder.c_str();
    tjs_int i = folder.GetLen() - 1;

    if(p[i] == TJS_W(':'))
        return true;

    if(p[i] == TJS_W('/') || p[i] == TJS_W('\\'))
        i--;

    return _TVPCreateFolders(ttstr(p, i + 1));
}

bool TVP_stat(const char *name, tTVP_stat &s) {
    struct stat t;
    if(stat(name, &t) != 0) {
        return false;
    }

    s.st_mode = t.st_mode;
    s.st_size = t.st_size;
    s.st_atime = t.st_atim.tv_sec;
    s.st_mtime = t.st_mtim.tv_sec;
    s.st_ctime = t.st_ctim.tv_sec;

    return true;
}

bool TVP_stat(const tjs_char *name, tTVP_stat &s) {
    return TVP_stat(ttstr{ name }.AsStdString().c_str(), s);
}

tjs_uint32 TVPGetRoughTickCount32() {
    tjs_uint32 uptime = 0;
    struct timespec on;
    if(clock_gettime(CLOCK_MONOTONIC, &on) == 0)
        uptime = on.tv_sec * 1000 + on.tv_nsec / 1000000;
    return uptime;
}

void TVPExitApplication(int code) {
    if(TVPHostSuppressProcessExit) {
        return;
    }
    TVPDeliverCompactEvent(TVP_COMPACT_LEVEL_MAX);
    exit(code);
}

bool TVPCheckStartupArg() { return false; }

void TVPProcessInputEvents() {}

bool TVPDeleteFile(const std::string &filename) {
    return unlink(filename.c_str()) == 0;
}

bool TVPRenameFile(const std::string &from, const std::string &to) {
    tjs_int ret = rename(from.c_str(), to.c_str());
    return !ret;
}

void TVPSendToOtherApp(const std::string &filename) {}

std::vector<std::string> TVPGetDriverPath() { return { "/" }; }

std::string TVPGetDefaultFileDir() {
    // The Flutter side injects the app sandbox files dir via KRKR_FILES_DIR
    // (Dart FFI setenv during bootstrap). Fall back to the module directory.
    const char *dir = std::getenv("KRKR_FILES_DIR");
    if(dir && *dir) {
        return dir;
    }
    char buffer[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if(len == -1) {
        return "";
    }
    buffer[len] = '\0';
    return std::string(buffer);
}

std::vector<std::string> TVPGetAppStoragePath() {
    std::vector<std::string> ret;
    ret.emplace_back(TVPGetDefaultFileDir());
    return ret;
}

bool TVPWriteDataToFile(const ttstr &filepath, const void *data,
                        unsigned int len) {
    FILE *handle = fopen(filepath.AsStdString().c_str(), "wb");
    if(handle) {
        bool ret = fwrite(data, 1, len, handle) == len;
        fclose(handle);
        return ret;
    }
    return false;
}

void TVPCheckAndSendDumps(const std::string &dumpdir,
                          const std::string &packageName,
                          const std::string &versionStr) {
    // no crash-dump pipeline on ohos yet
}

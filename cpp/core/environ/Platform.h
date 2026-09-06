#pragma once
#include "tjsCommHead.h"
#include <string>
#include <vector>
#include <spdlog/spdlog.h>

struct TVPMemoryInfo { // all in kB
    unsigned long MemTotal;
    unsigned long MemFree;
    unsigned long SwapTotal;
    unsigned long SwapFree;
    unsigned long VirtualTotal;
    unsigned long VirtualUsed;
};

void TVPGetMemoryInfo(TVPMemoryInfo &m);
tjs_int TVPGetSystemFreeMemory(); // in MB
tjs_int TVPGetSelfUsedMemory(); // in MB

// Native (C heap) allocator stats. -1 = unknown on this platform / API level.
// mapped_mb covers everything the allocator obtained from the OS, so on a
// healthy teardown in_use drops near zero while mapped stays whatever the
// allocator has NOT yet returned — the retention the memory governor needs
// to see (RSS keeps counting retained pages until they are purged).
struct TVPNativeHeapStats {
    tjs_int in_use_mb;
    tjs_int mapped_mb;
};
TVPNativeHeapStats TVPGetNativeHeapStats();

// Ask the platform allocator to release free-but-retained pages back to the
// OS (malloc_trim / mallopt(M_FLUSH_THREAD_CACHE) / zone pressure relief).
// Safe to call from any compact path; cheap no-op where unsupported.
void TVPPurgeNativeHeapForHost();

// One-shot native memory attribution (smaps breakdown + allocator internals)
// for the engine log. Called at session teardown/start, not per tick.
void TVPLogNativeMemoryBreakdown(const char *tag);

extern "C" int TVPShowSimpleMessageBox(const char *text, const char *caption,
                                       unsigned int nButton,
                                       const char **btnText); // C-style

int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption,
                            const std::vector<ttstr> &vecButtons);
int TVPShowSimpleMessageBox(const ttstr &text, const ttstr &caption);
int TVPShowSimpleMessageBoxYesNo(const ttstr &text, const ttstr &caption);

int TVPShowSimpleInputBox(ttstr &text, const ttstr &caption,
                          const ttstr &prompt,
                          const std::vector<ttstr> &vecButtons);

std::vector<std::string> TVPGetDriverPath();
std::vector<std::string> TVPGetAppStoragePath();
bool TVPCheckStartupPath(const std::string &path);
std::string TVPGetPackageVersionString();
void TVPExitApplication(int code);
void TVPCheckMemory();
const std::string &TVPGetInternalPreferencePath();
bool TVPDeleteFile(const std::string &filename);
bool TVPRenameFile(const std::string &from, const std::string &to);
bool TVPCopyFile(const std::string &from, const std::string &to);

void TVPShowIME(int x, int y, int w, int h);
void TVPHideIME();

void TVPRelinquishCPU();
void TVPPrintLog(const char *str);

// 宏定义冲突 sys/stat.h
#ifdef st_atime
#undef st_atime
#endif
#ifdef st_mtime
#undef st_mtime
#endif
#ifdef st_ctime
#undef st_ctime
#endif

struct tTVP_stat {
    uint16_t st_mode;
    uint64_t st_size;
    uint64_t st_atime;
    uint64_t st_mtime;
    uint64_t st_ctime;
};

bool TVP_stat(const tjs_char *name, tTVP_stat &s);
bool TVP_stat(const char *name, tTVP_stat &s);
bool TVP_utime(const char *name, time_t modtime);

void TVPSendToOtherApp(const std::string &filename);

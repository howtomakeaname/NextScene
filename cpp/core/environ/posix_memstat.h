#pragma once
// Shared /proc-based native-memory attribution for the POSIX-flavoured
// platform TUs (linux, ohos). Header-only because the environ platform
// sources are mutually exclusive per binary (see environ/CMakeLists.txt) —
// only one of them exists in any given link, so a cross-TU helper would
// have no home. Everything here is inline and dependency-free.

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <string>
#include <sys/mman.h>
#include <utility>
#include <vector>

#include <spdlog/spdlog.h>

#include "Platform.h"

struct TVPSmapsMappingInfo {
    std::string name; // "[heap]", "[anon:...]", file path, "" = plain anon
    unsigned long rss_kb = 0;
    unsigned long start = 0; // mapping range and perms, for madvise-style
    unsigned long end = 0;   // walks over our own address space
    char perms[8] = { 0 };
};

struct TVPSmapsSummary {
    bool ok = false;
    unsigned long total_kb = 0;
    unsigned long heap_kb = 0;       // the [heap] mapping
    unsigned long anon_kb = 0;       // unnamed anonymous mappings
    unsigned long anon_named_kb = 0; // [anon:...] tagged (allocator arenas…)
    unsigned long file_kb = 0;       // named, non-[...] file-backed mappings
    std::vector<TVPSmapsMappingInfo> mappings;
};

// Parses /proc/self/smaps (or the given path, for tests). Tolerates missing
// fields; total is the sum of per-mapping Rss, i.e. the smaps view of RSS.
inline TVPSmapsSummary TVPReadSmapsSummary(const char *path = "/proc/self/smaps") {
    TVPSmapsSummary s;
    FILE *f = fopen(path, "r");
    if(!f)
        return s;

    char line[1024];
    std::string cur_name;
    bool have_mapping = false;
    unsigned long cur_rss = 0;
    unsigned long cur_start = 0, cur_end = 0;
    char cur_perms[8] = { 0 };

    auto commit = [&]() {
        if(!have_mapping)
            return;
        s.total_kb += cur_rss;
        if(cur_name == "[heap]")
            s.heap_kb += cur_rss;
        else if(cur_name.empty())
            s.anon_kb += cur_rss;
        else if(cur_name.compare(0, 6, "[anon:") == 0)
            s.anon_named_kb += cur_rss;
        else
            s.file_kb += cur_rss;
        TVPSmapsMappingInfo info;
        info.name = cur_name;
        info.rss_kb = cur_rss;
        info.start = cur_start;
        info.end = cur_end;
        memcpy(info.perms, cur_perms, sizeof(info.perms));
        s.mappings.push_back(info);
    };

    while(fgets(line, sizeof(line), f)) {
        unsigned long start = 0, end = 0, offset = 0, inode = 0;
        char perms[8] = { 0 };
        unsigned int dmaj = 0, dmin = 0;
        int consumed = 0;
        if(sscanf(line, "%lx-%lx %7s %lx %x:%x %lu %n", &start, &end, perms,
                  &offset, &dmaj, &dmin, &inode,
                  &consumed) >= 7) {
            commit();
            have_mapping = true;
            cur_rss = 0;
            cur_start = start;
            cur_end = end;
            memcpy(cur_perms, perms, sizeof(cur_perms));
            const char *name = line + consumed;
            while(*name == ' ' || *name == '\t')
                name++;
            cur_name = name;
            while(!cur_name.empty() &&
                  (cur_name.back() == '\n' || cur_name.back() == '\r'))
                cur_name.pop_back();
        } else if(strncmp(line, "Rss:", 4) == 0) {
            unsigned long rss = 0;
            if(sscanf(line + 4, "%lu", &rss) == 1)
                cur_rss = rss;
        }
    }
    commit();
    fclose(f);
    s.ok = true;
    return s;
}

inline std::string TVPFormatTopSmapsMappings(const TVPSmapsSummary &s,
                                             size_t top_n = 5) {
    std::vector<const TVPSmapsMappingInfo *> ranked;
    ranked.reserve(s.mappings.size());
    for(const auto &m : s.mappings)
        if(m.rss_kb > 0)
            ranked.push_back(&m);
    std::sort(ranked.begin(), ranked.end(),
              [](const TVPSmapsMappingInfo *a, const TVPSmapsMappingInfo *b) {
                  return a->rss_kb > b->rss_kb;
              });
    if(ranked.size() > top_n)
        ranked.resize(top_n);
    std::string out;
    for(const auto *m : ranked) {
        if(!out.empty())
            out += ", ";
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%lu", m->rss_kb / 1024);
        out += (m->name.empty() ? std::string("(anon)") : m->name) + "[" +
               buf + "MB]";
    }
    return out;
}

// Top-N file-backed mappings, RSS summed per name (archives map many
// segments; libraries map several PT_LOADs — the sum is what we want).
// Shows "name[RSS xCOUNT]" when the same file is mapped more than once —
// per-open mmaps of a font that never get unmapped show up as a big count.
inline std::string TVPFormatTopFileMappings(const TVPSmapsSummary &s,
                                            size_t top_n = 5) {
    struct Agg {
        std::string name;
        unsigned long rss_kb;
        unsigned long count;
    };
    std::vector<Agg> agg;
    for(const auto &m : s.mappings) {
        if(m.name.empty() || m.name[0] == '[' || m.rss_kb == 0)
            continue;
        auto it = std::find_if(agg.begin(), agg.end(),
                               [&](const Agg &a) { return a.name == m.name; });
        if(it != agg.end()) {
            it->rss_kb += m.rss_kb;
            it->count += 1;
        } else {
            agg.push_back({m.name, m.rss_kb, 1});
        }
    }
    std::sort(agg.begin(), agg.end(),
              [](const Agg &a, const Agg &b) { return a.rss_kb > b.rss_kb; });
    if(agg.size() > top_n)
        agg.resize(top_n);
    std::string out;
    for(const auto &m : agg) {
        if(!out.empty())
            out += ", ";
        char buf[80];
        if(m.count > 1)
            std::snprintf(buf, sizeof(buf), "%lu x%lu", m.rss_kb / 1024,
                          m.count);
        else
            std::snprintf(buf, sizeof(buf), "%lu", m.rss_kb / 1024);
        out += m.name + "[" + buf + "MB]";
    }
    return out;
}

// Zap resident pages of read-only system-font mappings in this process.
// The platform text stack mmaps system fonts and CJK rasterization touches
// pages across the whole file, so clean font pages accumulate in RSS for
// the life of the process (measured ~500MB after a few game sessions —
// about half of RSS — with the same 20MB font mapped two dozen times).
// MADV_DONTNEED on a non-writable mapping discards nothing: pages simply
// refault from the file on next use. Returns dropped RSS in kB; sets
// *mapping_count to the number of mappings advised.
inline unsigned long TVPDropSystemFontPages(unsigned long *mapping_count) {
    if(mapping_count)
        *mapping_count = 0;
    TVPSmapsSummary s = TVPReadSmapsSummary();
    if(!s.ok)
        return 0;
    unsigned long dropped_kb = 0, advised = 0;
    for(const auto &m : s.mappings) {
        if(m.perms[0] != 'r' || m.perms[1] == 'w')
            continue; // never touch writable mappings
        if(m.name.compare(0, 14, "/system/fonts/") != 0)
            continue;
        const std::string::size_type dot = m.name.find_last_of('.');
        const std::string ext =
            dot == std::string::npos ? std::string() : m.name.substr(dot + 1);
        if(ext != "ttf" && ext != "ttc" && ext != "otf" && ext != "otc")
            continue;
        if(m.end <= m.start)
            continue;
        if(madvise(reinterpret_cast<void *>(m.start), m.end - m.start,
                   MADV_DONTNEED) == 0) {
            dropped_kb += m.rss_kb;
            advised++;
        }
    }
    if(mapping_count)
        *mapping_count = advised;
    return dropped_kb;
}

// One-shot attribution line for the engine log. heap carries the platform
// allocator stats (-1 = unknown); allocator_detail is an optional
// platform-composed string of raw allocator fields (mallinfo/zone numbers).
inline void TVPLogPosixMemoryBreakdown(const char *tag,
                                       const TVPNativeHeapStats &heap,
                                       const char *allocator_detail) {
    TVPSmapsSummary s = TVPReadSmapsSummary();
    if(!s.ok) {
        spdlog::info("(memstat:{}) smaps unavailable rss={}MB heap_alloc={}/{}MB",
                     tag, TVPGetSelfUsedMemory(), heap.in_use_mb,
                     heap.mapped_mb);
        return;
    }
    spdlog::info(
        "(memstat:{}) rss={}MB smaps_total={}MB [heap]={}MB anon={}MB "
        "anon_named={}MB file={}MB heap_alloc={}/{}MB{}{} top=[{}] "
        "filetop=[{}]",
        tag, TVPGetSelfUsedMemory(), s.total_kb / 1024, s.heap_kb / 1024,
        s.anon_kb / 1024, s.anon_named_kb / 1024, s.file_kb / 1024,
        heap.in_use_mb, heap.mapped_mb,
        allocator_detail && *allocator_detail ? " " : "",
        allocator_detail ? allocator_detail : "", TVPFormatTopSmapsMappings(s),
        TVPFormatTopFileMappings(s));
}

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
#include <utility>
#include <vector>

#include <spdlog/spdlog.h>

#include "Platform.h"

struct TVPSmapsMappingInfo {
    std::string name; // "[heap]", "[anon:...]", file path, "" = plain anon
    unsigned long rss_kb = 0;
};

struct TVPSmapsSummary {
    bool ok = false;
    unsigned long total_kb = 0;
    unsigned long heap_kb = 0;       // the [heap] mapping
    unsigned long anon_kb = 0;       // unnamed anonymous mappings
    unsigned long anon_named_kb = 0; // [anon:...] tagged (allocator arenas…)
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
        s.mappings.push_back({cur_name, cur_rss});
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
        "anon_named={}MB heap_alloc={}/{}MB{}{} top=[{}]",
        tag, TVPGetSelfUsedMemory(), s.total_kb / 1024, s.heap_kb / 1024,
        s.anon_kb / 1024, s.anon_named_kb / 1024, heap.in_use_mb,
        heap.mapped_mb, allocator_detail && *allocator_detail ? " " : "",
        allocator_detail ? allocator_detail : "", TVPFormatTopSmapsMappings(s));
}

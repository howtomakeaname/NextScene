#include "artemis_save_dir.h"

#include <cctype>
#include <cstdio>
#include <dirent.h>
#include <sys/stat.h>

namespace krkr2_artemis {
namespace {

std::string ToLower(std::string s) {
  for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

bool EndsWith(const std::string& s, const std::string& suffix) {
  return s.size() >= suffix.size() &&
         s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::string StripTrailingSlash(std::string p) {
  while (p.size() > 1 && (p.back() == '/' || p.back() == '\\')) p.pop_back();
  return p;
}

std::string BaseName(const std::string& p) {
  const std::string t = StripTrailingSlash(p);
  const size_t slash = t.find_last_of("/\\");
  return slash == std::string::npos ? t : t.substr(slash + 1);
}

uint32_t Fn1a32(const std::string& s) {
  uint32_t h = 2166136261u;
  for (unsigned char c : s) { h ^= c; h *= 16777619u; }
  return h;
}

std::string SaveDirForIdentity(const std::string& writable_root,
                               const std::string& game_dir,
                               const std::string& identity) {
  char suffix[9];
  std::snprintf(suffix, sizeof(suffix), "%08x", Fn1a32(identity));
  return StripTrailingSlash(writable_root) + "/artemis-saves/" +
         BaseName(game_dir) + "-" + suffix;
}

std::string StableGameIdentity(const std::string& writable_root,
                               const std::string& game_dir) {
  const std::string root = StripTrailingSlash(writable_root);
  const std::string game = StripTrailingSlash(game_dir);
  if (game.size() > root.size() + 1 && game.compare(0, root.size(), root) == 0 &&
      (game[root.size()] == '/' || game[root.size()] == '\\')) {
    return game.substr(root.size() + 1);
  }
  return game_dir;
}

bool IsRegularFile(const std::string& path) {
  struct stat st {};
  return ::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

void MakeDirs(const std::string& path) {
  std::string cur;
  for (size_t i = 0; i < path.size(); ++i) {
    cur.push_back(path[i]);
    if (path[i] == '/' && cur.size() > 1) ::mkdir(cur.c_str(), 0755);
  }
  ::mkdir(path.c_str(), 0755);
}

bool HasSaveFiles(const std::string& dir) {
  DIR* d = ::opendir(dir.c_str());
  if (d == nullptr) return false;
  bool found = false;
  while (dirent* ent = ::readdir(d)) {
    const std::string lower = ToLower(ent->d_name);
    // A freshly opened game may create config/global banks before any save.
    // They must not make an otherwise empty stable directory look established.
    if (lower != "conf.dat" && lower != "global.dat" && EndsWith(lower, ".dat")) {
      found = true;
      break;
    }
  }
  ::closedir(d);
  return found;
}

bool IsLegacyDirName(const std::string& name, const std::string& prefix) {
  if (name.size() != prefix.size() + 8 || name.compare(0, prefix.size(), prefix) != 0)
    return false;
  for (size_t i = prefix.size(); i < name.size(); ++i) {
    if (!std::isxdigit(static_cast<unsigned char>(name[i]))) return false;
  }
  return true;
}

// Old iOS containers leave directories hashed from their old absolute paths,
// which cannot be recomputed after the container UUID changes. When the stable
// directory has no real saves, recover the newest matching legacy directory.
std::string FindLatestLegacySaveDir(const std::string& writable_root,
                                    const std::string& game_dir,
                                    const std::string& stable_dir) {
  const std::string parent = StripTrailingSlash(writable_root) + "/artemis-saves";
  const std::string prefix = BaseName(game_dir) + "-";
  DIR* d = ::opendir(parent.c_str());
  if (d == nullptr) return {};
  std::string best;
  time_t best_mtime = 0;
  while (dirent* ent = ::readdir(d)) {
    const std::string name = ent->d_name;
    const std::string candidate = parent + "/" + name;
    if (candidate == stable_dir || !IsLegacyDirName(name, prefix) ||
        !HasSaveFiles(candidate)) continue;
    struct stat st {};
    if (::stat(candidate.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) continue;
    if (best.empty() || st.st_mtime > best_mtime ||
        (st.st_mtime == best_mtime && name > BaseName(best))) {
      best = candidate;
      best_mtime = st.st_mtime;
    }
  }
  ::closedir(d);
  return best;
}

bool CopyFileBytes(const std::string& from, const std::string& to) {
  FILE* in = std::fopen(from.c_str(), "rb");
  if (in == nullptr) return false;
  FILE* out = std::fopen(to.c_str(), "wbx");
  if (out == nullptr) { std::fclose(in); return false; }
  char buf[65536];
  size_t n;
  bool ok = true;
  while ((n = std::fread(buf, 1, sizeof(buf), in)) > 0) {
    if (std::fwrite(buf, 1, n, out) != n) { ok = false; break; }
  }
  if (std::ferror(in)) ok = false;
  std::fclose(in);
  if (std::fclose(out) != 0) ok = false;
  return ok;
}

int SeedSaveFiles(const std::string& save_dir, const std::string& source_dir,
                  bool sidecars,
                  const std::function<void(const std::string&)>& log) {
  DIR* d = ::opendir(source_dir.c_str());
  if (d == nullptr) return 0;
  int seeded = 0;
  while (dirent* ent = ::readdir(d)) {
    const std::string name = ent->d_name;
    const std::string lower = ToLower(name);
    const bool wanted = !sidecars || lower == "system.dat" || lower == "saveg.dat" ||
                        (lower.rfind("save", 0) == 0 && EndsWith(lower, ".dat"));
    if (!wanted) continue;
    const std::string from = source_dir + "/" + name;
    if (IsRegularFile(from) && CopyFileBytes(from, save_dir + "/" + name)) {
      ++seeded;
      log(std::string("artemis: migrated ") +
          (sidecars ? "sidecar" : "legacy") + " save file: " + name);
    }
  }
  ::closedir(d);
  return seeded;
}

}  // namespace

std::string LegacyPerGameSaveDir(const std::string& writable_root,
                                 const std::string& game_dir) {
  return SaveDirForIdentity(writable_root, game_dir, game_dir);
}

std::string PerGameSaveDir(const std::string& writable_root,
                           const std::string& game_dir) {
  return SaveDirForIdentity(writable_root, game_dir,
                            StableGameIdentity(writable_root, game_dir));
}

std::string PreparePerGameSaveDir(
    const std::string& writable_root, const std::string& game_dir,
    const std::function<void(const std::string&)>& log) {
  const std::string save_dir = PerGameSaveDir(writable_root, game_dir);
  MakeDirs(save_dir);
  if (!HasSaveFiles(save_dir)) {
    const std::string legacy_dir =
        FindLatestLegacySaveDir(writable_root, game_dir, save_dir);
    int seeded = 0;
    if (!legacy_dir.empty()) {
      log("artemis: recovering legacy save directory: " + legacy_dir);
      seeded += SeedSaveFiles(save_dir, legacy_dir, false, log);
    }
    seeded += SeedSaveFiles(save_dir, game_dir, true, log);
    if (seeded > 0) {
      log("artemis: migrated " + std::to_string(seeded) +
          " save file(s) into stable per-game save area");
    }
  }
  return save_dir;
}

}  // namespace krkr2_artemis

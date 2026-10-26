#ifndef KRKR2_ENGINE_API_ARTEMIS_SAVE_DIR_H_
#define KRKR2_ENGINE_API_ARTEMIS_SAVE_DIR_H_

#include <functional>
#include <string>

namespace krkr2_artemis {

// A game inside the writable root is identified by its relative path, so an
// iOS container UUID change does not change its save directory. Games outside
// that root (including Android document-provider logical paths) retain the
// historical absolute-path identity.
std::string PerGameSaveDir(const std::string& writable_root,
                           const std::string& game_dir);
std::string LegacyPerGameSaveDir(const std::string& writable_root,
                                 const std::string& game_dir);

// Create the per-game directory and populate a fresh one from the legacy hash
// directory and historical sidecar files. Existing destination files win.
std::string PreparePerGameSaveDir(
    const std::string& writable_root, const std::string& game_dir,
    const std::function<void(const std::string&)>& log);

}  // namespace krkr2_artemis

#endif  // KRKR2_ENGINE_API_ARTEMIS_SAVE_DIR_H_

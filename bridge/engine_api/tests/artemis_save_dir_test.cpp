#include "artemis_save_dir.h"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;
using krkr2_artemis::LegacyPerGameSaveDir;
using krkr2_artemis::PerGameSaveDir;
using krkr2_artemis::PreparePerGameSaveDir;

namespace {

void Expect(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

void WriteFile(const fs::path& path, const std::string& contents) {
  std::ofstream out(path, std::ios::binary);
  out << contents;
  Expect(out.good(), "write fixture " + path.string());
}

std::string ReadFile(const fs::path& path) {
  std::ifstream in(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>()};
}

}  // namespace

int main() {
  const std::string root_a = "/private/var/mobile/Containers/UUID-A/Documents";
  const std::string root_b = "/private/var/mobile/Containers/UUID-B/Documents";
  const std::string game_a = root_a + "/Games/脏翅膀";
  const std::string game_b = root_b + "/Games/脏翅膀";

  Expect(fs::path(PerGameSaveDir(root_a, game_a)).filename() ==
             fs::path(PerGameSaveDir(root_b, game_b)).filename(),
         "同一游戏跨 iOS 容器应使用相同存档目录名");
  Expect(PerGameSaveDir(root_a, game_a) !=
             PerGameSaveDir(root_a, root_a + "/Games/另一款游戏"),
         "不同游戏不得共享存档目录");
  Expect(PerGameSaveDir(root_a, root_a + "/Games-A/同名") !=
             PerGameSaveDir(root_a, root_a + "/Games-B/同名"),
         "同名但不同相对路径的游戏不得碰撞");
  Expect(PerGameSaveDir(root_a, "/external/Games/脏翅膀") ==
             LegacyPerGameSaveDir(root_a, "/external/Games/脏翅膀"),
         "外部路径和 Android 逻辑路径应保持原有标识");
  Expect(PerGameSaveDir(root_a, root_a + "-other/Games/脏翅膀") ==
             LegacyPerGameSaveDir(root_a, root_a + "-other/Games/脏翅膀"),
         "可写目录的同名前缀兄弟目录不得误判为子目录");

  const fs::path temp = fs::temp_directory_path() / "artemis-save-dir-test";
  fs::remove_all(temp);
  const fs::path root = temp / "Documents";
  const fs::path game = root / "Games" / "脏翅膀";
  fs::create_directories(game);
  const std::string old_root = temp / "OldContainerDocuments";
  const std::string old_game = old_root + "/Games/脏翅膀";
  const std::string legacy = LegacyPerGameSaveDir(root.string(), old_game);
  fs::create_directories(legacy);
  const std::string stable = PerGameSaveDir(root.string(), game.string());
  fs::create_directories(stable);
  WriteFile(fs::path(stable) / "conf.dat", "fresh-config");
  WriteFile(fs::path(legacy) / "AiyokunoEustia0001.dat", "legacy-slot");
  WriteFile(fs::path(legacy) / "AiyokunoEustia0001.png", "legacy-thumbnail");
  WriteFile(fs::path(legacy) / "system.dat", "legacy-system");
  WriteFile(game / "save0002.dat", "sidecar-slot");
  std::vector<std::string> logs;
  const std::string save = PreparePerGameSaveDir(
      root.string(), game.string(), [&logs](const std::string& line) { logs.push_back(line); });
  Expect(save == PerGameSaveDir(root.string(), game.string()),
         "准备存档目录应返回稳定目录");
  Expect(ReadFile(fs::path(save) / "AiyokunoEustia0001.dat") == "legacy-slot",
         "应迁移旧哈希目录中的槽位");
  Expect(ReadFile(fs::path(save) / "AiyokunoEustia0001.png") == "legacy-thumbnail",
         "应同时迁移槽位缩略图");
  Expect(ReadFile(fs::path(save) / "system.dat") == "legacy-system",
         "应迁移旧哈希目录中的系统变量");
  Expect(ReadFile(fs::path(save) / "save0002.dat") == "sidecar-slot",
         "旧目录迁移后仍应接收游戏旁的历史存档");
  Expect(!logs.empty(), "迁移应留下可诊断日志");

  WriteFile(fs::path(save) / "system.dat", "new-system");
  WriteFile(fs::path(legacy) / "save0003.dat", "must-not-overwrite");
  PreparePerGameSaveDir(root.string(), game.string(), {});
  Expect(ReadFile(fs::path(save) / "system.dat") == "new-system",
         "已有新存档时不得被旧目录覆盖");
  Expect(!fs::exists(fs::path(save) / "save0003.dat"),
         "已有数据的新目录不得再次合并旧目录");

  fs::remove_all(temp);
  std::cout << "Artemis save directory regressions passed\n";
  return 0;
}

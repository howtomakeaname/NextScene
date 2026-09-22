

# 下一幕 NextScene

基于 Flutter 重构的下一代跨平台视觉小说游戏模拟器



![Status](https://img.shields.io/badge/status-In%20Development-orange)![Engine](https://img.shields.io/badge/engine-KiriKiri2-blue)![Flutter](https://img.shields.io/badge/framework-Flutter-02569B)![ANGLE](https://img.shields.io/badge/graphics-ANGLE-red)![License](https://img.shields.io/badge/license-GPL--3.0-blue)

---

**语言 / Language**: 中文 | [English](README_EN.md)

> 🙏 本仓库（HarmonyOS 适配版）基于 [reAAAq/KrKr2-Next](https://github.com/reAAAq/KrKr2-Next) 二次开发而来，在其基础上新增了 HarmonyOS/OpenHarmony（原生鸿蒙）支持，感谢原作者的贡献。上游项目又是基于 [krkr2](https://github.com/2468785842/krkr2) 重构的，一并致谢。



## 简介

**下一幕**（NextScene）是 [KiriKiri2 (吉里吉里2)](https://zh.wikipedia.org/wiki/%E5%90%89%E9%87%8C%E5%90%89%E9%87%8C2) 视觉小说引擎的现代化跨平台运行环境。它兼容原版游戏脚本，用现代图形接口做硬件加速渲染，并在渲染和脚本执行上做了不少优化。界面用 Flutter 统一实现，目标平台是 macOS · iOS · Windows · Linux · Android · HarmonyOS/OpenHarmony。HarmonyOS 上同一个 HAP 还能跑 Artemis（`.pfs`）。

## 界面预览

以下截图采集自 HarmonyOS SDK 20 真机。竖图已裁掉系统状态栏。应用壳是四个 Tab：库 / 管理 / 统计 / 我的。游戏运行截图为《9-nine-九次九日九重色》标题画面，并打开了性能监控。


|                                                 |                                                            |
| ----------------------------------------------- | ---------------------------------------------------------- |
| ![游戏库首页](doc/screenshots/home.webp) 库           | ![首页长按快捷菜单](doc/screenshots/home-context-menu.webp) 长按快捷菜单 |
| ![游戏详情页](doc/screenshots/game-detail.webp) 游戏详情 | ![设置页](doc/screenshots/settings.webp) 设置                   |
| ![文件管理](doc/screenshots/manage.webp) 管理         | ![我的](doc/screenshots/profile.webp) 我的                     |




### 游戏运行（横屏）

![HarmonyOS 真机横屏运行 9-nine-九次九日九重色](doc/screenshots/game-running-landscape.webp)  
《9-nine-九次九日九重色》标题画面 （KiriKiri2 / GLES ，约 90 fps）

![游戏内快捷控制](doc/screenshots/game-controls.webp)  
游戏内快捷控制（暂停 / 虚拟操控手柄 / 退出）

## 架构

![技术架构图](doc/architecture.png)

**渲染管线**：macOS 等桌面/移动端走 ANGLE 的 EGL Pbuffer 离屏渲染（OpenGL ES 2.0），再经平台纹理共享（macOS → IOSurface、Windows → D3D11 Texture、Linux → DMA-BUF）交给 Flutter Texture。HarmonyOS 不经 ANGLE，直接用系统 EGL（GLES）画到 pbuffer，再经 OHNativeWindow / RawImage 读回显示。

## 开发进度

> ⚠️ 本项目仍在活跃开发，没有稳定发行版。本仓库当前以 HarmonyOS 真机为主；上游 macOS 进度仍较完整。


| 模块               | 状态     | 说明                                                            |
| ---------------- | ------ | ------------------------------------------------------------- |
| C++ 引擎核心编译       | ✅ 完成   | KiriKiri2 核心引擎全平台可编译                                          |
| ANGLE 渲染层迁移      | ✅ 基本完成 | 替代原 Cocos2d-x + GLFW 渲染管线，使用 EGL/GLES 离屏渲染                    |
| engine_api 桥接层   | ✅ 完成   | 导出 `engine_create` / `engine_tick` / `engine_destroy` 等 C API |
| Flutter Plugin   | ✅ 基本完成 | Platform Channel 通信、Texture 纹理桥接                              |
| Texture 零拷贝渲染    | ✅ 基本完成 | 通过平台原生纹理共享机制零拷贝传递引擎渲染帧到 Flutter                               |
| Flutter 应用壳      | ✅ 基本完成 | 库 / 管理 / 统计 / 我的，含设置、帮助、关于与性能监控                               |
| 输入事件转发           | ✅ 基本完成 | 鼠标 / 触控事件坐标映射转发到引擎                                            |
| 引擎性能优化           | 🔨 进行中 | SIMD 像素混合、GPU 合成管线、VM 解释器优化等                                  |
| 游戏兼容性优化          | 🔨 进行中 | 补全解析引擎、添加插件，阶段目标与 Z 大闭源版兼容性持平                                 |
| 原有 krkr2 模拟器功能移植 | 📋 规划中 | 将原有 krkr2 模拟器功能逐步移植到新架构                                       |




## 平台支持状态


| 平台                      | 状态                                     | 图形后端                 | 纹理共享机制                       |
| ----------------------- | -------------------------------------- | -------------------- | ---------------------------- |
| macOS                   | ✅ 基本完成                                 | Metal                | IOSurface                    |
| iOS                     | 🔨 流程打通，正在优化和修复 OpenGL 渲染              | Metal                | IOSurface                    |
| Windows                 | 📋 计划中                                 | Direct3D 11          | D3D11 Texture                |
| Linux                   | 📋 计划中                                 | Vulkan / Desktop GL  | DMA-BUF                      |
| Android                 | 🔨 流程跑通，优化中                            | OpenGL ES / Vulkan   | HardwareBuffer               |
| HarmonyOS / OpenHarmony | 🔨 真机可玩（SDK 20），优化中；额外支持 Artemis（.pfs） | 系统 EGL (GLES) / 软件合成 | OHNativeWindow / RawImage 读回 |




## HarmonyOS / OpenHarmony（原生鸿蒙）支持

本仓库在 upstream 基础上新增了原生鸿蒙（HarmonyOS / OpenHarmony，API 20 / SDK 5.x）支持：引擎 C++ 核心经 OHOS NDK（llvm + musl）交叉编译为 `libengine_api.so` 打入 HAP，由 Flutter OHOS 宿主加载；音频走系统 OHAudio；字体直接注册 `/system/fonts` 下的 NotoSansCJK 等系统字体。

### 环境准备

1. [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（含 OpenHarmony SDK，实测用 API 20）
2. Flutter OHOS fork：[flutter_flutter_ohos](https://gitcode.com/openharmony-sig/flutter_flutter)（ `oh-3.41.9-release` 分支），检出后将其 `bin` 加入 PATH
3. [ohos_flutter_packages](https://gitcode.com/openharmony-sig/flutter_packages) 检出到与本仓库**同级**的 `ohos_flutter_packages/` 目录（OHOS 专属的 `dependency_overrides` 存放在 `apps/flutter_app/pubspec_overrides.ohos.yaml`，构建脚本会自动拷贝为 `pubspec_overrides.yaml` 启用；其他平台不受影响，无需该目录）
4. vcpkg 依赖按仓库根 `vcpkg.json` 拉取，triplet 使用 `vcpkg/triplets/arm64-ohos.cmake`



### 构建与安装

```bash
./build/build_ohos.sh release     # 交叉编译引擎 + flutter build hap
hdc install -r apps/flutter_app/build/ohos/hap/entry-default-signed.hap
# 未配置本地签名时，改用 unsigned：
# hdc install -r apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

> ⚠️ 性能相关：请勿用 `debug` 产物评估性能——CMake Debug 为 `-O0`，Highway SIMD
> 混合内核退化为每 16 像素多次跨函数调用，整帧合成慢约两个数量级。release 为
> `-O2 -DNDEBUG` + Flutter AOT。



### 运行说明与已知限制

- 模拟器上建议在设置里切 **renderer=software**（软件渲染 + RawImage）；模拟器 GPU 对高频纹理上传不稳定。真机用默认 OpenGL 即可
- 游戏导入：在「库」点「添加游戏」，选完整游戏目录，或 XP3 / PFS 封包。HarmonyOS 也可以用系统文件管理把整个目录拷到 `Download/com.nextscene.app/games`，回首页下拉刷新；「管理」页能直接看这个目录。`hdc file send` 送进去同样有效
- Cubism Live2D 插件因无 OHOS 预编译 Core 暂未编入；layerex_draw（libgdiplus 依赖）同
- 引擎日志：hilog（tag `krkr2`）与应用沙箱内 `files/flutter/krkr2-engine.log` 双通道
- 游戏页支持横竖屏切换：设置页「屏幕方向」选择默认方向（横屏 / 竖屏 / 跟随系统），游戏内覆盖层菜单可随时「旋转屏幕」



### Artemis 引擎游戏（.pfs）

OHOS 版额外内置了 [artemis-compat](https://github.com/Weiss-UltimateSavior/artemis-compat)（Artemis Engine 兼容运行时，GPL-3.0，以完整 Git submodule 固定在 `cpp/artemis/upstream`，版本及接入说明见 [INTEGRATION.md](cpp/artemis/INTEGRATION.md)），同一个 `libengine_api.so` 按游戏路径自动分发：`.pfs` 封包或含 `.pfs` 的目录走 Artemis 后端，其余走 KiriKiri2。

- 渲染：GLES2 图层合成器绘制到与 krkr2 共用的 EGL pbuffer，经 RawImage 读回呈现（静态帧按图层修订号跳过读回）；音频走 OHAudio（每声部独立 renderer）
- 导入：游戏目录需包含主包 `root.pfs` 及其补丁卷 `root.pfs.000/.001…`，存档 `*.dat` 写在同目录。放到 `Download/com.nextscene.app/games` 后回首页下拉刷新，或在「库」里用「添加游戏」选目录 / PFS。`hdc file send` 送入后同样走刷新或添加游戏注册（适配层会把封包链与存档整体拷入 cache 再迁入 files）
- 引擎行为与可复用后端在上游维护，NextScene 负责窗口、呈现与帧循环。当前构建、真机验证及限制见[接入测试记录](doc/artemis-embedding-work.md)，历史功能验证见[兼容性记录](doc/artemis-compatibility-audit.md)
- Android/iOS 的应用级验收、Apple 音频和异步 Flutter 输入弹窗仍待推进；引擎能力与已知缺口以上游固定版本为准。新克隆或切到此版本后，先执行 `git submodule update --init --recursive`
- 日志：hilog tag `Artemis`（domain `0x0207`），同时写入 `krkr2-engine.log`（前缀 `[artemis]`）



## macOS 源码构建

```bash
./build/build_macos.sh debug      # 引擎 + Flutter app（需 Xcode）
```

Live2D Cubism SDK 因再分发许可**不入库**（`cpp/plugins/cubism/` 下的 `Core/lib/` 与 `Framework/` 已 gitignore），首次构建前需自行放置：

- `Core/`：官方 [CubismSdkForNative](https://cubism.live2d.com/sdk-native/en/) 压缩包（实测 5-r.5）中的 `Core` 目录——含各平台预编译 `libLive2DCubismCore.a` 与头文件；
- `Framework/`：使用 [KiriKiri-LauncherC](https://github.com/xiaocongyu66/KiriKiri-LauncherC) 仓库内的修补版 Framework（保留 krkrlive2d.cpp 所需的 `SetDrawableForceHidden` 等扩展 API）。

引擎无 UI 冒烟验证可不依赖 Xcode/Flutter：直接链接 `out/macos/debug/bridge/engine_api/libengine_api.dylib` 调用 engine_api C 接口（`engine_open_game_async` 支持 `.xp3` 归档或解包目录），设 `KRKR_HEADLESS=1` 可让引擎跳过系统弹窗、改为 stderr 输出。

## 引擎性能优化


| 优先级 | 任务                                                         | 状态     |
| --- | ---------------------------------------------------------- | ------ |
| P0  | 像素混合 SIMD 化 ([Highway](https://github.com/google/highway)) | ✅ 完成   |
| P0  | 全 GPU 合成渲染管线                                               | 🔨 进行中 |
| P0  | TJS2 VM 解释器优化 (computed goto)                              | 📋 计划中 |




## 许可证

本项目基于 GNU General Public License v3.0 (GPL-3.0) 开源，详见 [LICENSE](./LICENSE)。

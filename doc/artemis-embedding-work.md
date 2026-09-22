# Artemis 双宿主接入：改动与测试记录

2026-09-22；NextScene 基线 d4e6ab3，上游基线 a4f8a25。

## 改动计划

1. 规范：NextScene 新增 AGENTS.md，上游保留 AGENT.md 并增加 AGENTS.md 入口，明确官方 Android 壳和嵌入宿主的兼容要求。
2. 构建：上游可作为 CMake 子工程，提供 artemis::core；独立构建保持原 CLI/macOS/Android 路线，嵌入时不默认生成宿主。显式选择 GLES/桌面 GL/无 GL 和 OpenSL/OHAudio/静音后端，平台依赖传递到最终消费者。
3. 平台：原样回流经过验证的 OHAudio 后端；按渲染后端选择 Apple GL 头与 shader 适配，不再以 __APPLE__ 代表桌面 GL。
4. 宿主：补充 EngineContext 的可选存档目录及可测试会话边界，保持原调用默认值。NextScene 接上游对象所有权，保留自己的帧驱动和窗口。旧 JNI 函数、NativeActivity 和线程行为不在本批次改写。
5. 依赖：先通过独立 checkout 联调并确认测试结果，再切完整 submodule。若上游提交尚未发布，不把主项目指到本地独有提交；保留可审查分支和明确的源码 override。

异步弹窗的完整 Flutter UI、iOS Apple 音频/纹理呈现和 GL 丢失后保留剧情属于后续能力提交；此次构建迁移不将其宣称为已实现，也不改变官方壳的默认策略。

## 测试方案

| 验证 | 内容 | 结果记录 |
| --- | --- | --- |
| 上游基线 | 宿主合成测试、macOS 原生 GL 编译；记录已有失败 | a4f8a25 原本因 LuaEngine::Init 声明/实现不匹配而编译失败；独立修复所有权后构建通过；补回已记录但遗漏的合成音调后 19/19 通过 |
| 嵌入契约 | 外部 CMake 工程只链接 artemis::core；没有多余 CLI/JNI/mac host；链接运行小型消费者 | macOS 共享库消费者链接、运行通过；Android/OHOS 交叉编译最终链接通过 |
| GLES | ANGLE 上运行 compositor 回归，检查 Apple 平台不误用桌面 GL | 23/23 通过，包含真实 compositor、GLSL ES/桌面转换和会话测试；Cocoa/OpenGL 宿主编译通过 |
| Android 官方产物 | NDK arm64/API21 编译 libartemis.so，核对必要动态导出和链接依赖 | NDK r30 编译及 cmake install 通过；12 个必要动态导出齐全；JNI 源码相对上游 main 无差异 |
| Android 嵌入产物 | JNI 关闭后构建并链接消费者，检查 OpenSL/EGL/GLES 依赖传递 | 通过，消费者无 JNI 目标；最终链接含 OpenSL/EGL/GLES |
| HarmonyOS | SDK20 core 和 NextScene engine_api 编译链接；可用时签名包真机重进测试 | 完整 engine_api + file_archive 构建通过，FFmpeg 开启；新签名 release HAP 安装成功，包内 native build ID 与本次构建一致 |
| 存档与生命周期 | 合成包验证默认/独立存档目录、启动失败清理、关闭重开、旧会话资源失效 | 合成测试通过；上游及 NextScene 包装入口均为 22/22；真机验证见下 |
| iOS | 真实 iPhoneOS SDK 构建；本机目前只有 CommandLineTools | 缺完整 Xcode，不能以 macOS 代替 |
| 官方 jar | 合法持有的原始 jar 签名核对及 Android 设备壳测试 | 本机未找到原始 jar，且无 Android 真机；未验证，不能以符号检查替代 |

测试夹具均为合成资源。没有完成的设备测试不得记为通过。提交按构建、平台、生命周期、接入和规范拆开。

## 真机记录

设备系统报告 API 26，native 使用 OpenHarmony SDK20 编译。2026-09-22
安装 `com.nextscene.app` 的新签名 release HAP，应用进程 PID 55247。

- Artemis：标题、路线选择、对话逐页点击推进及动态背景正常；日志记录 OHAudio
  音轨创建/播放。未做音频录制和主观音质对比。
- Home 退后台后重新进入，画面恢复，点击继续推进对话。
- 返回游戏库后重进同一游戏，恢复现有会话与画面。应用既有行为是暂停保留会话，
  不能把这个步骤单独当作完整销毁验证。
- 同进程 Artemis → KiriKiri → Artemis：两个标题均正常显示，PID 始终为 55247。
  切换日志包含旧 Artemis 的 `destroyed EGL context`，返回时包含
  `reusing existing EGL context` 和新的 `boot sequence finished`。
- 已覆盖退出页面时的 native window detach 和重进 attach。没有模拟 GPU 驱动
  丢失整个上下文；这种恢复仍是单独的未验证项。
- `hdc` 上传的 shell 测试 ELF 被设备拒绝执行（Permission denied），包括使用
  SDK 二进制签名工具自签后的试跑。它们完成了交叉编译，但设备执行不记作通过。

HAP 路径：`apps/flutter_app/build/ohos/hap/entry-default-signed.hap`。
包内 `libengine_api.so` build ID：`8437e64ddd0de41c61575d1aa96c47de5b704e7c`；
`libfile_archive.so`：`30aed4e85a8f1b26ee34459fb38c9d9316c5e338`。
截图、完整游戏日志和签名配置仅留本地，不提交到仓库。

## 依赖与回退

引擎固定到已发布的 `9180c6627f3f3b066f8900b1c213055224f8c252`。
构建与生命周期改动已通过上游 PR #1 合并（合并提交 `5da0b38`）：
https://github.com/Weiss-UltimateSavior/artemis-compat/pull/1。
当前指针另外包含注释与文档清理 PR #2：
https://github.com/Weiss-UltimateSavior/artemis-compat/pull/2。
上述构建与设备结果对应 `a4d922b` 的实现；此后只改注释和文档，未重新运行
设备测试。源码注释增删检查与 `git diff --check` 通过。
通用修复分为规范、Lua 音频所有权、夹具、构建后端、构建测试、会话接口与文档七个提交。
主项目的源码改 submodule 是一次机械迁移，Git 会显示大量旧文件删除；宿主 API
适配与指针一起提交以避免产生不能构建的中间版本，重复测试/音频文件清理另有提交。

新克隆先执行 `git submodule update --init --recursive`。回退时一起撤销宿主迁移
和依赖变更，不单独换回旧引擎。开发和测试命令见 `cpp/artemis/INTEGRATION.md`
及子模块内 `docs/embedding.md`。

本批次没有启用 Android/iOS 应用的 Artemis 默认入口。iOS 缺完整 Xcode，也仍缺
Apple 音频；原始 Android jar 行为、异步 Flutter 输入弹窗、真正 GL context loss
恢复和完整跨平台应用验收继续单独推进。

2026-09-22 后续核对了 Tyranor-Next 的实际 Kotlin Activity 和插件加载器，
不再以缺少原始 jar 作为该宿主接口核对的障碍。PAD 回调签名、按键/视频完成
回调和音频桥符号仍有原有兼容缺口；详情见上游 `docs/embedding.md`。
Android 设备运行仍未验证。

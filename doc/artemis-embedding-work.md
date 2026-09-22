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
| 上游基线 | 宿主合成测试、macOS 原生 GL 编译；记录已有失败 | 待执行 |
| 嵌入契约 | 外部 CMake 工程只链接 artemis::core；没有多余 CLI/JNI/mac host；链接运行小型消费者 | 待执行 |
| GLES | ANGLE 上运行 compositor 回归，检查 Apple 平台不误用桌面 GL | 待执行 |
| Android 官方产物 | NDK arm64/API21 编译 libartemis.so，核对必要动态导出和链接依赖 | 待执行 |
| Android 嵌入产物 | JNI 关闭后构建并链接消费者，检查 OpenSL/EGL/GLES 依赖传递 | 待执行 |
| HarmonyOS | SDK20 core 和 NextScene engine_api 编译链接；可用时签名包真机重进测试 | 待执行 |
| 存档与生命周期 | 合成包验证默认/独立存档目录、启动失败清理、关闭重开、旧会话资源失效 | 待执行 |
| iOS | 真实 iPhoneOS SDK 构建；本机目前只有 CommandLineTools | 缺完整 Xcode，不能以 macOS 代替 |
| 官方 jar | 合法持有的原始 jar 签名核对及 Android 设备壳测试 | 需检查资源/设备可用性 |

测试夹具均为合成资源。没有完成的设备测试不得记为通过。提交按构建、平台、生命周期、接入和规范拆开。

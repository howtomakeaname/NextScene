# NextScene 应用图标

母版是用户选定的折页 N，保存在 `assets/nextscene_icon.png`（1254 × 1254，RGB）。
该文件按原样保存，SHA-256：
`87d1c16467071c8e122a208db679484d5f20d463fbf19b05ace154c0f909c9c5`。

## 生成资源

使用 Python 3.9+、Pillow；macOS 图标沿用仓库的 `assets/apple_icon_mask.svg`，
还需要 `rsvg-convert`（librsvg）。

```sh
python3 generate_icons.py
# 只更新指定平台，可重复传入参数：
python3 generate_icons.py --platform shared --platform ohos
```

脚本只按平台处理尺寸、留白和外轮廓，不重新绘制 N。更换母版后统一重新生成，
不要分别手改各平台图片，否则下一次运行脚本会覆盖。

| 资源 | 输出 |
| --- | --- |
| Flutter「关于」页 | `assets/branding/app_icon.png` 与 `app_icon_ohos.png`，均为 512px |
| HarmonyOS | AppScope、entry、ohosTest 三处 PNG，源资源均为 1024px、不透明 |
| 商店素材 | `doc/store/app_icon_1024.png`，1024px、不透明 |
| Android | 五档密度的 legacy 与 adaptive 图标，以及背景色资源 |
| iOS | 按现有 AppIcon 的 `Contents.json` 输出尺寸；RGB 方形，由系统裁切 |
| macOS | 按现有 AppIcon 目录输出尺寸；沿用圆角蒙版和桌面留白，同时更新原生入口的 ICNS |
| Windows | ICO，包含 16、24、32、48、64、128、256px |

Android 保留原图的一体式位图前景，并缩放留出裁切区域；不使用重新生成的抠图。
当前没有新增独立标志视差或自定义单色主题层。
[Android adaptive icon 规范](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
要求 108dp 的图层和安全区；本轮核对了五档密度下标志在 66dp 圆形安全区内。

## 本轮验证（2026-09-22）

- 核对 46 项生成资源的尺寸、格式及两次生成的内容一致性。
- iOS 与商店图均无透明通道；ICO、ICNS 可解码。
- 检查 16/32/48/64px 及圆形／圆角裁切预览。
- 使用现有本地签名成功构建 HarmonyOS release HAP；包内启动图标已是新图，
  资源编译后为 512px。「关于」页两张资源的像素与生成文件完全一致。
- 当时 `hdc` 没有在线设备，未验证安装后的桌面显示；Android/iOS/macOS/Windows
  本轮仅做资源校验，未进行各平台应用构建或设备验收。

所有 Flutter 路径均相对 `apps/flutter_app`。桥接示例工程的模板图标不属于
NextScene 应用入口，本轮不修改。

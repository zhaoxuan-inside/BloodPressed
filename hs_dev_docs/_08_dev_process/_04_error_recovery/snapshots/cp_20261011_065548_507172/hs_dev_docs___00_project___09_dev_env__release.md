# 发布流程（Android / 蒲公英）

> 蒲公英 API Key 是账号私钥，**只由开发者本人持有，禁止写入仓库与环境变量持久化**。
> 每次发布由开发者手动提供（会话内临时使用）或自行网页上传。

## 1. 版本号

`pubspec.yaml` → `version: x.y.z+build`（versionName+versionCode，每次发布 build 至少 +1）。
本次记录：**1.2.0+2**（2026-10-11，前一版 1.0.0+1）。

## 2. 门禁（发布前必须全绿）

```bash
flutter analyze          # 0 issue
flutter test             # 全绿
```

## 3. 打包（Git Bash）

```bash
export JAVA_HOME='D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1'   # Gradle 需 JDK 17+，shell 默认 JVM 8 会失败
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

## 4. 上传蒲公英

**网页方式**：https://www.pgyer.com → 登录 → 发布应用 → 拖入 APK → 填更新日志 → 发布。

**命令行方式**（Key 由开发者临时提供）：

```bash
curl -F "file=@build/app/outputs/flutter-apk/app-release.apk" \
     -F "_api_key=<你的蒲公英APIKey>" \
     -F "buildUpdateDescription=<更新日志，见下方>" \
     https://www.pgyer.com/apiv2/app/upload
```

响应 `code: 0` 即成功；返回的 `buildShortcutUrl`（https://www.pgyer.com/xxxx 二维码短链）即分发页。

## 5. 发布记录

| 版本 | 日期 | 产物 | SHA1 | 状态 |
|---|---|---|---|---|
| 1.2.0+2 | 2026-10-11 | build/app/outputs/flutter-apk/app-release.apk（328.7MB，minSdk 24） | d8557587f239492ffaa258d699888a3b7ce26f42 | 已构建，待上传蒲公英（Key 由开发者手动提供） |

## 6. 更新日志模板（发布时填入）

```
本次更新（1.2.0）：
1. 内置默认模型：首次使用引导下载 Qwen3-1.7B，AI 功能开箱即用（低置信问题自动拒答）
2. 模型中心：搜索/下载/安装一站式，同时接入多个模型社区
3. 功能搜索：首页搜索直达全部功能与设置项
4. 趋势页：全屏横屏图表、血压规律分析（时段/星期/峰值）、一键 AI 分析、图表与规律分享
5. 修复与优化：APK 减重约 30MB、OCR 反光场景识别更稳、语音录入文案国际化
```

## 7. 发布检查单

- [ ] pubspec 版本已升级且 build 递增
- [ ] analyze 0 + 全量测试绿
- [ ] release APK 构建成功（真机安装冒烟：登录/录音/相机权限首启弹窗）
- [ ] 更新日志已填写
- [ ] 上传后用分发短链真机安装验证版本号与核心功能（拍照识别/内置模型问答/趋势全屏）
- [ ] 版本提交已 commit（含 pubspec 与本文档的发布记录）

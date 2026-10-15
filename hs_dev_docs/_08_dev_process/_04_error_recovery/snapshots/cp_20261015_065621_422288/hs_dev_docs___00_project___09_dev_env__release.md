# 发布流程（Android / 蒲公英）

> 蒲公英 API Key 是账号私钥，**只由开发者本人持有，禁止写入仓库与环境变量持久化**。
> 每次发布由开发者手动提供（会话内临时使用）或自行网页上传。

## 1. 版本号

`pubspec.yaml` → `version: x.y.z+build`（versionName+versionCode，每次发布 build 至少 +1）。
本次记录：**1.2.1+3**（2026-10-15，前一版 1.2.0+2）。

## 2. 门禁（发布前必须全绿）

```bash
flutter analyze          # 0 issue
flutter test             # 全绿
```

## 3. 打包（Git Bash）

```bash
export JAVA_HOME='D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1'   # Gradle 需 JDK 17+，shell 默认 JVM 8 会失败
flutter build apk --release --target-platform android-arm64
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

发布仅支持 ARM64（arm64-v8a）手机；release 构建配置排除 32 位原生库。
实际过滤位于 app defaultConfig.ndk，配合 gradle.properties 的
`disable-abi-filtering=true` 防止 Flutter 自动重新加入其他 ABI；不使用 --split-per-abi。
当前 release 沿用 debug 签名；尚未配置正式发布证书。

Windows PowerShell 本机命令（Flutter SDK 不在 PATH）：

```powershell
$env:JAVA_HOME = 'D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1'
New-Item -ItemType Directory -Force -Path "$PWD\build\java-tmp" | Out-Null
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$PWD\build\java-tmp"
& 'E:\HardStone.Flutter\flutter\bin\flutter.bat' --no-version-check build apk --release --target-platform android-arm64 --no-pub
```

此 Java 临时目录参数仅在当前 PowerShell 进程生效，用于规避本机默认临时目录下
Java NIO `Unable to establish loopback connection` / `UnixDomainSockets.connect0` 错误。

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

2026-10-15：**1.2.1+3 ARM64** 构建成功，170,668,649 字节（162.76 MiB），
产物 `build/app/outputs/flutter-apk/BloodPressed-1.2.1+3-arm64-v8a.apk`。
SHA256：`1cb46adf70dc0ef962c7691769b7b33dd77a13997dfad96a0214a9dda3323f60`。
aapt 与 ZIP 检查均确认仅 `arm64-v8a`，minSdk 24，versionCode 3；apksigner v2 验证通过。
包含 7027013 的离线语音模型下载修复。未上传蒲公英，未进行真机安装冒烟。

| 版本 | 日期 | 产物 | SHA1 | 状态 |
|---|---|---|---|---|
| 1.2.0+2 | 2026-10-11 | build/app/outputs/flutter-apk/app-release.apk（328.7MB，minSdk 24） | d8557587f239492ffaa258d699888a3b7ce26f42 | 已构建，待上传蒲公英（Key 由开发者手动提供） |

## 6. 更新日志模板（发布时填入）

```
本次更新（1.2.1）：
1. 增加离线语音识别兜底，系统语音不可用时可下载离线模型。
2. 修复语音模型下载：正确断点续传、中断重试、文件大小校验与进度累计。
3. 发布包仅保留 ARM64，不再兼容 32 位系统。
```

## 7. 发布检查单

- [ ] pubspec 版本已升级且 build 递增
- [ ] analyze 0 + 全量测试绿
- [ ] release APK 构建成功（真机安装冒烟：登录/录音/相机权限首启弹窗）
- [ ] 更新日志已填写
- [ ] 上传后用分发短链真机安装验证版本号与核心功能（拍照识别/内置模型问答/趋势全屏）
- [ ] 版本提交已 commit（含 pubspec 与本文档的发布记录）

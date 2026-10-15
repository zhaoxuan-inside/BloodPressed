# 发布流程（Android / 蒲公英）

> 蒲公英 API Key 是账号私钥，**只由开发者本人持有，禁止写入仓库与环境变量持久化**。
> 每次发布由开发者手动提供（会话内临时使用）或自行网页上传。

## 1. 版本号

`pubspec.yaml` → `version: x.y.z+build`（versionName+versionCode，每次发布 build 至少 +1）。
本次记录：**1.2.2+4**（2026-10-15，前一版 1.2.1+3）。

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

2026-10-15：**1.2.4+6 ARM64（隐私授权与正式身份）**，双包：

- 商店包 `build/app/outputs/flutter-apk/BloodPressed-1.2.4+6-arm64-v8a-store.apk`，220,034,939 字节。
  SHA256 `2c92a369751ff283fbc21ab5263ec3bfdcc4958c07f80649d2ce0bd0915df762`。
  包名 `com.zhaoxuan.bloodpressed`，正式证书 SHA256 `87c43a7a7f202eeceb64477b17cad8b0ec4fbb3c3ab43b7fc28ac249245ba8b9`。
- 覆盖测试包 `build/app/outputs/flutter-apk/BloodPressed-1.2.4+6-arm64-v8a-legacy-test.apk`，220,034,923 字节。
  SHA256 `775c8160fba9658601683890437e431ce8dd81885c235fbf294e2e83f8e5bc73`。
  包名 `com.example.blood_pressed`，保持旧调试证书，供已有测试版覆盖安装。

两包 versionName 1.2.4、versionCode 6、minSdk 24、targetSdk 36、仅 arm64-v8a，v2 签名验证通过。
正式身份与测试身份独立，已有数据继续留在旧测试版中；正式包不自动继承旧包数据。
首启同意前不启动业务，远端健康信息单独授权可撤回，云同步及账号登录占位入口隐藏。
281 项全量测试通过、静态分析无问题。政策网页更新提交 gh-pages 3f6f1f5，HTTP 200 已验证。
密钥在仓库外创建；备份与构建说明见 `docs/android-signing.md`。未做真机安装或商店 SDK 检测。

2026-10-15：**1.2.3+5 ARM64（设置优化与隐私政策）**，219,968,959 字节（209.78 MiB）。
产物 `build/app/outputs/flutter-apk/BloodPressed-1.2.3+5-arm64-v8a.apk`。
SHA256：`e884ac09c5858c56b2b48eb00c161db996eba48a4f76ac86103aa893e3097e1a`。
versionName 1.2.3、versionCode 5、minSdk 24、targetSdk 36，仅 arm64-v8a，v2 签名验证通过；证书与 1.2.2 一致，仍为调试证书。
隐藏“微信分享配置”设置及搜索入口，保留分享链路；增加离线隐私政策，APP 与网页同源。
公开页面 <https://zhaoxuan-inside.github.io/BloodPressed/privacy-policy/> 已验证 HTTP 200，运营者赵宣、邮箱 zhaoxuanmail@163.com。
全量 277 项测试通过、静态分析无问题；APK 中四个语音模型 SHA256 与源文件一致，ORT 1.28.2 保留。
未进行真机安装与麦克风验证；完整上架前仍需首启同意、健康数据单独授权、SDK 初始化时机及正式签名改造，详见 `docs/privacy-policy/README.md`。

2026-10-15：**1.2.2+4 ARM64（内置离线语音模型）**，219,963,720 字节（209.77 MiB）。
产物 `build/app/outputs/flutter-apk/BloodPressed-1.2.2+4-arm64-v8a.apk`。
SHA256：`2e9a0af033fb26bfecebdbf3bf46d4b7dee926ab7ee3818cdb93ceb3f3a9d908`。
版本及 ABI 验证：versionName 1.2.2、versionCode 4、仅 arm64-v8a、minSdk 24；v2 签名验证通过，签名证书与 1.2.1 相同。
四个语音模型资源在 APK 内逐个核对 SHA256，ORT 确认为 1.28.2，旧 1.17.1 已排除。
全量 276 项测试与静态分析通过，真实双语音频识别通过，OCR det/rec 在新 ORT 推理通过。
未上传分发平台，未连接手机做麦克风验证。

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
本次更新（1.2.4）：
1. 增加首启隐私同意、拒绝和撤回流程，同意后才启动业务。
2. 远端健康信息发送需单独授权，接收方/模型变化重新确认，支持撤回。
3. 隐藏尚未接入的云同步和登录入口，更新隐私政策正文。
4. 提供正式签名商店包和旧身份覆盖测试包，均为 ARM64。
```

## 7. 发布检查单

- [ ] pubspec 版本已升级且 build 递增
- [ ] analyze 0 + 全量测试绿
- [ ] release APK 构建成功（真机安装冒烟：登录/录音/相机权限首启弹窗）
- [ ] 更新日志已填写
- [ ] 上传后用分发短链真机安装验证版本号与核心功能（拍照识别/内置模型问答/趋势全屏）
- [ ] 版本提交已 commit（含 pubspec 与本文档的发布记录）

## 8. 语音原生库回归检查

Android app 的本地 jniLibs 与 onnxruntime 插件旧运行库不参与打包；统一使用
sherpa_onnx 的 ORT。不要手工复制旧 libonnxruntime.so 到 app 的源码目录。

宿主真实语音验证（无需麦克风，使用固定官方音频与生产同一模型配置）：

```powershell
& 'E:\HardStone.Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe' --packages=.dart_tool/package_config.json scripts/verify_voice_model.dart
```

包内须有 assets/flutter_assets/assets/models/voice/ 下的 encoder.int8.onnx、
decoder.onnx、joiner.int8.onnx、tokens.txt，字节与 assets/models/voice 相同。
`lib/arm64-v8a/libonnxruntime.so` 本次要求 1.28.2；原库 1.17.1 无法满足语音引擎 API 28。

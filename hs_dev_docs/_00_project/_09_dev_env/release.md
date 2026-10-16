# 发布流程（Android / 蒲公英）

> 蒲公英 API Key 是账号私钥，**只由开发者本人持有，禁止写入仓库与环境变量持久化**。
> 每次发布由开发者手动提供（会话内临时使用）或自行网页上传。

## 1. 版本号

按 hs-dev-skill 四段式：`MAJOR.FEATURE.PATCH.BUILD`。本次功能版本为 `1.3.0`。

- `pubspec.yaml` 保持 Flutter 格式 `1.3.0+BUILD`；APK 内 `versionName` 为 `1.3.0.BUILD`，`versionCode` 为整数 BUILD。
- 唯一打包入口为 `scripts/build_android_release.ps1`。每次调用自动预留新 BUILD，优先使用上海时区 `MMddHHmmss`；同秒重复、时钟回拨或跨年时使用上次号 +1，保证 Android code 严格递增。失败构建也不回收版本号。
- 脚本持有项目独占锁，禁止并行发包；构建后校验实际 APK 的 versionName/versionCode、身份、ABI 与签名，不允许只改文件名冒充新版。
- 可交付文件位于 `output/mobile/BloodPressed-v1.3.0.BUILD-android-arm64-store.apk`；相邻 `.sha256` 和 `.json` 记录校验值、版本、构建时间、源码基线及工作区状态，符号表按完整版本归档。
- 正式包与旧身份覆盖测试包也各自获得新 BUILD；已有产物拒绝覆盖。`build/` 只是可变的中间输出，不再作为唯一交付归档。
- 不直接运行原始 `flutter build apk` 作为对外出包入口，也不手动改名替代版本升级。

## 2. 门禁（发布前必须全绿）

```bash
flutter analyze          # 0 issue
flutter test             # 全绿
```

## 3. 打包（Windows PowerShell）

```powershell
$env:JAVA_HOME = 'D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1'
& .\scripts\test_release_version.ps1
& .\scripts\build_android_release.ps1 -FlutterPath 'E:\HardStone.Flutter\flutter\bin\flutter.bat'
# 旧测试身份包另加 -Legacy，仍自动预留独立版本。
```

脚本自动配置 Java 临时目录参数，规避本机 NIO loopback / UnixDomainSockets 问题。
仅打 ARM64；正式包使用仓库外的正式签名，缺少签名时拒绝回退至 debug。
签名与覆盖安装身份说明见 `docs/android-signing.md`。

## 4. 上传蒲公英

**网页方式**：https://www.pgyer.com → 登录 → 发布应用 → 拖入 APK → 填更新日志 → 发布。

**命令行方式**（Key 由开发者临时提供）：

```bash
curl -F "file=@output/mobile/<本次完整版本APK文件名>" \
     -F "_api_key=<你的蒲公英APIKey>" \
     -F "buildUpdateDescription=<更新日志，见下方>" \
     https://www.pgyer.com/apiv2/app/upload
```

响应 `code: 0` 即成功；返回的 `buildShortcutUrl`（https://www.pgyer.com/xxxx 二维码短链）即分发页。

## 5. 发布记录

2026-10-16：**1.3.0.1016162951 Android ARM64（版本治理修正及测量趋势）**。

- 用户指出先前多个出包复用了 `1.2.4+6`；旧文件名无法可靠区分内部版本。本次开始由脚本自动预留、实际核验并归档每个构建。
- APK 内 versionName `1.3.0.1016162951`、versionCode `1016162951`，pubspec 为 `1.3.0+1016162951`。
- `output/mobile/BloodPressed-v1.3.0.1016162951-android-arm64-store.apk`，219,969,627 字节。
- SHA256 `50cf513ae61be0b5a0ea4e24f7a56fadb2e83e2a97ba631f3003fc36fe576464`。
- 旁附 `.sha256`、`.json` 回执，符号表位于 `output/mobile/symbols/1.3.0.1016162951-store/`。
- manifest 版本、正式身份 `com.zhaoxuan.bloodpressed`、ARM64、签名经实际产物核验；304 项测试与静态分析通过。未上传、未做真机安装。
- 业务内容：每次测量趋势、缺日/缺项断线、单项血压及同次脉压差、单日展开与直接数值标注。


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
本次更新（1.3.0.1016162951）：
1. 保留每次血压测量，支持缺项留空、缺测断线及同次脉压差。
2. 单日视图展开密集读数，显示数值、时刻，并支持同步横滑与编辑。
3. 每次打包自动生成独立版本，核验 APK 内版本，归档校验值、回执及符号表。
```

## 7. 发布检查单

- [ ] 经官方脚本预留新 BUILD，APK 内四段 versionName 和递增 versionCode 与回执一致
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

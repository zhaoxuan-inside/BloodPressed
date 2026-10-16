# Android 正式签名

用户于 2026-10-15 确认：无既有商店包名或必须沿用的正式密钥。

- 商店包名：`com.zhaoxuan.bloodpressed`；默认 release 必须使用正式密钥。
- 正式证书 SHA256：`87c43a7a7f202eeceb64477b17cad8b0ec4fbb3c3ab43b7fc28ac249245ba8b9`。
- 覆盖测试包：`com.example.blood_pressed`，显式 `bloodPressedLegacy=true` 使用原 debug 证书。
- 两种身份不同，正式包不会自动继承测试包的本地记录；测试旧数据继续保留在原包中，不要为安装正式包而卸载旧包。
- namespace 保留已有 Kotlin 代码命名，与应用发布包名独立。

`scripts/init_android_signing.ps1` 只在不存在密钥时生成 RSA 3072 / PKCS12 身份，已有身份不会覆盖。
本机路径为 `C:/Users/hardstone/.bloodpressed-signing/`；目录包含私钥、密码配置和公开证书，权限限制为当前 Windows 用户。
请将整个目录备份到你控制的加密存储；私钥和密码缺失会影响后续版本更新，勿发给他人或提交 Git。
Gradle 默认读取当前用户该目录的 signing.properties，也可通过 `BP_SIGNING_PROPERTIES` 指定路径。
正式 release 缺失配置会构建失败，不会退回调试签名。仓库只保存生成脚本，不保存私钥及密码。

```powershell
$env:JAVA_HOME = 'D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1'
./scripts/init_android_signing.ps1
./scripts/build_android_release.ps1 -FlutterPath 'E:/HardStone.Flutter/flutter/bin/flutter.bat'
./scripts/build_android_release.ps1 -FlutterPath 'E:/HardStone.Flutter/flutter/bin/flutter.bat' -Legacy
```

产物分别有 `-store.apk` 与 `-legacy-test.apk` 后缀，并附 SHA256。
脚本显式通过 Flutter `--android-project-arg` 传递构建身份，并校验实际 APK 包名、ABI 和签名后才复制到命名产物，避免环境变量未生效导致两个包身份相同。
提交商店使用 store 包；已有测试版覆盖安装使用 legacy-test 包。
正式包改了包名和证书，若以后使用微信原生 SDK 直接分享，开放平台登记也需匹配新身份；未配置时继续走系统分享。
操作系统权限/SDK 检测及 OPPO/vivo 审核需对最终 store 包进行，不能用测试包检测结果替代。

每次脚本调用都会预留独立的打包版本。交付 APK、SHA256、JSON 回执及对应符号表归档在 `output/mobile/`，不能只改文件名复用版本。以脚本最终打印的完整版本和产物路径为准。

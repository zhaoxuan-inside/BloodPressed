# TD-001：google_mlkit_text_recognition 双依赖清理（已解决）

- 状态：**resolved**（2026-10-11，任务 td-001-mlkit，change_size=S）
- 发现：plan-006 用 PP-OCRv5 ONNX（onnxruntime）+ 自研七段码路径替换 ML Kit 后，Dart 层零引用，但依赖声明与原生层配置未清理。

## 处置（三层全拆）

| 层 | 移除内容 |
|---|---|
| pubspec.yaml | `google_mlkit_text_recognition: ">=0.14.0 <0.21.0"` 及注释 |
| android/app/build.gradle.kts | `implementation("com.google.mlkit:text-recognition-chinese:16.0.1")`（plan-003 崩溃修复时捆绑的中文模型）；minSdk 注释同步更新 |
| android/app/proguard-rules.pro | 8 行 `-dontwarn` + 4 行 `-keep class com.google.mlkit/**`，文件清空保留规则入口 |

## 验证

- `flutter pub get` 后 `.flutter-plugins-dependencies` / `pubspec.lock` 零 mlkit 残留
- `flutter analyze` 0 issue；`flutter test` 146/146 绿
- **release APK 构建成功（R8 全量混淆通过）**：328.3MB，较移除前（Oct 7 产物 358.6MB）**减重约 30MB**（bundled 中文 OCR 模型 + GMS 内部库 + 插件原生代码）

## 备注

- 真机拍照识别冒烟建议随下次 `flutter run --release` 例行确认（OCR 主路径为七段码专用引擎，不经 ML Kit）。
- Gradle 构建需 JDK 21：`JAVA_HOME=D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1`（shell 默认 JVM 8 会报 "Gradle requires JVM 17 or later"）。
- 遗留观察：flutter_timezone / share_plus 插件仍 apply 旧版 Kotlin Gradle Plugin（Flutter 构建警告，未来需插件侧升级）。

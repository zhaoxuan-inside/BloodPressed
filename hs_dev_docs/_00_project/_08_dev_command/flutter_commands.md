# 开发命令（Windows 宿主）

Flutter SDK 不在 PATH：`E:\HardStone.Flutter\flutter`（Git Bash 用 `/e/HardStone.Flutter/flutter/bin/flutter.bat`）。
Python 用 `py -3`（Git Bash 里无 `python`/`python3`）。

## 日常命令

| 用途 | 命令 |
|---|---|
| 依赖安装 | `flutter pub get` |
| 静态分析（门禁） | `flutter analyze` —— 要求 0 issue |
| 全量测试（门禁） | `flutter test` —— 要求全绿 |
| 单文件测试 | `flutter test test/xxx_test.dart` |
| 按名过滤测试 | `flutter test --plain-name "测试名"` |
| 生成 l10n | `flutter gen-l10n`（arb 在 `lib/l10n/app_{zh,en}.arb`） |
| 运行 Android | `flutter run`（设备/模拟器） |
| 构建产物 | `flutter build apk --release` |

## 测试环境要点

- 测试夹具：`test/support/real_test_harness.dart`（内存 SQLite via sqflite_ffi NoIsolate + 真实仓库）。
- `speech_to_text` 平台通道在夹具中 mock 为「设备不支持」（否则录入页初始化抛 MissingPluginException）。
- UI 集成测试用 `RealNetworkWidgetsBinding` + `pumpUntilReal`（sqflite_ffi 回包需要真实事件循环）。
- 中文断言依赖 `settings.setLocalePref('zh')`（夹具已固定）。
- Windows 插件符号链接需要开发者模式（影响 `flutter pub get` 后的插件装配，不影响 `flutter test`）。

## 已知约束

- `pubspec.yaml` 的 sqlite3 构建钩子走 ghproxy 镜像（国内网络直连 GitHub 超时）。
- PP-OCR 模型资产在 `assets/models/ppocr/`；知识文章在 `assets/knowledge/{,en/}`。
- 分析排除目录：`build/ android/ ios/ linux/ hs_dev_docs/`（见 analysis_options.yaml）。

## hs-dev-skill 工具（根目录执行）

| 用途 | 命令 |
|---|---|
| 续做扫描 | `py -3 C:\Users\hardstone\.agents\skills\hs-dev-skill\scripts\process_log.py resume-scan` |
| 改文件前快照 | `… process_log.py checkpoint --id <task> --step <S?> --summary … --paths a,b,c` |
| 任务卡 | `… task_manager.py create/status` |
| 提交前门禁 | `… verify_consistency.py --root .` |
| 文档检索 | `… doc_index_db.py --root . search --q 关键词` |

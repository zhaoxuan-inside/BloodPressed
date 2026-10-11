# TD-001：google_mlkit_text_recognition 双依赖待清理

- 状态：open（登记于 2026-10-11，rebuild-001）
- 发现：plan-006 已用 PP-OCRv5 ONNX（`onnxruntime`）+ 自研七段码路径**替换**了 ML Kit 作为识别引擎，但 `pubspec.yaml` 仍保留 `google_mlkit_text_recognition` 依赖，`lib/features/camera_ocr/data/image_utils.dart` 等处可能仍有引用。
- 影响：APK 体积（ML Kit 中文模型 ~20MB+）、构建复杂度（plan-003 曾因 ML Kit R8 keep 规则崩溃）。
- 处置建议：确认 `lib/` 内已无 `google_mlkit` import 后，从 pubspec 移除依赖并清理 android 配置（R8 keep / proguard）。
- 验证方式：移除后全量测试绿 + release 构建成功 + OCR 流程真机冒烟。

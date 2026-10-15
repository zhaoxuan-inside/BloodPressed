# 任务详细设计与执行记录：voice-builtin-003

- **任务名称**：内置离线语音模型并修复初始化不可用
- **变更分级**：`M`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **开始时间**：`2026-10-15T06:46:58Z`
- **最后更新**：`2026-10-15T07:09:43Z`

---

## 1. 任务背景与目标
ARM64安装包内置离线语音模型，系统语音缺失时无需下载即可录入，修复Zipformer模型加载并提供可重试诊断

---

## 2. 验收标准
真实模型加载解码通过，离线初始化失败可诊断重试，完整模型在APK内，ARM64打包验收通过

### 触达面冻结（M / IMPLEMENT）
- 用户明确要求模型内置：现有约 50 MB 四个文件随 assets 打包，首次离线使用从包内解包到应用目录，无 HTTP 请求。
- 保留现有系统语音优先与离线兜底路径；旧的下载文件与新资源使用相同模型及文件名，精确大小校验后可复用。
- Zipformer 模型类别从 ONNX 元数据识别，不强制错误的 zipformer2。
- 初始化异常保留技术原因供复制报告；用户提示初始化失败且点击可重试，禁止永久禁用按钮。
- 不变更 DB/API/血压解析规则；只增加 Android 系统语音包可见性声明。
- UI 流程：录入页 → 初始化（包内准备）→ 麦克风录入；失败 → 错误报告 → 点击重试。
- Seam：BundledVoiceModelStore 的真实文件复制（无网络/短文件/失败恢复/重复调用）；Sherpa 服务加载真实模型与音频；Notifier 初始化异常恢复；最终 APK 资产与 ABI 检查。
- 自动化无法证明手机麦克风录音链路；当前 adb 未发现连接设备，最终明确真机验证边界。

---

## 3. 执行步骤 (Checklist)
- [x] 1. M 触达面冻结与接口契约，见验收标准。
- [x] 2. 无 DB/API 变更；模型 assets 为现有约 50 MB 四件套。
- [x] 3. 包内准备、自动模型类别、可重试初始化错误、停止冲刷与释放原生资源。
- [x] 4. 离线部署与重试回归 + 真实语音推理 + OCR/新 ORT 兼容验证。
- [x] 5. 276 项测试、静态分析、ARM64 构建、APK 内容/版本/签名验证与文档门禁。

---

## 4. 涉及文件修改清单 (Diff Tracking)
```text
assets/models/voice/ （完整模型、许可与来源）
lib/features/records/data/bundled_voice_model_store.dart
lib/features/records/data/offline_voice_config.dart
lib/features/records/data/offline_voice_service.dart
lib/features/records/data/voice_input_service.dart
lib/features/records/presentation/controllers/voice_input_provider.dart
android/app/src/main/AndroidManifest.xml
android/app/build.gradle.kts
android/build.gradle.kts
pubspec.yaml
test/bundled_voice_model_store_test.dart
test/voice_input_notifier_test.dart
test/onnx_runtime_compatibility_test.dart
test/support/real_test_harness.dart
test/fixtures/voice/0.wav
scripts/verify_voice_model.dart
```

---

## 5. 验证与门禁记录
- 真实原生复现：旧 modelType=zipformer2 配置报 query_head_dims 元数据缺失；自动识别 Zipformer v1 后识别官方双语音频成功。
- 模型获取：魔搭固定 revision=00710ef42664d2f9ebc25da91c556526177674d3，四个模型文件与音频均核对 SHA256；许可来源见 assets/models/voice/NOTICE.md。
- 新增部署/初始化恢复回归，定向测试 33 项通过。
- 新 ORT 1.28 的实际 OCR det/rec 模型推理测试通过，验证 OCR API 15 向后兼容。
- 包内原生库缺陷：旧 APP 的 libonnxruntime.so=1.17.1，优先取自本机 ignored app/src/main/jniLibs；排除 app 与 OCR 插件旧副本，统一使用 sherpa 运行时。
- 生命周期回归：离开页面释放系统及离线服务；重进页面重新创建，防止复用已释放引擎。修复前测试失败，修复后通过。
- 全量 276 项测试通过，flutter analyze 无问题；真实语音脚本成功识别双语 WAV。
- 首轮 APK 验包：仅 arm64-v8a，四件套模型 SHA256 与源文件一致，运行库 1.28.2。
- 最终 APK：BloodPressed-1.2.2+4-arm64-v8a.apk，219,963,720 字节；同样仅 ARM64，四个模型 SHA256 与源文件一致，ORT 1.28.2，v2 签名验证通过。
- SHA256：2e9a0af033fb26bfecebdbf3bf46d4b7dee926ab7ee3818cdb93ceb3f3a9d908。
- 真机边界：adb 未发现设备；此轮完成宿主真实模型推理、APK 内容与签名验证，不声称已通过手机麦克风冒烟。

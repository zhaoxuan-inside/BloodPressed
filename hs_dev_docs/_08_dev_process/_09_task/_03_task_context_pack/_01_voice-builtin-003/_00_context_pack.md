# 上下文装载包 (Context Pack)：voice-builtin-003

- **change_size**：`M`
- **任务 ID**：`voice-builtin-003`
- **生成时间**：`2026-10-15T06:46:58Z`
- **状态**：`COMPLETED`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **查询**：`doc_index_db.py --root . search|slice`；Skill 详规用 `skill_ref_index.py search`（勿通读 references/）

---

## 1. 需求与目标（物化）
ARM64安装包内置离线语音模型，系统语音缺失时无需下载即可录入，修复Zipformer模型加载并提供可重试诊断

用户反馈录入页仍显示“当前设备不支持语音识别”，明确要求模型随包内置。
验收：无系统语音时使用包内模型，首次只从 assets 解包，不下载；真实模型加载识别成功；初始化失败保留诊断且可重试。
UI：录入 → 包内准备 → 录音；权限不足走现有授权入口；失败显示现有错误报告并可重试。
保持 ARM64 与现有 debug 签名，版本 1.2.2+4。

---

## 2. 数据模型切片（物化）
N/A：无 DB schema 变更。模型沿用既有应用模型目录；四个本地文件长度须匹配清单，旧有效文件可复用。

---

## 3. 接口与六元组签名（物化）
BundledVoiceModelStore implements VoiceModelStore：download() 仅从 AssetBundle 复制；并发共用 Future；失败可重试；isDownloaded() 校验落盘文件。
SherpaOfflineInputService.initialize()：缺失时先复制 assets；按 ONNX 元数据确定模型类别；失败抛 VoiceInitializationException。
VoiceInputNotifier：区分初始化失败与设备不支持，保留原始错误供复制报告，点击麦克风重试。
Android 原生库：单份 ORT 由 sherpa 提供，排除 app ignored 旧库与 OCR 插件旧库。

---

## 4. 调用链与 Mock 契约（物化）
录入页 → 系统 STT 不可用 → 权限检查 → Sherpa.initialize → BundledVoiceModelStore.download（本地复制）→ 模型元数据识别 → 麦克风PCM → 文本 → 原有血压解析。
测试 seam：真实模型文件部署与损坏恢复、Notifier 初始化异常、共享配置下的原生双语 WAV 推理、OCR 模型在新 ORT 实际推理、APK 模型 SHA256/ABI/ORT 版本检查。
Widget 宿主无麦克风，权限通道明确模拟拒绝，原生推理由独立检查覆盖。

---

## 5. 查询轨迹（降 Token）
- 续做扫描 0 活跃任务；在当前 voice-builtin-003 中继续，不重新开需求。
- 已读：hs-dev-skill、load_latch、process_continuity、testing；项目 DESIGN.md。
- 外部依据：sherpa 官方模型文档、C++ 模型类别分发代码；原模型 HF Apache-2.0 声明。
- 最终证据：276 项测试通过，静态分析无问题，生产配置识别官方 WAV 成功；APK 1.2.2+4 仅 ARM64，四个模型与 SHA256、ORT 1.28.2 及签名验证均通过。

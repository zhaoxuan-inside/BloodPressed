# 任务详细设计与执行记录：voice-fix-001

- **任务名称**：修复语音录入真机不可用：错误被吞卡死聆听中+权限未申请+中文数字解析缺口
- **变更分级**：`M`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：agent
- **开始时间**：`2026-10-11T07:25:37Z`
- **最后更新**：`2026-10-11T07:50:04Z`

---

## 1. 任务背景与目标

用户真机实测反馈：语音录入"不可用，没有正确的生成内容"。

模拟器（emulator-5554，Android 15）复现取证（release 1.2.0+2）：
- 点击麦克风 → UI 进入"正在聆听…"，90 秒后仍停留在聆听态，无结果、无反馈；
- logcat 确认识别服务会话已建立（`RecognitionService#onStartListening`）。

缺陷链（四项）：
1. **运行时麦克风权限从未申请**：`permission_handler` 仅用于相机 OCR 与提醒；语音链路无
   `Permission.microphone.request()`。模拟器靠 Google 特权识别服务的 attribution 跳过权限检查，
   真机（无 GMS/严格 ROM）上无权限时识别服务直接失败。
2. **错误被吞**：`initialize(onError: (_) {})` 空实现 + 无 status 监听；`cancelOnError: true`
   下错误伴随会话静默取消，UI 永远卡在"正在聆听…"。
3. **无兜底超时**：`listenFor/pauseFor` 依赖平台识别服务行为，无音频输入/部分 ROM 上不生效。
4. **解析缺口**：中文 STT 逐位读法（"一三五"→135、"一六零"→160）、20~39 十位段
   （"二十八"）、"血压"关键词开头、"血压 128/85" 斜杠混排均解析失败。

## 2. 修复设计

- `VoiceInputService` 抽象为接口（测试 seam），平台实现 `SpeechToTextInputService`：
  - `startListening` 前置 `Permission.microphone.request()`（可注入，测试用），
    拒绝 → `VoiceInputError.permissionDenied`；
  - `onStatus` 挂 `initialize()`（插件 7.5.0 契约：`listen()` 无 onStatus 参数），
    用 sink 字段中转到当次会话回调；`listen()` 包 try/catch → `unknown`。
- `VoiceInputNotifier` 状态机可靠性约定：会话无论以何种方式结束都必须在有限时间内离开 listening：
  - 最终结果 → done + 解析；错误 → error + 用户可读消息（UI snackbar）；
  - status done/notListening 且无最终结果 → partial 降级解析（有内容）或 idle + "未听到内容"；
  - **18s 看门狗**兜底插件层静默挂起（无回调时 stop + 降级/报错）。
- UI：`_onVoiceResult` 新增 error 分支 → snackbar + consumeResult 复位。
- Parser：`血压` 入 sys 关键词表；十位正则扩至 20~99；新增逐位中文数字转换（含"零"，
  在百/十组合转换之后执行避免吞"八十五"）；斜杠回退条件放宽为 `dia == null`（兼容"血压 128/85"）。

## 3. 执行步骤 (Checklist)
- [x] 1. 模拟器复现取证（release 包卡死聆听复现 + logcat 定位）
- [x] 2. Service 接口化 + 权限门 + onError/onStatus 转发
- [x] 3. Notifier 错误/状态兜底自恢复 + 18s 看门狗 + partial 降级解析
- [x] 4. Parser 四项解析缺口修补
- [x] 5. UI error 分支 snackbar
- [x] 6. 测试：parser 新增 8 用例；notifier 状态机 11 用例（fake_async 驱动看门狗）；
       SpeechToTextInputService 3 用例（mock method channel + 注入权限钩子）
- [x] 7. 模拟器回归：debug 包装机后点麦克风 → 聆听态在 ~20s 内自动恢复为可再次触发（旧版永久卡死）

## 4. 涉及文件修改清单 (Diff Tracking)
```text
lib/features/records/data/voice_input_service.dart        （重写：接口化 + 权限 + 回调契约）
lib/features/records/presentation/controllers/voice_input_provider.dart （重写：状态机可靠性）
lib/features/records/presentation/record_edit_page.dart   （error 分支 snackbar）
lib/features/records/domain/bp_voice_parser.dart          （关键词/十位/逐位/斜杠 四项修补）
test/bp_voice_parser_test.dart                            （+8 用例）
test/voice_input_notifier_test.dart                       （新增 14 用例）
pubspec.yaml                                              （dev_dependencies + fake_async）
```

## 5. 验证与门禁记录
- flutter analyze：`No issues found`
- 全量测试：`244 passed`（含新增 22 项语音用例）
- 模拟器回归：修复版点麦克风后不再卡死；权限申请路径生效（RECORD_AUDIO granted）
- 契约比对：`OK`（VoiceInputError 错误码为上层唯一出口；provider 注入点 voiceInputServiceImplProvider 可 override）

## 6. 遗留与建议
- 真机端最终确认需在用户设备复测（不同 ROM 识别服务差异较大）；若仍无内容，
  UI 现在会给出明确错误反馈（权限/未听到/出错重试），可按提示定位。
- `_VoiceMicRow` 与 record_edit_page 存在硬编码中文文案，未纳入本任务范围（沿用现状）。

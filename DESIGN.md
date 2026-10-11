# DESIGN.md — BloodPressed 项目身份

> 本文件是项目身份唯一入口：产品是什么、技术栈、架构分层、关键约束。
> 过程性文档在 `hs_dev_docs/`；历史任务结论见 `hs_dev_docs/_00_project/_05_decision_record/ADR-001`。

## 1. 产品

**血压了么 / BloodPressed** v1.0.0+1 —— 跨 Android/iOS 的血压监控应用。

- 记录血压脉搏：手动录入、拍照/相册识别、语音录入三种途径
- 趋势图表：近 7/30/90 天 + 自定义区间，血压/脉搏双序列 + 参考线
- AI 健康指导：本地（llama.cpp GGUF）或远端（OpenAI 兼容 SSE）大模型，结合近 30 天记录
- 数据导出与分享：CSV + 单次记录卡/统计摘要卡（微信/系统分享）
- 健康知识阅读：内置双语文章（assets/knowledge）
- 测量提醒：每日定时 / 提醒窗口内周期提醒
- 隐私立场：数据全本地（SQLite + Outbox），云同步为预留 seam（SyncService 接口，未接入平台）

## 2. 技术栈（选型已冻结）

| 层 | 选择 | 备注 |
|---|---|---|
| 框架 | Flutter (Dart ^3.13) | Material 3，`ColorScheme.fromSeed(0xFF00897B)` 青绿主色 |
| 状态 | flutter_riverpod | StateNotifier 风格 |
| 路由 | go_router | 底部 5 Tab：首页/趋势/AI助手/知识/我的 |
| 存储 | sqflite + shared_preferences | UUID 主键 + deviceId + 软删除 + updated_at |
| OCR | 自研七段码（纯 Dart）+ PP-OCRv5 ONNX 兜底 | onnxruntime；ML Kit 双依赖待清理（TD-001） |
| LLM | llamadart（本地 GGUF）+ dio SSE（远端） | 模型从魔搭下载 |
| i18n | flutter gen-l10n（zh/en） | `AppLocaleService.current` 为无 context 快照 |
| 通知 | flutter_local_notifications + timezone | 每日定时与窗口周期两种模式 |
| 分享 | share_plus + fluwx | 分享卡 PNG 圆角外透明（chg-014 约束） |

## 3. 架构（三层 + 按功能分包）

```
lib/
├── core/           # db(AppDatabase+OutboxDao) / design(色板·尺寸·分级配色)
│                   # i18n(AppLocaleService+labels) / router / theme / utils / widgets
├── features/       # records(录入·历史·语音) · camera_ocr(七段码+ppocr) ·
│                   # llm(引擎·市场·配置) · assistant(对话) · stats(趋势) ·
│                   # export(CSV+分享卡) · knowledge · settings(提醒) · sync(预留 seam)
└── l10n/           # gen-l10n 产物（勿手改）
```

- 依赖方向：`features → core`，禁止反向；`core/providers.dart` 汇总全局 Provider。
- 深模块 seam：`SyncService`（本地实现=不同步）、`InferenceEngine`（local/remote 双实现）、`RecordsRepository`（UI 不直接触 SQL）。
- 枚举文案唯一出口：`core/i18n/labels.dart`（新增枚举值必须同步补齐 sourceLabel 等 switch + zh/en arb）。

## 4. 关键约束（违反即回退）

1. **测试是门禁**：提交前 `flutter test` 全绿 + `flutter analyze` 0 issue（工具链命令见 `hs_dev_docs/_00_project/_08_dev_command/flutter_commands.md`）。
2. **l10n 双语同步**：改文案必须同时改 `app_zh.arb` 与 `app_en.arb`，`flutter gen-l10n` 后提交；禁止 UI 内硬编码文案（历史教训：record_edit_page 曾硬编码「语音录入」）。
3. **分享卡导出**：PNG 圆角外必须透明（alpha=0），应用内预览所见即所得（chg-013→014 反复两次的教训）。
4. **分级判定**（`core/utils/bp_category.dart`）与**参考线**（135/85 家庭自测）是医学口径，改动需在测试中固化断言。
5. **隐私**：任何新功能不得默认上传用户数据；云同步必须走 SyncService seam。
6. **测试宿主差异**：speech_to_text 等平台通道在 `test/support/real_test_harness.dart` mock；sqflite 用 FFI NoIsolate（详见 dev_command 文档）。

## 5. 测试策略（15 文件 / 145 用例基线）

- 单元：bp_voice_parser / bp_category / formatters / reminder_schedule / ocr_parser / ppocr 逻辑 / seven_segment（含反光两种场景）
- 契约：records_repository（真实 SQLite）· model_market_api（真实网络）
- UI 集成：app_integration（欢迎→录入→分级→编辑→落盘全链路）· l10n smoke
- 规则：修 bug 先加失败测试；新枚举值必须带 labels 断言（防非穷尽 switch 回归）

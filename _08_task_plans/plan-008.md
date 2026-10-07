# 支持英文：全量 UI 文案迁移 gen-l10n + 语言切换

- id: `plan-008`
- name: `支持英文：全量 UI 文案迁移 gen-l10n + 语言切换`
- time: `2026-10-07 13:42:30`
- requirement: 用户拍板「支持英文」——沿用上一轮结论：官方 gen-l10n 方案，设置页加语言选项（跟随系统/中文/English）
- changelog: `<chg-xxx，记账后填写>`

## 目标

1. 应用 UI 全量支持中英双语：官方 `flutter gen-l10n`（arb → AppLocalizations），新增语言设置（跟随系统/中文/English），选择持久化并驱动 MaterialApp.locale，系统弹窗随语言变化。
2. 无 BuildContext 的用户可见文案同样双语：测量提醒通知、CSV 表头、分享卡片、Fmt.friendlyDay、枚举 label（臂/体位/来源/血压分级）——用「当前语言快照」服务（AppLocaleService，随 MaterialApp locale 同步更新）供 data 层取词。
3. 质量门禁：analyze 0 issues；全量测试通过（存量断言在 zh 下不变）；新增英文冒烟测试。

## 范围

- 做：lib/ 全部用户可见 UI 文案；通知文本；CSV 表头；分享卡文字；平台内标题（onGenerateTitle）。
- 不做（内容型文案，另行立项）：知识库 13 篇文章正文；LLM 系统提示词与健康上下文（health_context_builder）；应用商店元数据。英文下这些内容仍为中文，在设置页语言行副标题注明。
- 语言规则：默认跟随系统；supportedLocales [zh, en]；强制非跟随时的 locale；切换语言后重排提醒通知（保证已排程通知语言一致）。

## 设计要点

- l10n.yaml：arb-dir lib/l10n，template app_en.arb，output 落 lib/l10n（Flutter 3.47 已禁用 synthetic package，直接源码目录 import）。
- 词典键名 camelCase 按功能分组（homeX/statsX/settingsX…），带参文案用 arb placeholder。
- 枚举 label 保留中文字段为数据层/CSV 兜底，UI 取词走 l10n 映射助手（避免改 domain 常量结构）。
- 测试：harness 固定语言为中文（保持存量断言）；新增 en 冒烟用例。

## 步骤（任务卡）

- [ ] 1. T1 基建：l10n.yaml + 空 ARB（app_en/app_zh）+ pubspec generate + AppLocaleService（当前语言快照）+ app.dart 接线（delegates/supportedLocales/locale/onGenerateTitle）+ AppSettings 增加 locale 偏好 + 设置页语言行 + 切换后重排通知
- [ ] 2. T2 records：home_page、record_tile、record_edit_page、core/widgets/common_widgets、stat_card、bp_category/枚举取词助手
- [ ] 3. T3 stats + export：stats_page、export_page、share_card_widgets、csv_exporter 表头
- [ ] 4. T4 camera_ocr：ocr_flow 用户可见文案
- [ ] 5. T5 llm：llm_settings_page、model_market_page、remote_profile_edit_page
- [ ] 6. T6 assistant + knowledge：assistant_page、knowledge_page、knowledge_detail_page
- [ ] 7. T7 settings + sync：settings_page、sync_page、reminder_service 通知文本、Fmt（friendlyDay 等）
- [ ] 8. T8 测试：harness 固定 zh；新增英文冒烟（含语言切换后系统弹窗/首页关键文案）；analyze + 全量测试
- [ ] 9. T9 索引同步（_10/_07 若有新方法/_00）+ 分卡提交

## 恢复

- 上次完成：无
- 下一步：步骤 1（T1 基建）
- 阻塞：无

## 备注

- 项目 _01~_06 未建文档（历史一贯快速通道），本计划详情即本次需求的功能/接口设计记录；无 _06 契约变更（对外行为新增，不改既有契约）。
- 迁移注意：使用 l10n 的 Text 需去 const；showDialog/showModalBottomSheet 内用 ctx 取 l10n；ARB 英文文案以地道简洁为准，单位与专有名词（mmHg/CSV/API）保留。

# 任务详细设计与执行记录：builtin-001

- **任务名称**：内置默认模型 Qwen3-1.7B + 功能搜索跳转 + 90 分置信度门槛问答
- **变更分级**：`L`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **开始时间**：`2026-10-11T01:01:26Z`
- **最后更新**：`2026-10-11T02:29:26Z`

---

## 1. 任务背景与目标

Qwen/Qwen3-1.7B-GGUF 作为内置默认模型（首次使用确认后下载）；首页搜索功能与设置项并跳转；仅内置模型启用 90 分置信度门槛问答。

冻结决策：① 首次使用时弹窗确认后下载（不自动）；② 搜索入口=首页 AppBar 图标，范围=功能+设置项；③ 门槛仅适用内置默认模型，用户自配模型零门槛；④ 助手 Tab 就绪后才显示。

---

## 2. 架构落点（六切片，均独立 commit）

| Slice | Commit | 内容 |
|---|---|---|
| 1 | 56e121d | builtin_model.dart virtual 档案 + effectiveLlmProfileProvider 三级解析 + ensureReady 懒激活 + activateAndPersist 双写不变量（修复远端激活不持久化 bug） |
| 2 | 0689043 | BuiltinModelCard 三态卡片 + 下载确认弹窗 + 助手页引导态 + 助手 Tab 可见条件 |
| 3 | 47fca63 | LocalChatEngine.chatJson（GBNF grammar 约束）+ gated_answer 协议 |
| 4 | 7a3b628 | AssistantController 门禁分支（≥90 答案 / <90 拒答 / 竞态守卫 / 历史裁剪 8 条） |
| 5 | 093d92f | 功能搜索（registry 15 条目 + 确定性匹配 + 语义兜底）+ /sync /market /record/new /search 路由提升 + 修复 Tab 路由 push 叠层崩溃 |
| 6 | 本次 | 门禁收口 |

---

## 3. 验证与门禁记录

- `flutter analyze`：**0 issue**
- `flutter test`：**183/183 绿**（基线 170 → 新增 32：builtin 域 8 + UI 7 + gated 协议 4 + 门禁控制器 5 + 搜索 13，含修正）
- `verify_consistency.py`：**PASS**
- 契约/单测覆盖：确定性匹配、解析优先级、双写成败、门槛行为、语义兜底均有自动化；**模型真实生成质量**不可离线断言（见冒烟清单）

---

## 4. 真机冒烟清单（下次 `flutter run` 例行验证）

1. 全新安装：首页搜索图标可用（确定性匹配）；底部无 AI助手 Tab；「我的→AI 模型」顶部有内置卡片（未下载态）
2. 点下载 → 确认弹窗（1.8GB 告知）→ 进度条 → 完成后卡片变「已就绪」、助手 Tab 出现
3. 助手提问：非流式"思考中"占位 → 高把握问题正常回答；刁钻/超纲问题 → 拒答文案
4. 配置任意远端 API 激活 → 问答恢复流式、无门槛；助手标签随激活档案变化
5. 搜索 zh/en 关键词 → 点击跳转对应页；Tab 目的地（如"测量提醒"）切分支正常不崩溃
6. 内置模型激活状态下杀进程重启：助手 Tab 仍在（文件存在性播种生效），懒激活正常

---

## 5. 遗留与登记

- `pubspec.lock` 因 l10n 无变化未动；无 DB 迁移（virtual 档案设计）
- llamadart GBNF 子集不支持数值 minimum/maximum → 置信度范围由 parseGatedAnswer 兜底（已注释）
- flutter_timezone / share_plus 旧版 KGP 警告（见 TD-001 备注，插件侧问题）

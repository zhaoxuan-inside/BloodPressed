# 任务简述清单分片 001

### 任务简述：rebuild-001
- **标题**：重建 hs-dev-skill 开发环境 + 修复编译错误/反光斑缺陷/弃用 API + 补强测试
- **change_size**：`M`
- **状态**：`COMPLETED`
- **优先级**：P0
- **负责人**：Agent
- **核心目标**：用 hs-dev-skill v2.21 重建项目开发文档环境；修复 flutter analyze 的 2 错误 1 警告 5 弃用项；修复 seven_segment 反光斑失败测试；全量测试绿后门禁提交
- **详情索引**：`_02_task_detail/_01_rebuild-001/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_rebuild-001/_00_context_pack.md`
- **更新时间**：`2026-10-11T00:01:08Z`
---

### 任务简述：td-001-mlkit
- **标题**：移除 ML Kit 双依赖（pubspec/gradle/proguard 三层残留）
- **change_size**：`S`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **核心目标**：确认 Dart 层零引用后，移除 google_mlkit_text_recognition 依赖、gradle 中文捆绑库与 R8 keep 规则，减 APK 体积
- **详情索引**：`_02_task_detail/_01_td-001-mlkit/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_td-001-mlkit/_00_context_pack.md`
- **更新时间**：`2026-10-11T00:47:03Z`
---

### 任务简述：builtin-001
- **标题**：内置默认模型 Qwen3-1.7B + 功能搜索跳转 + 90 分置信度门槛问答
- **change_size**：`L`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **核心目标**：Qwen/Qwen3-1.7B-GGUF 作为内置默认模型（首次使用确认后下载）；首页搜索功能与设置项并跳转；仅内置模型启用 90 分置信度门槛问答
- **详情索引**：`_02_task_detail/_01_builtin-001/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_builtin-001/_00_context_pack.md`
- **更新时间**：`2026-10-11T02:29:26Z`
---

### 任务简述：search-tier-001
- **标题**：搜索分级管线：T1精确→T2包含→T3模糊→T4重合度→T5模型兜底
- **change_size**：`S`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **核心目标**：确定性层升级为分级 NLP 匹配（精确/前缀包含/编辑距离/拼音/字符bigram重合度），模型仅在全部未命中且查询≥2字时兜底
- **详情索引**：`_02_task_detail/_01_search-tier-001/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_search-tier-001/_00_context_pack.md`
- **更新时间**：`2026-10-11T04:58:47Z`
---

### 任务简述：model-center-001
- **标题**：模型中心：魔搭+HF 双社区搜索/下载/安装/推理，品牌统一
- **change_size**：`M`
- **状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **核心目标**：UI 更名模型中心且不出现社区品牌；搜索并行查双社区合并去重；自定义 ID 双源查找；下载完成自动建档（安装）；推理复用档案激活
- **详情索引**：`_02_task_detail/_01_model-center-001/_00_task_detail.md`
- **上下文包**：`_03_task_context_pack/_01_model-center-001/_00_context_pack.md`
- **更新时间**：`2026-10-11T05:32:01Z`
---


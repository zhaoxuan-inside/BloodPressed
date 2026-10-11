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


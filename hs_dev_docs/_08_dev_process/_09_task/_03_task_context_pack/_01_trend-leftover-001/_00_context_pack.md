# 上下文装载包 (Context Pack)：trend-leftover-001

- **change_size**：`S`
- **任务 ID**：`trend-leftover-001`
- **生成时间**：`2026-10-11T06:36:41Z`
- **状态**：`READY`
- **装载纪律**：必须物化切片正文；禁止只写路径。
- **查询**：`doc_index_db.py --root . search|slice`；Skill 详规用 `skill_ref_index.py search`（勿通读 references/）

---

## 1. 需求与目标（物化）
全屏横屏页补 AI 分析入口（pop 恢复竖屏后跳助手）；分析文案提取共享去重；补全屏页/分析卡/分享卡/文案测试；stats-trend-001 遗留清零

<!-- Agent：用 doc_index_db search/slice 粘贴 PRD/DoD 关键段落，勿只留链接；S 可仅 3～8 行 DoD -->

---

## 2. 数据模型切片（物化）
<!-- 粘贴相关表字段/约束原文片段；并注明 path + line range；未触达写 N/A -->

---

## 3. 接口与六元组签名（物化）
<!-- 粘贴方法签名、入参/出参、compensate/fallback；改 API 时读 api_engineering.md -->

---

## 4. 调用链与 Mock 契约（物化）
<!-- 粘贴依赖方法清单与契约关键字段 -->

---

## 5. 查询轨迹（降 Token）
- `doc_index_db` 命中 path 列表：
- `skill_ref_index` 命中 path 列表：
- 本会话已读 Skill references（禁止重复整读）：

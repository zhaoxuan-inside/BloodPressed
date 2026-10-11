# ADR-001：从旧版 hs-project-skill 扁平文档迁移到 hs-dev-skill v2.21

- 状态：已采纳（2026-10-11，rebuild-001）
- 背景commit：`93c551b feat(del) 清理旧 Skill 开发环境`（旧根目录 `_0X_*` 文档已删除）

## 决策

1. 采用 hs-dev-skill v2.21 的 `hs_dev_docs/` 目录结构（`init_hs_dev_docs.py` 生成），不再使用旧版根目录扁平格式（`_00_project_idx.json` / `_08_task_plan_idx.json` / `_10_change_log.json`）。
2. 旧史**不逐文件搬运**，只迁移结论性知识：
   - 12 个历史任务（plan-001~012）的关键结论已浓缩进术语词典与 DESIGN.md；
   - 14 条变更史（chg-001~014）中仍生效的两条约束：**分享卡导出 PNG 圆角外为透明**（chg-013→014 最终态，勿再改回底衬方案）；**CSV 表头/分享卡文案随语言变化**（plan-008 i18n）；
   - 未竟工作 plan-012「OCR 七段码反光处理」在 rebuild-001 中完成收口（背景亮度自适应阈值方案，见 git log）。
3. 根目录 `DESIGN.md` 成为项目身份唯一入口；`hs_dev_docs/` 只放过程性文档。

## 后果

- 旧文档可用 `git log -- _00_project_idx.json` 追溯；本文件是唯一的迁移映射。
- 新工作一律走 `task_manager.py` + `process_log.py`（plan_log/change_log 在 `hs_dev_docs/_08_dev_process/`）。

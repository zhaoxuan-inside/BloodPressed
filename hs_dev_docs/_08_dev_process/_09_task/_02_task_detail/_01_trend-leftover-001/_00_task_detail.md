# 任务详细设计与执行记录：trend-leftover-001

- **任务名称**：趋势遗留收口：全屏页 AI 分析入口 + 补齐 UI 测试 + 文档清遗留
- **变更分级**：`S`
- **当前状态**：`COMPLETED`
- **优先级**：P1
- **负责人**：Agent
- **开始时间**：`2026-10-11T06:36:41Z`
- **最后更新**：`2026-10-11T06:43:45Z`

---

## 1. 背景

用户要求「不要有遗留，必须完整开发、文档维护、测试」。上一任务
stats-trend-001 详情遗留节两项：全屏页 AI 入口（代码遗留）与微信真机
AppID（环境依赖）。本任务将代码遗留清零并补齐测试。

## 2. 实施

1. **分析文案共享化**：`analysis_text.dart`（bucketLabel / analysisConclusion /
   analysisSummaryZh / trendRangeLabel）——stats_page 私有实现提取共享，
   全屏页与测试复用。
2. **全屏页 AI 分析入口**：顶部控制条加「AI 分析」按钮；流程 = 读分析 →
   `guardAndSendAnalysis` 守卫 → **pop 本页（dispose 恢复竖屏）→ push /assistant**
   ——对话流不滞留横屏。
3. **测试 +7**（test/stats_trend_ui_test.dart）：
   - 文案助手 3：结论（偏高指出时段/全部理想）、摘要串、范围标签
   - 分析卡 1：折叠/展开/回调
   - 分享卡渲染 2：趋势卡（图表+均值）、分析卡（结论/时段/峰值）
   - 全屏页 1：折线渲染 + 系列切换 + AI 全流程（pending 清空、pop 回竖屏、
     进助手页、用户消息入库）

## 3. 文档维护

- stats-trend-001 详情「遗留」节改收口态（~~AI 入口~~ 已补；微信标注**环境依赖**），
  归档 idx 经 IdxManager.update_digest() 刷新
- 本任务详情即收口记录；词典/DESIGN 无需再动（T1-T7 已覆盖）

## 4. 门禁

- `flutter analyze`：0 issue
- `flutter test`：全量绿（212 基线 + 7 = 219/219）
- `verify_consistency.py`：PASS

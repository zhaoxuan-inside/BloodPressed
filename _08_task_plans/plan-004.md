# 血压趋势支持自定义时间段

- id: `plan-004`
- name: `血压趋势支持自定义时间段`
- time: `2026-10-05 11:20:00`
- requirement: `血压趋势要支持指定的时间段。快速通道。`
- changelog: `chg-005`

## 目标

趋势页在固定范围（近7/30/90天/全部）外支持自定义起止日期；图表与统计卡按所选区间计算；x 轴按区间末日锚定（区间可完全在过去）。

## 范围

- 做：TrendQuery/StatsRange 增加显式 from/to；statsProvider/trendDataProvider 分支；筛选条加"自定义"chip + showDateRangePicker；xOf/titles 改为按查询锚定；单测覆盖查询区间与 x 轴定位。
- 不做：记忆上次自定义区间（会话内有效即可）；导出页联动。

## 步骤

- [x] 1. 写失败测试：TrendQuery 自定义区间（isCustom/span/endDate）与 xOf 过去区间锚定
- [x] 2. TrendQuery 增加 from/to + endDate/span；trendDataProvider 分支；xOf/ChartBase.titles 改为按查询锚定
- [x] 3. StatsRange 增加 from/to；statsProvider 分支
- [x] 4. StatsPage：自定义 chip + showDateRangePicker + 状态切换；图表传查询对象
- [x] 5. flutter analyze + 全量测试
- [x] 6. 模拟器实测：选历史区间（含已删数据期）验证图表/统计卡正确
- [x] 7. 收尾：_10 记账、提交

## 恢复

- 上次完成：全部步骤
- 下一步：无（已完成，模拟器实测通过）
- 阻塞：无

## 备注

- 快速通道：影响 4 个文件（trend_providers、records_providers、stats_page、新测试）。

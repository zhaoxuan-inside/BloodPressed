# 系统弹窗中文化：趋势自定义日期选择与提醒窗口时间选择

- id: `plan-007`
- name: `系统弹窗中文化：趋势自定义日期选择与提醒窗口时间选择`
- time: `2026-10-07 12:17:55`
- requirement: 用户反馈「血压趋势的自定义按钮里面要用中文；提醒窗口的时间选择要用中文」
- changelog: `chg-010`

## 目标

趋势页点击「自定义」弹出的日期范围选择器、设置页「测量提醒」的时间选择器（含提醒窗口开始/结束时间）均以中文显示（标题、按钮、上午/下午等）。快速通道：小改动（≤4 文件、约 ±20 行），不改变任何接口与业务逻辑。

## 范围

- 做：MaterialApp 配置中文本地化（flutter_localizations + locale zh）；趋势页自定义选中态按钮文案改为中文日期格式（10月1日-10月7日）。
- 不做：不改提醒逻辑、不改 _06 接口、不引入多语言切换设置项。

## 步骤

- [x] 1. pubspec.yaml 添加 flutter_localizations 依赖并 flutter pub get
- [x] 2. app.dart 配置 localizationsDelegates / supportedLocales / locale: zh
- [x] 3. stats_page.dart 自定义按钮选中态标签改为中文日期格式
- [x] 4. flutter analyze 0 issues + flutter test 全部通过
- [x] 5. 同步索引：_10 记账（含 plan_id）、勾选本计划、_00 必要时同步

## 恢复

- 上次完成：全部步骤（120 测试通过 + analyze 0 issues）
- 下一步：无（完成）
- 阻塞：无

## 备注

根因：MaterialApp 未配置 localizationsDelegates/supportedLocales，Flutter 系统 picker（showDateRangePicker/showTimePicker）默认美式英语渲染。趋势页预设按钮（近7天/近30天/近90天/全部）与「自定义」文字本身已是中文，无需改。

# 测量提醒多方式：每日定时 + 周期提醒（提醒窗口+提醒周期）

- id: `plan-001`
- name: `测量提醒多方式：每日定时 + 周期提醒（提醒窗口+提醒周期）`
- time: `2026-10-04 18:03:38`
- requirement: `血压提示支持多种方式：定时提示；周期性提示（选择开始结束时间，按提醒周期如半小时重复）`
- changelog: `<chg-xxx，记账后填写>`

## 目标

ReminderMode 三态（off/daily/interval），周期提醒在提醒窗口内按 intervalMinutes 计算触发时刻排程一次性通知，设置页可编辑，启动与设置变更后重排。

## 范围

- 做：AppSettings 扩展与旧配置迁移；ReminderSchedule 纯逻辑（occurrence 计算）；ReminderService 双模式排程；设置页 UI；启动恢复；单测与模拟器实测。
- 不做：按"今日已测量则静默"的抑制逻辑（后续需求）；跨午夜提醒窗口（UI 强制 start < end）；每周/工作日重复粒度。

## 步骤

- [x] 1. _09 登记术语（ReminderMode/DailyReminder/IntervalReminder/reminderWindow/intervalMinutes/occurrence）并写失败测试：ReminderSchedule.occurrences 纯计算（窗口内/外、horizon 截断、上限、末次≤end）+ AppSettings 旧配置迁移
- [x] 2. AppSettings：reminderMode 三态 + 周期提醒字段（intervalStart/intervalEnd/intervalMinutes），旧 reminderEnabled=true 迁移为 daily
- [x] 3. domain/reminder_schedule.dart：occurrences 纯函数最小实现，测试转绿
- [x] 4. ReminderService：scheduleFromSettings（取消→按模式排程 daily/interval 一次性通知，ID 分段）+ cancelAllReminders；main.dart 启动改调 scheduleFromSettings
- [x] 5. SettingsPage UI：提醒方式 SegmentedButton（关闭/定时/周期）+ 定时时间行 + 周期窗口（开始/结束）与提醒周期下拉，变更即持久化并重排
- [x] 6. flutter analyze 0 issues + flutter test 全量通过（92/92，含外部重写测试的修复）
- [x] 7. 模拟器实测：设置周期提醒（窗口覆盖当前时刻、间隔 15 分钟）→ 等待下一次 occurrence → 验证系统通知出现；恢复原设置
  - 追加修复（实测暴露的三个真问题）：① v19 排程不自动建通知通道 → _ensureChannels 显式创建（缺通道通知静默丢失）；② exactAllowWhileIdle 替换 inexact（提醒必须准时）；③ v19 要求使用方清单声明 ScheduledNotificationReceiver/BootReceiver（缺失时 alarm 广播无人接收，静默丢弃），并在 initialize 注册 @pragma('vm:entry-point') 后台回调
- [x] 8. 收尾：_07 登记新增方法、_10 记账 verified、Conventional Commits 提交

## 恢复

- 上次完成：无
- 下一步：步骤 1
- 阻塞：无

## 备注

- 快速通道（right-sizing）评估：影响面约 5 个代码文件（settings 三个 + main.dart + 新测试文件），不改变既有对外契约，豁免 P1~P6 门禁。
- 存量代码未采用五段签名；为保持与既有 90+ 方法风格一致（SKILL 冲突裁决：会话上下文与既有规范优先于引入新框架），新方法按既有 Clean Architecture 风格实现，五段改造留待专门 onboarding 任务（_00.conventions 已登记此约定）。
- 周期提醒排程采用"一次性精确/准确定时通知批量预排"（水平 2 天、上限 64 条，iOS pending 上限 64 内），触发与设置变更、启动时重排。

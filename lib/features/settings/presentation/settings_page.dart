import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/sync/presentation/sync_page.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/settings/data/reminder_service.dart';

/// "我的"设置页。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final activeProfile = ref.watch(activeLlmProfileProvider);
    final engineState = ref.watch(llmEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader('AI 模型'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('AI 模型配置'),
                  subtitle: Text(activeProfile == null
                      ? '未配置 · 点击添加本地或远端模型'
                      : '当前：${activeProfile.name}'
                          '（${activeProfile.kind == LlmKind.local ? '本地' : '远端'}）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/llm'),
                ),
                if (activeProfile != null &&
                    engineState.status == LlmEngineStatus.error)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.error_outline,
                        color: theme.colorScheme.error, size: 20),
                    title: Text(
                      '模型加载失败：${engineState.error ?? ''}',
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader('测量偏好'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pan_tool_alt_outlined),
                  title: const Text('默认测量臂'),
                  trailing: SegmentedButton<MeasureArm>(
                    segments: const [
                      ButtonSegment(
                          value: MeasureArm.left, label: Text('左臂')),
                      ButtonSegment(
                          value: MeasureArm.right, label: Text('右臂')),
                    ],
                    selected: {settings.defaultArm},
                    onSelectionChanged: (s) {
                      settings.setDefaultArm(s.first);
                      setState(() {});
                    },
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                  ),
                ),
                _ReminderSection(settings: settings),
              ],
            ),
          ),
          const SectionHeader('数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('导出与分享'),
                  subtitle: const Text('CSV 导出 · 卡片分享 · 微信'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/export'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('云同步'),
                  subtitle: const Text('未开启 · 多设备同步（预留）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncPage()),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('通用'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          size: 22, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Text('外观', style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('跟随系统')),
                        ButtonSegment(value: 'light', label: Text('亮色')),
                        ButtonSegment(value: 'dark', label: Text('暗色')),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) {
                        settings.setThemeMode(s.first);
                        ref.read(themeModeNameProvider.notifier).state =
                            s.first;
                        setState(() {});
                      },
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: const Text('微信分享配置'),
                  subtitle: Text(settings.wechatAppId.isEmpty
                      ? '未配置 AppID（未配置时使用系统分享）'
                      : 'AppID：${_mask(settings.wechatAppId)}'),
                  onTap: () => _editWechat(settings),
                ),
              ],
            ),
          ),
          const SectionHeader('关于'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.monitor_heart_outlined),
                  title: Text('BloodPressed 血压管家'),
                  subtitle: Text('v1.0.0 · 跨平台血压健康助手'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('免责声明'),
                  onTap: () => _showDisclaimer(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mask(String id) =>
      id.length <= 8 ? id : '${id.substring(0, 4)}****${id.substring(id.length - 4)}';

  Future<void> _editWechat(AppSettings settings) async {
    final appIdCtrl = TextEditingController(text: settings.wechatAppId);
    final linkCtrl = TextEditingController(text: settings.wechatUniversalLink);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('微信分享配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: appIdCtrl,
              decoration: const InputDecoration(
                labelText: '微信开放平台 AppID',
                hintText: '留空则使用系统分享',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: linkCtrl,
              decoration: const InputDecoration(
                labelText: 'iOS Universal Link（可选）',
                hintText: 'https://your-domain/appendix/',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      await settings.setWechatAppId(appIdCtrl.text.trim());
      await settings.setWechatUniversalLink(linkCtrl.text.trim());
      setState(() {});
    }
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('免责声明'),
        content: const SingleChildScrollView(
          child: Text(
            '本应用提供的所有内容（包括但不限于血压分级提示、AI 健康指导、'
            '健康知识文章）仅用于健康信息参考与自我管理辅助，'
            '不构成医学诊断或治疗建议。\n\n'
            'AI 生成内容可能存在错误或遗漏，请勿据此调整用药或做出医疗决策。'
            '如有健康问题，请咨询专业医疗机构。\n\n'
            '本应用数据仅保存在您的设备本地（云同步开启前不上传任何数据），'
            '请自行通过导出功能妥善备份。',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}


/// 测量提醒：提醒方式（关闭/定时/周期）+ 各方式参数编辑。
class _ReminderSection extends ConsumerStatefulWidget {
  const _ReminderSection({required this.settings});

  final AppSettings settings;

  @override
  ConsumerState<_ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends ConsumerState<_ReminderSection> {
  static const _intervalChoices = [15, 30, 45, 60, 120];

  AppSettings get settings => widget.settings;

  String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _apply({bool enabling = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (enabling) {
      final granted = await ReminderService.requestExactAlarmPermission();
      if (!granted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('未获得通知权限，提醒可能无法显示')));
      }
    }
    await ReminderService.scheduleFromSettings(settings);
    if (mounted) setState(() {});
  }

  Future<void> _changeMode(ReminderMode mode) async {
    await settings.setReminderMode(mode);
    await _apply(enabling: mode != ReminderMode.off);
  }

  Future<void> _pickDailyTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (time == null) return;
    await settings.setReminderTime(time.hour, time.minute);
    await _apply();
  }

  Future<void> _pickWindowTime({required bool isStart}) async {
    final messenger = ScaffoldMessenger.of(context);
    final initialHour =
        isStart ? settings.intervalStartHour : settings.intervalEndHour;
    final initialMinute =
        isStart ? settings.intervalStartMinute : settings.intervalEndMinute;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (time == null) return;
    final startHour = isStart ? time.hour : settings.intervalStartHour;
    final startMinute = isStart ? time.minute : settings.intervalStartMinute;
    final endHour = isStart ? settings.intervalEndHour : time.hour;
    final endMinute = isStart ? settings.intervalEndMinute : time.minute;
    if (startHour * 60 + startMinute >= endHour * 60 + endMinute) {
      messenger.showSnackBar(const SnackBar(content: Text('结束时间需晚于开始时间')));
      return;
    }
    await settings.setIntervalWindow(startHour, startMinute, endHour, endMinute);
    await _apply();
  }

  Future<void> _pickInterval(int minutes) async {
    await settings.setIntervalMinutes(minutes);
    await _apply();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = settings.reminderMode;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.alarm_outlined),
          title: const Text('测量提醒'),
          trailing: SegmentedButton<ReminderMode>(
            segments: const [
              ButtonSegment(value: ReminderMode.off, label: Text('关闭')),
              ButtonSegment(value: ReminderMode.daily, label: Text('定时')),
              ButtonSegment(value: ReminderMode.interval, label: Text('周期')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                _changeMode(selection.first),
          ),
        ),
        if (mode == ReminderMode.daily)
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('提醒时间'),
            subtitle: const Text('每天在固定时刻提醒测量'),
            trailing: TextButton(
              onPressed: _pickDailyTime,
              child: Text(_clock(settings.reminderHour, settings.reminderMinute)),
            ),
          ),
        if (mode == ReminderMode.interval) ...[
          ListTile(
            leading: const Icon(Icons.timelapse_outlined),
            title: const Text('提醒窗口'),
            subtitle: const Text('仅在窗口内按周期提醒'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _pickWindowTime(isStart: true),
                  child: Text(_clock(
                      settings.intervalStartHour, settings.intervalStartMinute)),
                ),
                Text('–', style: theme.textTheme.bodyLarge),
                TextButton(
                  onPressed: () => _pickWindowTime(isStart: false),
                  child: Text(_clock(
                      settings.intervalEndHour, settings.intervalEndMinute)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.update_outlined),
            title: const Text('提醒周期'),
            subtitle: const Text('窗口内每隔该时长提醒一次'),
            trailing: DropdownButton<int>(
              value: settings.intervalMinutes,
              items: _intervalChoices
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text('$m 分钟')))
                  .toList(),
              onChanged: (m) {
                if (m != null) _pickInterval(m);
              },
            ),
          ),
        ],
      ],
    );
  }
}

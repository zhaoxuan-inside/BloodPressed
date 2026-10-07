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
import 'package:blood_pressed/l10n/app_localizations.dart';

/// "我的"设置页。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _mask(String id) =>
      id.length <= 8 ? id : '${id.substring(0, 4)}****${id.substring(id.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final activeProfile = ref.watch(activeLlmProfileProvider);
    final engineState = ref.watch(llmEngineProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(l10n.aiModelSection),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(l10n.aiModelConfig),
                  subtitle: Text(activeProfile == null
                      ? l10n.aiModelNotConfigured
                      : l10n.aiModelCurrent(
                          activeProfile.name,
                          activeProfile.kind == LlmKind.local
                              ? l10n.kindLocal
                              : l10n.kindRemote)),
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
                      l10n.llmLoadError(engineState.error ?? ''),
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(l10n.sectionPreference),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pan_tool_alt_outlined),
                  title: Text(l10n.defaultArm),
                  trailing: SegmentedButton<MeasureArm>(
                    segments: [
                      ButtonSegment(
                          value: MeasureArm.left, label: Text(l10n.armLeft)),
                      ButtonSegment(
                          value: MeasureArm.right, label: Text(l10n.armRight)),
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
          SectionHeader(l10n.sectionData),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: Text(l10n.exportShare),
                  subtitle: Text(l10n.exportShareSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/export'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.cloudSync),
                  subtitle: Text(l10n.cloudSyncSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncPage()),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.sectionGeneral),
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
                      Text(l10n.appearance, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'system', label: Text(l10n.themeSystem)),
                        ButtonSegment(
                            value: 'light', label: Text(l10n.themeLight)),
                        ButtonSegment(
                            value: 'dark', label: Text(l10n.themeDark)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.language_outlined,
                          size: 22, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Text(l10n.langTitle, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'system',
                                label: Text(l10n.langSystem)),
                            ButtonSegment(
                                value: 'zh', label: Text(l10n.langChinese)),
                            ButtonSegment(
                                value: 'en', label: Text(l10n.langEnglish)),
                          ],
                          selected: {settings.localePref},
                          onSelectionChanged: (s) async {
                            final v = s.first;
                            await settings.setLocalePref(v);
                            ref.read(localePrefProvider.notifier).state = v;
                            setState(() {});
                            // 已排程的提醒通知按新语言重排
                            await ReminderService.scheduleFromSettings(
                                settings);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.langSubtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: Text(l10n.wechatConfig),
                  subtitle: Text(settings.wechatAppId.isEmpty
                      ? l10n.wechatNotConfigured
                      : l10n.wechatAppIdMasked(_mask(settings.wechatAppId))),
                  onTap: () => _editWechat(settings),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.sectionAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(l10n.appTitle),
                  subtitle: Text(l10n.appVersionSubtitle),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.disclaimer),
                  onTap: () => _showDisclaimer(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editWechat(AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final appIdCtrl = TextEditingController(text: settings.wechatAppId);
    final linkCtrl = TextEditingController(text: settings.wechatUniversalLink);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wechatDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: appIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.wechatAppIdField,
                hintText: l10n.wechatAppIdHint,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: linkCtrl,
              decoration: InputDecoration(
                labelText: l10n.wechatUniversalLinkField,
                hintText: 'https://your-domain/appendix/',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.saveBtn)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disclaimer),
        content: SingleChildScrollView(
          child: Text(l10n.disclaimerBody),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).okGotIt),
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
    final l10n = AppLocalizations.of(context);
    if (enabling) {
      final granted = await ReminderService.requestExactAlarmPermission();
      if (!granted) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.notificationDenied)));
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
    final l10n = AppLocalizations.of(context);
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
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.windowEndAfterStart)));
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
    final l10n = AppLocalizations.of(context);
    final mode = settings.reminderMode;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.alarm_outlined),
          title: Text(AppLocalizations.of(context).reminderTitle),
          trailing: SegmentedButton<ReminderMode>(
            segments: [
              ButtonSegment(
                  value: ReminderMode.off,
                  label: Text(AppLocalizations.of(context).reminderOff)),
              ButtonSegment(
                  value: ReminderMode.daily,
                  label: Text(AppLocalizations.of(context).reminderDaily)),
              ButtonSegment(
                  value: ReminderMode.interval,
                  label: Text(AppLocalizations.of(context).reminderInterval)),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                _changeMode(selection.first),
          ),
        ),
        if (mode == ReminderMode.daily)
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.reminderDailyTime),
            subtitle: Text(l10n.reminderDailySubtitle),
            trailing: TextButton(
              onPressed: _pickDailyTime,
              child: Text(_clock(settings.reminderHour, settings.reminderMinute)),
            ),
          ),
        if (mode == ReminderMode.interval) ...[
          ListTile(
            leading: const Icon(Icons.timelapse_outlined),
            title: Text(l10n.reminderWindowTitle),
            subtitle: Text(l10n.reminderWindowSubtitle),
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
            title: Text(l10n.reminderIntervalTitle),
            subtitle: Text(l10n.reminderIntervalSubtitle),
            trailing: DropdownButton<int>(
              value: settings.intervalMinutes,
              items: _intervalChoices
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(l10n.intervalMinutes(m))))
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/providers.dart';
import 'features/assistant/data/health_context_builder.dart';
import 'features/assistant/presentation/controllers/assistant_providers.dart';
import 'features/export/data/wechat_share_service.dart';
import 'features/llm/presentation/controllers/llm_providers.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/data/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 基础存储
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  await settings.deviceId(); // 确保设备 ID 已生成

  // 2. 数据库
  final database = await AppDatabase.open();

  // 3. 微信分享注册（未配置 AppID 时静默跳过，不阻塞首帧）
  unawaited(
    ShareService(
      wechatAppId: settings.wechatAppId,
      universalLink: settings.wechatUniversalLink,
    ).registerWeChat(),
  );

  // 4. 恢复测量提醒（重启后按当前提醒方式整体重排）
  await ReminderService.scheduleFromSettings(settings);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appSettingsProvider.overrideWithValue(settings),
        appDatabaseProvider.overrideWithValue(database),
        llmProfilesProvider.overrideWith((ref) => LlmProfilesController(
              ref.watch(llmProfileStoreProvider),
              ref.watch(appSettingsProvider),
            )),
        llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
        assistantProvider.overrideWith((ref) => AssistantController(
              ref.watch(chatRepositoryProvider),
              HealthContextBuilder(ref.watch(recordsRepositoryProvider)),
              ref,
            )),
        activeLlmProfileIdProvider
            .overrideWith((ref) => settings.activeLlmProfileId),
        themeModeNameProvider.overrideWith((ref) => settings.themeMode),
      ],
      child: const BloodPressedApp(),
    ),
  );
}

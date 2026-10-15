import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/providers.dart';
import 'features/export/data/wechat_share_service.dart';
import 'features/llm/domain/builtin_model.dart';
import 'features/llm/presentation/controllers/llm_providers.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/data/reminder_service.dart';
import 'features/settings/presentation/privacy_startup.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 基础存储
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  AppDatabase? database;
  runApp(
    PrivacyStartup(
      settings: settings,
      cleanup: () async {
        await ReminderService.cancelAllReminders();
        await database?.db.close();
        AppDatabase.resetInstanceForTest();
        database = null;
      },
      initialize: (withdraw) async {
        database = await AppDatabase.open();
        return _initializeBusiness(prefs, settings, database!, withdraw);
      },
    ),
  );
}

Future<Widget> _initializeBusiness(
  SharedPreferences prefs,
  AppSettings settings,
  AppDatabase database,
  Future<void> Function() withdraw,
) async {
  await settings.deviceId(); // 确保设备 ID 已生成

  // 3. 微信分享注册（未配置 AppID 时静默跳过，不阻塞首帧）
  unawaited(
    ShareService(
      wechatAppId: settings.wechatAppId,
      universalLink: settings.wechatUniversalLink,
    ).registerWeChat(),
  );

  // 4. 恢复测量提醒（重启后按当前提醒方式整体重排）
  await ReminderService.scheduleFromSettings(settings);

  // 5. 内置默认模型（Qwen3-1.7B）：路径恒播种，就绪态按文件存在性判定
  final docsPath = (await getApplicationDocumentsDirectory()).path;
  final builtinPath = builtinModelFilePath(docsPath);
  final builtinReady = File(builtinPath).existsSync();

  return ProviderScope(
    overrides: [
      withdrawPrivacyProvider.overrideWithValue(withdraw),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(database),
      activeLlmProfileIdProvider.overrideWith(
        (ref) => settings.activeLlmProfileId,
      ),
      builtinModelPathProvider.overrideWith((ref) => builtinPath),
      builtinModelReadyProvider.overrideWith((ref) => builtinReady),
      themeModeNameProvider.overrideWith((ref) => settings.themeMode),
      localePrefProvider.overrideWith((ref) => settings.localePref),
    ],
    child: BloodPressedApp(router: buildAppRouter()),
  );
}

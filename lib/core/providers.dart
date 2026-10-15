import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'db/app_database.dart';
import 'db/outbox_dao.dart';

/// 依赖装配中枢：main() 中完成初始化后通过 ProviderScope overrides 注入，
/// 之后全部为同步 Provider，UI 侧无需等待。

// 同步 Provider 的存储必须在隐私同意后的启动流程中异步打开。
// 未注入意味着启动装配错误，不能悄悄另开数据库或跳过隐私流程。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) =>
    throw StateError('SharedPreferences must be initialized by PrivacyStartup'));

final appSettingsProvider = Provider<AppSettings>(
    (ref) => AppSettings(ref.watch(sharedPreferencesProvider)));

final appDatabaseProvider = Provider<AppDatabase>((ref) =>
    throw StateError('AppDatabase must be initialized by PrivacyStartup'));

final outboxDaoProvider =
    Provider<OutboxDao>((ref) => OutboxDao(ref.watch(appDatabaseProvider)));

final recordsRepositoryProvider = Provider<RecordsRepository>(
    (ref) => RecordsRepository(
        ref.watch(appDatabaseProvider), ref.watch(outboxDaoProvider)));

final llmProfileStoreProvider = Provider<LlmProfileStore>(
    (ref) => LlmProfileStore(ref.watch(appDatabaseProvider)));

final chatRepositoryProvider = Provider<ChatRepository>(
    (ref) => ChatRepository(ref.watch(appDatabaseProvider)));

/// 记录来源的设备标识。
final deviceIdProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(appSettingsProvider);
  return settings.deviceId();
});

/// 主题模式名称（system/light/dark），设置页修改时双写。
final themeModeNameProvider = StateProvider<String>((ref) => 'system');

/// 界面语言偏好（system/zh/en），设置页修改时双写。
final localePrefProvider = StateProvider<String>((ref) => 'system');

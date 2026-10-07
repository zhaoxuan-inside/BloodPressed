import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/export/data/wechat_share_service.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'db/app_database.dart';
import 'db/outbox_dao.dart';

/// 依赖装配中枢：main() 中完成初始化后通过 ProviderScope overrides 注入，
/// 之后全部为同步 Provider，UI 侧无需等待。

final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('需在 main() 中覆盖'));

final appSettingsProvider = Provider<AppSettings>(
    (ref) => throw UnimplementedError('需在 main() 中覆盖'));

final appDatabaseProvider = Provider<AppDatabase>(
    (ref) => throw UnimplementedError('需在 main() 中覆盖'));

final outboxDaoProvider =
    Provider<OutboxDao>((ref) => OutboxDao(ref.watch(appDatabaseProvider)));

final recordsRepositoryProvider = Provider<RecordsRepository>(
    (ref) => RecordsRepository(
        ref.watch(appDatabaseProvider), ref.watch(outboxDaoProvider)));

final llmProfileStoreProvider = Provider<LlmProfileStore>(
    (ref) => LlmProfileStore(ref.watch(appDatabaseProvider)));

final chatRepositoryProvider = Provider<ChatRepository>(
    (ref) => ChatRepository(ref.watch(appDatabaseProvider)));

/// 设备标识（同步预留）。
final deviceIdProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(appSettingsProvider);
  return settings.deviceId();
});

/// 分享服务（微信 AppID 从设置读取）。
final shareServiceProvider = Provider<ShareService>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return ShareService(
    wechatAppId: settings.wechatAppId,
    universalLink: settings.wechatUniversalLink,
  );
});

/// 主题模式名称（system/light/dark），设置页修改时双写。
final themeModeNameProvider = StateProvider<String>((ref) => 'system');

/// 界面语言偏好（system/zh/en），设置页修改时双写。
final localePrefProvider = StateProvider<String>((ref) => 'system');

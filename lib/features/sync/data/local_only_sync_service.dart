import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/sync/domain/sync_service.dart';
import 'package:blood_pressed/core/db/outbox_dao.dart';

/// 默认实现：未开启云同步（no-op）。
class LocalOnlySyncService implements SyncService {
  const LocalOnlySyncService();

  @override
  bool get enabled => false;

  @override
  bool get syncing => false;

  @override
  Future<SyncOutcome> push(List<OutboxEntry> changes) async {
    throw UnsupportedError('云同步尚未开启');
  }

  @override
  Future<SyncOutcome> pull(DateTime? since) async {
    throw UnsupportedError('云同步尚未开启');
  }
}

/// 当前同步服务（后期替换为具体平台实现）。
final Provider<SyncService> syncServiceProvider =
    Provider<SyncService>((ref) => const LocalOnlySyncService());

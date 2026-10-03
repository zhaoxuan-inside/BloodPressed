import 'package:blood_pressed/core/db/outbox_dao.dart';

/// 云同步抽象层。
///
/// 设计目标：当前不接入任何云平台（云同步是可关闭的增值服务），
/// 但数据层已按同步友好方式设计（UUID 主键 + 软删除 + updated_at + outbox 变更日志）。
/// 后期确定平台（Supabase / 自建 API / LeanCloud 等）后，实现 [SyncService]
/// 并在 data/local_only_sync_service.dart 的 [syncServiceProvider] 处替换实现即可，
/// 业务代码无需改动。
abstract class SyncService {
  /// 是否已开启云同步。
  bool get enabled;

  /// 是否正在同步。
  bool get syncing;

  /// 增量推送：把 outbox 中的变更上传到服务端。
  Future<SyncOutcome> push(List<OutboxEntry> changes);

  /// 增量拉取：拉取 [since] 之后服务端变更并合并入库。
  Future<SyncOutcome> pull(DateTime? since);
}

class SyncOutcome {
  const SyncOutcome({
    required this.pushed,
    required this.pulled,
    this.conflicts = 0,
    this.message,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
  final String? message;
}

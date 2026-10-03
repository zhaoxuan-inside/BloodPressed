import 'package:intl/intl.dart';

/// 日期与数值格式化工具（界面统一使用）。
class Fmt {
  Fmt._();

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fullFormat = DateFormat('yyyy-MM-dd HH:mm');

  static String day(DateTime dt) => _dayFormat.format(dt);
  static String time(DateTime dt) => _timeFormat.format(dt);
  static String full(DateTime dt) => _fullFormat.format(dt);

  /// 列表分组用：今天/昨天/M-d
  static String friendlyDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${dt.month}月${dt.day}日';
  }

  static String mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  /// 文件大小（B/KB/MB/GB）。
  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

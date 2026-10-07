import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// CSV 导出（Excel 兼容：UTF-8 BOM + 标准转义）。
///
/// 表头与枚举值随当前语言快照变化（无 BuildContext，取自 AppLocaleService）。
class CsvExporter {
  const CsvExporter();

  List<String> get header {
    final l10n = AppLocaleService.auto;
    return [
      l10n.csvTime,
      l10n.csvSystolic,
      l10n.csvDiastolic,
      l10n.csvPulse,
      l10n.csvArm,
      l10n.csvPosture,
      l10n.csvNote,
      l10n.csvSource,
    ];
  }

  String buildCsv(List<BpRecord> records) {
    final l10n = AppLocaleService.auto;
    final sb = StringBuffer('\uFEFF'); // UTF-8 BOM
    sb.writeln(header.map(_escape).join(','));
    for (final r in records) {
      sb.writeln([
        _fmtDateTime(r.measuredAt),
        '${r.systolic}',
        '${r.diastolic}',
        r.pulse?.toString() ?? '',
        armLabel(l10n, r.arm),
        r.posture == null ? '' : postureLabel(l10n, r.posture),
        r.note ?? '',
        sourceLabel(l10n, r.source),
      ].map(_escape).join(','));
    }
    return sb.toString();
  }

  /// 导出为临时文件并返回路径。
  Future<File> exportToFile(List<BpRecord> records,
      {String? fileName}) async {
    final dir = await getTemporaryDirectory();
    final name = fileName ??
        'blood_pressed_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(buildCsv(records), flush: true);
    return file;
  }

  static String _fmtDateTime(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _escape(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}

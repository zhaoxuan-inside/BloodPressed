import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// CSV 导出（Excel 兼容：UTF-8 BOM + 标准转义）。
class CsvExporter {
  const CsvExporter();

  static const List<String> header = [
    '测量时间',
    '高压(mmHg)',
    '低压(mmHg)',
    '脉搏(次/分)',
    '测量臂',
    '体位',
    '备注',
    '来源',
  ];

  String buildCsv(List<BpRecord> records) {
    final sb = StringBuffer('\uFEFF'); // UTF-8 BOM
    sb.writeln(header.map(_escape).join(','));
    for (final r in records) {
      sb.writeln([
        _fmtDateTime(r.measuredAt),
        '${r.systolic}',
        '${r.diastolic}',
        r.pulse?.toString() ?? '',
        r.arm.label,
        r.posture?.label ?? '',
        r.note ?? '',
        r.source.label,
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

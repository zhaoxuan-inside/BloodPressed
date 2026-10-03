import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/records/data/records_repository.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';

/// 健康指导的上下文构建器：把近 30 天血压摘要注入 System Prompt。
class HealthContextBuilder {
  HealthContextBuilder(this._repo);

  final RecordsRepository _repo;

  Future<String> buildSystemPrompt() async {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    final stats = await _repo.stats(from: from, to: to);
    final records = await _repo.list(from: from, to: to, limit: 60);
    final latest = records.isEmpty ? null : records.first;

    final sb = StringBuffer();
    sb.writeln('你是一位温和、专业的血压健康管理助手。');
    sb.writeln('要求：');
    sb.writeln('1. 基于用户的血压记录给出生活方式建议（饮食、运动、睡眠、情绪、监测习惯）。');
    sb.writeln('2. 不进行诊断、不推荐具体药物或剂量；用户血压明显异常或出现不适时，'
        '建议及时就医。');
    sb.writeln('3. 回答简明实用，分点说明，每次不超过 300 字。');
    sb.writeln('4. 用中文回答。');
    sb.writeln();
    sb.writeln('以下是用户近 30 天的血压数据摘要：');

    if (stats.count == 0) {
      sb.writeln('（暂无记录，可引导用户先记录几次血压再咨询。）');
      return sb.toString();
    }

    sb.writeln(
        '- 测量次数：${stats.count} 次；平均血压 ${stats.avgSystolic.toStringAsFixed(0)}/'
        '${stats.avgDiastolic.toStringAsFixed(0)} mmHg');
    sb.writeln(
        '- 血压范围：高压 ${stats.minSystolic}~${stats.maxSystolic}，'
        '低压 ${stats.minDiastolic}~${stats.maxDiastolic}');
    if (stats.avgPulse != null) {
      sb.writeln(
          '- 平均脉搏：${stats.avgPulse!.toStringAsFixed(0)} 次/分');
    }
    sb.writeln(
        '- 家庭自测达标率（<135/85）：'
        '${(stats.normalRate * 100).toStringAsFixed(0)}%');

    // 左右臂对比
    final left = records.where((r) => r.arm == MeasureArm.left).toList();
    final right = records.where((r) => r.arm == MeasureArm.right).toList();
    if (left.isNotEmpty && right.isNotEmpty) {
      double avg(List<BpRecord> l, int Function(BpRecord) f) =>
          l.map(f).reduce((a, b) => a + b) / l.length;
      sb.writeln(
          '- 左臂平均 ${avg(left, (r) => r.systolic).toStringAsFixed(0)}/'
          '${avg(left, (r) => r.diastolic).toStringAsFixed(0)}，'
          '右臂平均 ${avg(right, (r) => r.systolic).toStringAsFixed(0)}/'
          '${avg(right, (r) => r.diastolic).toStringAsFixed(0)}'
          '（双臂差值持续大于10建议就医）');
    }

    if (latest != null) {
      final c = BpCategory.fromValues(latest.systolic, latest.diastolic);
      sb.writeln(
          '- 最近一次：${latest.measuredAt.month}月${latest.measuredAt.day}日 '
          '${latest.systolic}/${latest.diastolic} mmHg（${c.label}）');
    }
    sb.writeln();
    sb.writeln('请基于以上数据回答用户问题；若数据不足以支撑结论，请如实说明。');
    return sb.toString();
  }
}

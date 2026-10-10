import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressed/features/records/domain/bp_voice_parser.dart';

void main() {
  group('BpVoiceParser', () {
    // ── 关键词 + 阿拉伯数字 ─────────────────────────────────────────────────

    test('中文关键词 + 阿拉伯数字（全三值）', () {
      final r = BpVoiceParser.parse('收缩压120舒张压80脉搏72');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
      expect(r.isComplete, isTrue);
      expect(r.recognizedCount, 3);
    });

    test('高压/低压/心率别名', () {
      final r = BpVoiceParser.parse('高压 130 低压 85 心率 68');
      expect(r.systolic, 130);
      expect(r.diastolic, 85);
      expect(r.pulse, 68);
    });

    test('英文关键词', () {
      final r = BpVoiceParser.parse('systolic 120 diastolic 80 pulse 72');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    test('sbp/dbp 缩写', () {
      final r = BpVoiceParser.parse('sbp 140 dbp 90 hr 65');
      expect(r.systolic, 140);
      expect(r.diastolic, 90);
      expect(r.pulse, 65);
    });

    // ── 斜杠格式 ──────────────────────────────────────────────────────────

    test('斜杠格式 120/80', () {
      final r = BpVoiceParser.parse('120/80');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, isNull);
    });

    test('斜杠格式带脉搏', () {
      final r = BpVoiceParser.parse('120/80 脉搏 72');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    // ── 中文数字转换 ───────────────────────────────────────────────────────

    test('中文数字：一百二十/八十/七十二', () {
      final r = BpVoiceParser.parse('收缩压一百二十舒张压八十脉搏七十二');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    test('中文数字：一百三十五/九十/六十八', () {
      final r = BpVoiceParser.parse('高压一百三十五低压九十心率六十八');
      expect(r.systolic, 135);
      expect(r.diastolic, 90);
      expect(r.pulse, 68);
    });

    // ── 位置降级匹配 ───────────────────────────────────────────────────────

    test('裸三数字序列（位置推断）', () {
      final r = BpVoiceParser.parse('120 80 72');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    test('裸两数字序列（只有收缩/舒张）', () {
      final r = BpVoiceParser.parse('135 90');
      expect(r.systolic, 135);
      expect(r.diastolic, 90);
      expect(r.pulse, isNull);
    });

    // ── 部分识别 ──────────────────────────────────────────────────────────

    test('只说收缩压', () {
      final r = BpVoiceParser.parse('收缩压 125');
      expect(r.systolic, 125);
      expect(r.diastolic, isNull);
      expect(r.hasAny, isTrue);
      expect(r.isComplete, isFalse);
    });

    test('只说舒张压和心率', () {
      final r = BpVoiceParser.parse('舒张压 82 脉搏 70');
      expect(r.systolic, isNull);
      expect(r.diastolic, 82);
      expect(r.pulse, 70);
    });

    // ── 无效输入 ──────────────────────────────────────────────────────────

    test('空字符串', () {
      final r = BpVoiceParser.parse('');
      expect(r.hasAny, isFalse);
    });

    test('无血压相关内容', () {
      final r = BpVoiceParser.parse('今天天气不错');
      expect(r.hasAny, isFalse);
    });

    test('超出范围的数值不填入', () {
      // 401 超出收缩压上限 300
      final r = BpVoiceParser.parse('收缩压 401 舒张压 80');
      expect(r.systolic, isNull);
      expect(r.diastolic, 80);
    });

    test('舒张压低于下限不填入', () {
      final r = BpVoiceParser.parse('收缩压 120 舒张压 10');
      expect(r.systolic, 120);
      expect(r.diastolic, isNull);
    });

    // ── 带标点噪声 ────────────────────────────────────────────────────────

    test('带逗号句号', () {
      final r = BpVoiceParser.parse('收缩压，120。舒张压，80，脉搏，72。');
      expect(r.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    // ── recognizedCount ────────────────────────────────────────────────────

    test('recognizedCount 计数正确', () {
      expect(
          BpVoiceParser.parse('收缩压120舒张压80脉搏72').recognizedCount, 3);
      expect(BpVoiceParser.parse('收缩压120舒张压80').recognizedCount, 2);
      expect(BpVoiceParser.parse('收缩压120').recognizedCount, 1);
      expect(BpVoiceParser.parse('今天好').recognizedCount, 0);
    });
  });
}

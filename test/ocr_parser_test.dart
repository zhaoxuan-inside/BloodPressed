import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';

void main() {
  const parser = OcrBpParser();

  BpCandidate? best(String text) => parser.parse(text).best;

  group('分数式（fraction）', () {
    test('基本格式 120/80', () {
      final r = best('120/80 mmHg');
      expect(r, isNotNull);
      expect(r!.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, isNull);
      expect(r.confidence, greaterThan(0.6));
    });

    test('带空格 120 / 80 mmHg', () {
      final r = best('120 / 80 mmHg');
      expect(r, isNotNull);
      expect(r!.systolic, 120);
      expect(r.diastolic, 80);
    });

    test('带脉搏 120/80 mmHg 72 bpm', () {
      final r = best('120/80 mmHg 72 bpm');
      expect(r, isNotNull);
      expect(r!.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    test('脉搏缩写 PUL 72', () {
      final r = best('126/83 PUL 68');
      expect(r!.pulse, 68);
    });

    test('全角数字与全角斜杠', () {
      final r = best('１２０／８０ ｍｍＨｇ');
      expect(r, isNotNull);
      expect(r!.systolic, 120);
      expect(r.diastolic, 80);
    });

    test('Omrion 风格带 hr 关键字在后面', () {
      final r = best('mmHg 132 85 hr 66');
      // adjacent 模式（无斜杠）需要 mmHg 关键字，可识别
      expect(r, isNotNull);
      expect(r!.systolic, 132);
      expect(r.diastolic, 85);
    });
  });

  group('标签式（labeled）', () {
    test('中文标签 高压/低压/脉搏', () {
      final r = best('高压 135 低压 85 脉搏 76');
      expect(r, isNotNull);
      expect(r!.systolic, 135);
      expect(r.diastolic, 85);
      expect(r.pulse, 76);
    });

    test('收缩压/舒张压', () {
      final r = best('收缩压 128 舒张压 82');
      expect(r, isNotNull);
      expect(r!.systolic, 128);
      expect(r.diastolic, 82);
    });

    test('英文 SYS/DIA/PUL', () {
      final r = best('SYS 122 DIA 79 PUL 70');
      expect(r, isNotNull);
      expect(r!.systolic, 122);
      expect(r.diastolic, 79);
      expect(r.pulse, 70);
    });

    test('标签式 + mmHg 提升置信度', () {
      final withUnit = best('高压 120 低压 80 mmHg')!;
      final withoutUnit = best('高压 120 低压 80')!;
      expect(withUnit.confidence, greaterThan(withoutUnit.confidence));
    });
  });

  group('非法输入', () {
    test('高压低于低压', () {
      final r = best('60/120 mmHg');
      expect(r, isNull);
    });

    test('超出合理范围', () {
      expect(best('350/80 mmHg'), isNull);
      expect(best('120/10 mmHg'), isNull);
      expect(best('999/999'), isNull);
    });

    test('纯噪声文本', () {
      final result = parser.parse('开始测量 please wait... 记录中');
      expect(result.isEmpty, isTrue);
    });

    test('空文本', () {
      expect(parser.parse('').isEmpty, isTrue);
    });
  });

  group('多行 OCR 场景', () {
    test('典型血压计屏幕输出', () {
      const text = '''
OMRON
13:25
120/80
mmHg
PUL
72
/min
''';
      final r = best(text);
      expect(r, isNotNull);
      expect(r!.systolic, 120);
      expect(r.diastolic, 80);
      expect(r.pulse, 72);
    });

    test('两段读数取最高置信度', () {
      const text = '''
上一条记录 98/64
当前测量 128/84 mmHg 脉搏 74
''';
      final result = parser.parse(text);
      expect(result.candidates.length, greaterThanOrEqualTo(2));
      // 置信度排序：带 mmHg 的在前
      expect(result.best!.systolic, 128);
    });
  });

  group('LLM 提取解析（多模态兜底）', () {
    test('纯 JSON', () {
      final c = parseLlmExtraction(
          '{"systolic": 118, "diastolic": 76, "pulse": 71}');
      expect(c, isNotNull);
      expect(c!.systolic, 118);
      expect(c.pulse, 71);
    });

    test('markdown 代码块包裹', () {
      final c = parseLlmExtraction('识别结果如下：\n```json\n'
          '{"systolic": 132, "diastolic": 88, "pulse": null}\n```');
      expect(c, isNotNull);
      expect(c!.systolic, 132);
      expect(c.diastolic, 88);
    });

    test('夹带说明文字', () {
      final c = parseLlmExtraction(
          '好的，我识别到的高压是145低压是95。结果：{"systolic":"145","diastolic":"95"}');
      expect(c, isNotNull);
      expect(c!.systolic, 145);
    });

    test('不合理数值返回 null', () {
      expect(
        parseLlmExtraction('{"systolic": 500, "diastolic": 80}'),
        isNull,
      );
      expect(parseLlmExtraction('我看不到任何数字'), isNull);
    });
  });
}

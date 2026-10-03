import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';

void main() {
  group('血压分级', () {
    test('家庭自测标准分级', () {
      expect(BpCategory.fromValues(120, 78), BpCategory.normal);
      expect(BpCategory.fromValues(132, 80), BpCategory.elevated);
      expect(BpCategory.fromValues(145, 85), BpCategory.grade1);
      expect(BpCategory.fromValues(165, 95), BpCategory.grade2);
      expect(BpCategory.fromValues(85, 55), BpCategory.low);
    });
  });

  group('OCR 解析', () {
    const parser = OcrBpParser();
    test('分数式', () {
      final r = parser.parse('120/80 mmHg');
      expect(r.best, isNotNull);
      expect(r.best!.systolic, 120);
      expect(r.best!.diastolic, 80);
    });
    test('标签式带脉搏', () {
      final r = parser.parse('SYS 118 DIA 76 PUL 72');
      expect(r.best, isNotNull);
    });
  });

  testWidgets('占位冒烟测试', (tester) async {
    expect(true, isTrue);
  });
}

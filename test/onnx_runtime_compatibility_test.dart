import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';

void main() {
  test('OCR models execute with the newer runtime required by speech', () {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final package = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'sherpa_onnx_windows');
    final directory = Directory.fromUri(
      Uri.parse(package['rootUri'] as String),
    );
    DynamicLibrary.open('${directory.path}/windows/onnxruntime.dll');

    for (final model in ['det', 'rec']) {
      final shape = model == 'det' ? [1, 3, 64, 64] : [1, 3, 48, 320];
      final options = OrtSessionOptions();
      final session = OrtSession.fromBuffer(
        File('assets/models/ppocr/ch_PP-OCRv5_${model}_mobile.onnx')
            .readAsBytesSync(),
        options,
      );
      final count = shape.reduce((a, b) => a * b);
      final input = OrtValueTensor.createTensorWithDataList(
        Float32List(count),
        shape,
      );
      final runOptions = OrtRunOptions();
      try {
        final output = session.run(runOptions, {
          session.inputNames.first: input,
        });
        expect(output, isNotEmpty);
        expect(output.first?.value, isNotNull);
        for (final value in output) {
          value?.release();
        }
      } finally {
        input.release();
        runOptions.release();
        session.release();
        options.release();
      }
    }
  }, skip: !Platform.isWindows ? 'Windows host native-runtime check' : false);
}

/// 门槛问答协议单测：schema 合法性、parseGatedAnswer 语义校验、
/// chatJson 未就绪守卫（真实模型加载属真机冒烟范畴）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart'
    show LlamaInferenceException, LlamaStructuredOutput;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/assistant/domain/gated_answer.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';

void main() {
  group('门槛答案解析', () {
    test('合法输出（含 90 分边界）可解析且 isReliable 正确', () {
      final high = parseGatedAnswer(
          const {'answer': '血压 120/80 属正常范围。', 'confidence': 90});
      expect(high, isNotNull);
      expect(high!.isReliable, isTrue);

      final mid = parseGatedAnswer(
          const {'answer': '可能是……', 'confidence': 89});
      expect(mid, isNotNull);
      expect(mid!.isReliable, isFalse);
    });

    test('非法输入一律返回 null（拒答兜底）', () {
      expect(parseGatedAnswer(const {'confidence': 95}), isNull);
      expect(parseGatedAnswer(const {'answer': '  ', 'confidence': 95}),
          isNull);
      expect(parseGatedAnswer(const {'answer': 'x', 'confidence': 101}),
          isNull);
      expect(parseGatedAnswer(const {'answer': 'x', 'confidence': -1}),
          isNull);
      expect(parseGatedAnswer(const {'answer': 'x', 'confidence': '95'}),
          isNull);
      expect(parseGatedAnswer(const <String, Object?>{}), isNull);
    });

    test('gatedAnswerSchema 可被 llamadart 校验并通过 parse 解码', () {
      final output =
          LlamaStructuredOutput<Map<String, Object?>>.jsonSchema(
        schema: gatedAnswerSchema,
        decoder: (value) => value,
      );
      final decoded =
          output.parse('{"answer": "建议低盐饮食。", "confidence": 92}');
      expect(decoded['answer'], '建议低盐饮食。');
      expect(decoded['confidence'], 92);

      // grammar 约束失败的兜底路径：不合法 JSON 在 parse 处抛出
      expect(() => output.parse('不是 JSON'),
          throwsA(isA<LlamaInferenceException>()));
    });
  });

  group('chatJson 未就绪守卫', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDatabase.resetInstanceForTest();
      db = await AppDatabase.openForTest(
          await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath));
    });

    tearDown(() async {
      await db.db.close();
      AppDatabase.resetInstanceForTest();
    });

    test('引擎未加载时抛 InferenceException（引擎层与控制器层）', () async {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
      ]);
      addTearDown(c.dispose);

      expect(
        () => c.read(llmEngineProvider.notifier).chatJson(
              const [],
              schema: gatedAnswerSchema,
            ),
        throwsA(isA<InferenceException>()),
      );
    });
  });
}

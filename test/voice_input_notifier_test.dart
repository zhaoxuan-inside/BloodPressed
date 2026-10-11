/// 语音录入状态机测试：用 Fake service 驱动 VoiceInputNotifier，
/// 覆盖错误兜底、会话静默结束自恢复、看门狗与 partial 降级解析。
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:blood_pressed/features/records/data/voice_input_service.dart';
import 'package:blood_pressed/features/records/presentation/controllers/voice_input_provider.dart';

class FakeVoiceInputService implements VoiceInputService {
  FakeVoiceInputService({this.available = true, this.initThrows = false});

  final bool available;
  final bool initThrows;

  bool listening = false;
  int stopCalls = 0;

  VoiceResultCallback? resultSink;
  VoiceErrorCallback? errorSink;
  VoiceStatusCallback? statusSink;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize() async {
    if (initThrows) throw StateError('init boom');
    return available;
  }

  @override
  Future<void> startListening({
    required VoiceResultCallback onResult,
    VoiceErrorCallback? onError,
    VoiceStatusCallback? onStatus,
    String? localeId,
  }) async {
    resultSink = onResult;
    errorSink = onError;
    statusSink = onStatus;
    listening = true;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancelListening() async {
    listening = false;
  }

  @override
  void dispose() {}
}

VoiceInputResult _final(String text) =>
    VoiceInputResult(text: text, isFinal: true);

VoiceInputResult _partial(String text) =>
    VoiceInputResult(text: text, isFinal: false);

void main() {
  group('VoiceInputNotifier', () {
    test('初始化成功 → idle', () {
      fakeAsync((async) {
        final notifier = VoiceInputNotifier(FakeVoiceInputService());
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('初始化失败/抛异常 → notAvailable', () {
      fakeAsync((async) {
        final n1 = VoiceInputNotifier(FakeVoiceInputService(available: false));
        async.flushMicrotasks();
        expect(n1.state.status, VoiceInputStatus.notAvailable);
        n1.dispose();

        final n2 = VoiceInputNotifier(FakeVoiceInputService(initThrows: true));
        async.flushMicrotasks();
        expect(n2.state.status, VoiceInputStatus.notAvailable);
        n2.dispose();
      });
    });

    test('最终结果 → done 并解析回填，consumeResult 复位', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.listening);

        svc.resultSink!(_final('收缩压120舒张压80脉搏72'));
        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 120);
        expect(notifier.state.result?.diastolic, 80);
        expect(notifier.state.result?.pulse, 72);

        notifier.consumeResult();
        expect(notifier.state.status, VoiceInputStatus.idle);
        expect(notifier.state.result, isNull);
        notifier.dispose();
      });
    });

    test('会话静默结束（status done）但只有 partial → 降级解析', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('血压128低压85'));
        svc.statusSink!('done');

        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 128);
        expect(notifier.state.result?.diastolic, 85);
        notifier.dispose();
      });
    });

    test('会话静默结束且无内容 → error（no_speech）+ 消息（不再卡聆听）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.statusSink!('done');

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.noSpeech);
        expect(notifier.state.errorMessage, isNotNull);
        notifier.dispose();
      });
    });

    test('错误回调 → error 状态 + 消息 + 错误码，consumeResult 复位', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.errorSink!(VoiceInputError.permissionDenied);

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.permissionDenied);
        expect(notifier.state.errorMessage, contains('麦克风'));

        notifier.consumeResult();
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });

    test('错误回调保留已收到的 partial 文本（供错误报告排查）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('血压一百三'));
        svc.errorSink!(VoiceInputError.unknown);

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.partialText, '血压一百三');
        expect(notifier.state.errorCode, VoiceInputError.unknown);
        notifier.dispose();
      });
    });

    test('非聆听状态下的错误回调被忽略', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.cancel();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        svc.errorSink!(VoiceInputError.unknown);
        expect(notifier.state.status, VoiceInputStatus.idle);
        expect(notifier.state.errorMessage, isNull);
        notifier.dispose();
      });
    });

    test('看门狗：无任何回调 18s 后强制离开 listening（无内容 → error）', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 19));

        expect(notifier.state.status, VoiceInputStatus.error);
        expect(notifier.state.errorCode, VoiceInputError.watchdogTimeout);
        expect(notifier.state.errorMessage, isNotNull);
        expect(svc.stopCalls, 1);
        notifier.dispose();
      });
    });

    test('看门狗：已有 partial 内容 → 降级解析为 done', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        svc.resultSink!(_partial('高压135低压90'));
        async.elapse(const Duration(seconds: 19));

        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 135);
        expect(notifier.state.result?.diastolic, 90);
        notifier.dispose();
      });
    });

    test('手动停止后收到最终结果仍正常解析', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.stopListening();
        async.flushMicrotasks();
        // stopListening 兜底复位（尚无结果）
        expect(notifier.state.status, VoiceInputStatus.idle);

        // 引擎随后送达最终结果
        svc.resultSink!(_final('收缩压118舒张压76脉搏70'));
        expect(notifier.state.status, VoiceInputStatus.done);
        expect(notifier.state.result?.systolic, 118);
        notifier.dispose();
      });
    });

    test('取消 → 复位 idle，看门狗撤销', () {
      fakeAsync((async) {
        final svc = FakeVoiceInputService();
        final notifier = VoiceInputNotifier(svc);
        async.flushMicrotasks();

        notifier.startListening();
        async.flushMicrotasks();
        notifier.cancel();
        async.flushMicrotasks();
        expect(notifier.state.status, VoiceInputStatus.idle);

        async.elapse(const Duration(seconds: 19));
        expect(notifier.state.status, VoiceInputStatus.idle);
        notifier.dispose();
      });
    });
  });

  group('SpeechToTextInputService', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Future<void> mockSttChannel(Future<Object?>? Function(String) handler) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugin.csdcorp.com/speech_to_text'),
        (call) async => handler(call.method),
      );
    }

    test('initialize 平台异常 → 不可用，listen 前 not_available', () async {
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.granted,
      );
      final ok = await svc.initialize();
      expect(ok, isFalse);

      String? code;
      await svc.startListening(onResult: (_) {}, onError: (c) => code = c);
      expect(code, VoiceInputError.notAvailable);
    });

    test('无麦克风权限 → permission_denied 且不进入聆听', () async {
      await mockSttChannel((method) async {
        if (method == 'has_permission') return true;
        if (method == 'initialize') return true;
        if (method == 'listen') return true;
        return null;
      });
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.denied,
      );
      expect(await svc.initialize(), isTrue);

      String? code;
      VoiceInputResult? anyResult;
      await svc.startListening(
        onResult: (r) => anyResult = r,
        onError: (c) => code = c,
      );
      expect(code, VoiceInputError.permissionDenied);
      expect(anyResult, isNull);
      expect(svc.isListening, isFalse);
    });

    test('权限授予 → 发起 listen（插件 listen 已被调用且无错误）', () async {
      var listenCalled = false;
      await mockSttChannel((method) async {
        if (method == 'has_permission') return true;
        if (method == 'initialize') return true;
        if (method == 'listen') {
          listenCalled = true;
          return true;
        }
        return null;
      });
      final svc = SpeechToTextInputService(
        requestMicPermission: () async => PermissionStatus.granted,
      );
      expect(await svc.initialize(), isTrue);

      String? error;
      await svc.startListening(onResult: (_) {}, onError: (c) => error = c);
      expect(error, isNull);
      expect(listenCalled, isTrue);
    });
  });
}

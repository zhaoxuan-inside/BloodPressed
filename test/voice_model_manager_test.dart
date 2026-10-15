import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/records/data/voice_model_manager.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Tests must use the injected HTTP adapter');
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

// Sparse fixtures avoid allocating the full model in memory or on disk.
void _sized(File file, int size) {
  final handle = file.openSync(mode: FileMode.write);
  if (size > 0) {
    handle.setPositionSync(size - 1);
    handle.writeByteSync(0);
  }
  handle.closeSync();
}

void main() {
  final previousOverrides = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = _NoNetwork());
  tearDownAll(() => HttpOverrides.global = previousOverrides);
  late Directory temp;
  late Dio dio;
  late VoiceModelManager manager;
  late Directory modelDir;
  final tokens = VoiceModelManager.files.last;
  File target() => File('${modelDir.path}/${tokens.localName}');
  File part() => File('${target().path}.part');

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('voice-model-test-');
    dio = Dio();
    // No test can accidentally fall through to the public model endpoint.
    dio.httpClientAdapter = _Adapter(
      (_) => throw StateError('unexpected HTTP'),
    );
    manager = VoiceModelManager(dio: dio, docsPath: temp.path);
    modelDir = Directory(await manager.modelDir());
    for (final file in VoiceModelManager.files.take(3)) {
      _sized(File('${modelDir.path}/${file.localName}'), file.size);
    }
  });

  tearDown(() {
    dio.close(force: true);
    temp.deleteSync(recursive: true);
  });

  test('206 appends to the existing prefix and completes the model', () async {
    _sized(part(), tokens.size - 4);
    final prefix = part().openSync(mode: FileMode.append);
    prefix.setPositionSync(0);
    prefix.writeByteSync(42);
    prefix.closeSync();
    dio.httpClientAdapter = _Adapter((request) {
      expect(request.headers['range'], 'bytes=${tokens.size - 4}-');
      return ResponseBody.fromBytes(
        [1, 2, 3, 4],
        206,
        headers: {
          'content-range': [
            'bytes ${tokens.size - 4}-${tokens.size - 1}/${tokens.size}',
          ],
        },
      );
    });
    await manager.download();
    expect(await manager.isDownloaded(), isTrue);
    final handle = target().openSync();
    expect(handle.readByteSync(), 42);
    handle.setPositionSync(tokens.size - 4);
    expect(handle.readSync(4), [1, 2, 3, 4]);
    handle.closeSync();
    expect(part().existsSync(), isFalse);
  });

  test('200 ignores Range safely by replacing the partial file', () async {
    _sized(part(), tokens.size - 4);
    _sized(target(), 3); // Replace an invalid file left by an earlier attempt.
    dio.httpClientAdapter = _Adapter(
      (_) => ResponseBody.fromBytes(List.filled(tokens.size, 7), 200),
    );
    await manager.download();
    expect(await manager.isDownloaded(), isTrue);
    expect(target().readAsBytesSync().every((byte) => byte == 7), isTrue);
  });

  test(
    'wrong Content-Range rejects the response without touching the prefix',
    () async {
      _sized(part(), tokens.size - 4);
      dio.httpClientAdapter = _Adapter(
        (_) => ResponseBody.fromBytes(
          [1, 2],
          206,
          headers: {
            'content-range': ['bytes 0-1/${tokens.size}'],
          },
        ),
      );
      await expectLater(manager.download(), throwsException);
      expect(part().lengthSync(), tokens.size - 4);
      expect(target().existsSync(), isFalse);
      expect(manager.isDownloading, isFalse);
    },
  );

  test(
    'interrupted transfer preserves bytes and retries from the new offset',
    () async {
      _sized(part(), tokens.size - 4);
      dio.httpClientAdapter = _Adapter(
        (_) => ResponseBody(
          (() async* {
            yield Uint8List.fromList([1, 2]);
            throw StateError('connection lost');
          })(),
          206,
          headers: {
            'content-range': [
              'bytes ${tokens.size - 4}-${tokens.size - 1}/${tokens.size}',
            ],
          },
        ),
      );
      await expectLater(manager.download(), throwsA(anything));
      expect(part().lengthSync(), tokens.size - 2);
      expect(manager.isDownloading, isFalse);
      dio.httpClientAdapter = _Adapter((request) {
        expect(request.headers['range'], 'bytes=${tokens.size - 2}-');
        return ResponseBody.fromBytes(
          [3, 4],
          206,
          headers: {
            'content-range': [
              'bytes ${tokens.size - 2}-${tokens.size - 1}/${tokens.size}',
            ],
          },
        );
      });
      await manager.download();
      expect(await manager.isDownloaded(), isTrue);
    },
  );

  test('oversized response is rejected and discarded before retry', () async {
    dio.httpClientAdapter = _Adapter(
      (_) => ResponseBody.fromBytes(List.filled(tokens.size + 1, 7), 200),
    );
    await expectLater(manager.download(), throwsException);
    expect(target().existsSync(), isFalse);
    expect(part().existsSync(), isFalse);
    expect(manager.isDownloading, isFalse);
  });

  test('complete .part is promoted without making a request', () async {
    _sized(part(), tokens.size);
    await manager.download();
    expect(await manager.isDownloaded(), isTrue);
  });

  test('oversized .part restarts without Range', () async {
    _sized(part(), tokens.size + 1);
    dio.httpClientAdapter = _Adapter((request) {
      expect(request.headers['range'], isNull);
      return ResponseBody.fromBytes(List.filled(tokens.size, 1), 200);
    });
    await manager.download();
    expect(await manager.isDownloaded(), isTrue);
  });

  test('progress accumulates across files and stays within bounds', () async {
    for (final file in modelDir.listSync()) {
      file.deleteSync();
    }
    final progress = <double>[];
    manager = VoiceModelManager(
      docsPath: temp.path,
      fetcher: (url, file, start, onReceived) async {
        final spec = VoiceModelManager.files.firstWhere(
          (spec) => url == VoiceModelManager.downloadUrl(spec.remotePath),
        );
        _sized(file, spec.size);
        onReceived(spec.size ~/ 2);
        onReceived(spec.size);
      },
    );
    final subscription = manager.progressStream.listen(progress.add);
    await manager.download();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(progress, isNotEmpty);
    for (var i = 0; i < progress.length; i++) {
      expect(progress[i], inInclusiveRange(0, 1));
      if (i > 0) expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
    expect(progress.last, 1);
    expect(await manager.isDownloaded(), isTrue);
  });
}

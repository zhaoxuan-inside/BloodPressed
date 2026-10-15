import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_pressed/features/records/data/bundled_voice_model_store.dart';
import 'package:blood_pressed/features/records/data/voice_model_manager.dart';

class _Assets extends CachingAssetBundle {
  int loads = 0;
  bool badTokens = false;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (badTokens && key.endsWith('tokens.txt')) return ByteData(1);
    return ByteData.sublistView(await File(key).readAsBytes());
  }
}

void main() {
  late Directory temporary;
  late _Assets assets;
  late BundledVoiceModelStore store;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('bundled-voice-');
    assets = _Assets();
    store = BundledVoiceModelStore(bundle: assets, docsPath: temporary.path);
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test('fresh install deploys the actual bundled model without HTTP', () async {
    expect(await store.isDownloaded(), isFalse);
    await store.download();
    expect(await store.isDownloaded(), isTrue);
    expect(assets.loads, 4);
    final dir = await store.modelDir();
    for (final spec in VoiceModelManager.files) {
      final deployed = File('$dir/${spec.localName}');
      expect(deployed.lengthSync(), spec.size);
      final actual = deployed.openSync();
      final expected = File('assets/models/voice/${spec.localName}').openSync();
      expect(actual.readSync(64), expected.readSync(64));
      actual.setPositionSync(spec.size - 64);
      expected.setPositionSync(spec.size - 64);
      expect(actual.readSync(64), expected.readSync(64));
      actual.closeSync();
      expected.closeSync();
    }
    await store.download();
    expect(assets.loads, 4); // Already deployed assets are reused.
    expect(store.progress, 1);
    expect(store.isDownloading, isFalse);
  });

  test('concurrent initializations share a single deployment', () async {
    await Future.wait([store.download(), store.download(), store.download()]);
    expect(await store.isDownloaded(), isTrue);
    expect(assets.loads, 4);
  });

  test(
    'bad asset is rejected, then only the missing file is retried',
    () async {
      assets.badTokens = true;
      await expectLater(store.download(), throwsStateError);
      expect(await store.isDownloaded(), isFalse);
      expect(store.isDownloading, isFalse);
      assets.badTokens = false;
      await store.download();
      expect(await store.isDownloaded(), isTrue);
      expect(assets.loads, 5);
      final dir = Directory(await store.modelDir());
      expect(
        dir.listSync().where((file) => file.path.endsWith('.part')),
        isEmpty,
      );
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:blood_pressed/features/records/data/voice_model_manager.dart';

/// Deploys the bundled speech model locally; never makes a network request.
class BundledVoiceModelStore implements VoiceModelStore {
  BundledVoiceModelStore({AssetBundle? bundle, String? docsPath})
    : _bundle = bundle ?? rootBundle,
      _storage = VoiceModelManager(docsPath: docsPath);

  final AssetBundle _bundle;
  final VoiceModelManager _storage;
  Future<void>? _installation;
  double _progress = 0;

  @override
  bool get isDownloading => _installation != null;

  @override
  double get progress => _progress;

  @override
  Stream<double> get progressStream => const Stream.empty();

  @override
  Future<String> modelDir() => _storage.modelDir();

  @override
  Future<bool> isDownloaded() => _storage.isDownloaded();

  /// The legacy store calls this download; here it only copies APK assets.
  @override
  Future<void> download() {
    return _installation ??= _install().whenComplete(
      () => _installation = null,
    );
  }

  Future<void> _install() async {
    final dir = await modelDir();
    var completed = 0;
    for (final spec in VoiceModelManager.files) {
      final target = File('$dir/${spec.localName}');
      if (!target.existsSync() || target.lengthSync() != spec.size) {
        final data = await _bundle.load(
          'assets/models/voice/${spec.localName}',
        );
        if (data.lengthInBytes != spec.size) {
          throw StateError(
            'Bundled voice model size mismatch: ${spec.localName}',
          );
        }
        final temporary = File('${target.path}.bundled.part');
        try {
          await temporary.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
          if (target.existsSync()) await target.delete();
          await temporary.rename(target.path);
        } finally {
          if (temporary.existsSync()) await temporary.delete();
        }
      }
      completed += spec.size;
      _progress = completed / VoiceModelManager.totalBytes;
    }
  }
}

// Runs the production recognizer configuration against a real audio fixture.
// dart --packages=.dart_tool/package_config.json scripts/verify_voice_model.dart
// Optional arguments: model directory, mono PCM WAV path.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:blood_pressed/features/records/data/offline_voice_config.dart';

void main(List<String> args) {
  if (Platform.isWindows) {
    // Windows System32 also has an older onnxruntime.dll; preload the runtime
    // matching sherpa rather than resolving that system copy as a dependency.
    final path = sherpa.resolveSherpaOnnxPathSync();
    if (path == null) throw StateError('Cannot locate sherpa native runtime');
    DynamicLibrary.open('$path/onnxruntime.dll');
  }
  sherpa.initBindings();
  final modelDir = args.isNotEmpty ? args[0] : 'assets/models/voice';
  final wav = args.length > 1 ? args[1] : 'test/fixtures/voice/0.wav';
  final recognizer = sherpa.OnlineRecognizer(offlineVoiceConfig(modelDir));
  final stream = recognizer.createStream();
  try {
    final wave = sherpa.readWave(wav);
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    stream.acceptWaveform(
      samples: Float32List(wave.sampleRate),
      sampleRate: wave.sampleRate,
    );
    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final text = recognizer.getResult(stream).text;
    stdout.writeln(text);
    // The bilingual fixture contains these Mandarin words and English weekdays.
    if (!text.contains('昨天') ||
        !text.contains('星期三') ||
        !text.toUpperCase().contains('MONDAY')) {
      throw StateError('Unexpected transcript: $text');
    }
  } finally {
    stream.free();
    recognizer.free();
  }
}

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Shared by the microphone service and real native model verification.
sherpa.OnlineRecognizerConfig offlineVoiceConfig(String modelDir) =>
    sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: '$modelDir/encoder.int8.onnx',
          decoder: '$modelDir/decoder.onnx',
          joiner: '$modelDir/joiner.int8.onnx',
        ),
        tokens: '$modelDir/tokens.txt',
        // Empty means read model_type from ONNX metadata. This model is
        // Zipformer v1; forcing zipformer2 can terminate the native runtime.
        modelType: '',
        numThreads: 2,
        debug: false,
      ),
      enableEndpoint: true,
      rule1MinTrailingSilence: 1.8,
      rule2MinTrailingSilence: 1.2,
    );

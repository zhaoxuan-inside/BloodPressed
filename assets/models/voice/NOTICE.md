# Bundled offline speech model

Model: k2-fsa sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16.
Architecture: Zipformer v1, streaming transducer, Chinese and English.
Upstream: https://github.com/k2-fsa/sherpa-onnx
Original model and license declaration: https://huggingface.co/csukuangfj/k2fsa-zipformer-bilingual-zh-en-t
Model documentation: https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html
Mirror: https://modelscope.cn/models/liaowenbin/sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16-mobile
Pinned mirror revision: 00710ef42664d2f9ebc25da91c556526177674d3.
The corresponding original model files are redistributed under Apache-2.0;
see LICENSE.txt in this directory. Model author: k2-fsa.

Files were downloaded from the mirror's root and verified against its SHA256 metadata:

- encoder.int8.onnx (32631819 bytes): ed2932a455d69fb6555ee6a1badcc4b765bef60e426796b62fca18b36328b941
- decoder.onnx (13877276 bytes): 89be509a83175261695bdef5fd1c7b9ab1129a663d1284e7ba9f8507b21e0906
- joiner.int8.onnx (3228485 bytes): bdda356d6f9b8c2d7cee9ee0e26075fa537490f7fd06520be408d287073667b9
- tokens.txt (56317 bytes): a8e0e4ec53810e433789b54a5c0134a7eaa2ffca595a6334d54c00da858841d3

test/fixtures/voice/0.wav is the same model's upstream bilingual test sample,
retrieved from test_wavs/0.wav at the pinned revision.
SHA256: 7d93384ca14702cc584a7a33fe2fed92e89e708549161cb12ea38c916882103b.

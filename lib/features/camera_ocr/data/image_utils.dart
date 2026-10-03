import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 图片处理工具：多模态识别前的压缩、OCR 原图的持久化保存。
class ImageUtils {
  ImageUtils._();

  /// 压缩到最大边长 [maxSide]、JPEG 质量 [quality]。
  static Future<Uint8List> compressForAi(
    String path, {
    int maxSide = 1280,
    int quality = 82,
  }) async {
    final bytes = await File(path).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('无法解码图片：$path');
    }
    if (image.width > maxSide || image.height > maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxSide : null,
        height: image.height > image.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// 把临时图片复制到应用文档目录长期保存（记录引用）。
  static Future<String> persistImage(String srcPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'photos'));
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(srcPath)}';
    final dest = p.join(photosDir.path, name);
    await File(srcPath).copy(dest);
    return dest;
  }
}

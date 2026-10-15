import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// OCR 原图的持久化保存。
class ImageUtils {
  ImageUtils._();

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

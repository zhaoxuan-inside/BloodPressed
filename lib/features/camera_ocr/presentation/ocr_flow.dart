import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/features/camera_ocr/data/image_utils.dart';
import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/ppocr_service.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/position_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/seven_segment.dart';
import 'package:permission_handler/permission_handler.dart';

/// OCR 识别总流程（拍照 / 相册 → 七段码 LCD / PP-OCR → 解析 → 确认表单。
/// 识别结果无论置信度高低都进确认表单预填，低置信度红框强调，不弹窗打断。
class OcrFlow {
  OcrFlow._();

  /// 从相机拍照开始：直接调起系统相机（自绘取景框纵向比例不适配手机，已废弃）。
  static Future<void> startCamera(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!context.mounted) return;
      showErrorDialog(context, '未获得相机权限', '请在系统设置中允许相机后重试。');
      return;
    }
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (xfile == null || !context.mounted) return;
    await _runPipeline(context, xfile.path);
  }

  /// 从相册选择开始。
  static Future<void> startGallery(BuildContext context) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (xfile == null || !context.mounted) return;
    await _runPipeline(context, xfile.path);
  }

  static Future<void> _runPipeline(
      BuildContext context, String imagePath) async {
    // 加载框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在识别…'),
              ],
            ),
          ),
        ),
      ),
    );

    OcrParseResult? result;
    String? errorMsg;
    String lcdSummary = '';
    try {
      final image = await PpOcrService.decodeImage(imagePath);
      // 1) 七段码专用路径：彩色背光血压计屏。巨型七段字形是通用文本
      //    检测/识别模型的盲区（plan-006 对照实验），先走结构化读取。
      SevenSegmentReader.collectDebugArtifacts = true;
      final readout = SevenSegmentReader()
          .read(SegImage(image.rgba, image.width, image.height));
      lcdSummary = readout == null
          ? 'LCD: 未找到彩色背光屏'
          : 'LCD 读数: ${readout.numbers.isEmpty ? "无可读数字" : readout.numbers}';
      final lcdResult = readout == null ? null : parseLcdReadout(readout);
      if (lcdResult != null && lcdResult.isReliable) {
        debugPrint('OCR LCD readout: $readout');
        result = lcdResult;
      } else {
        // 2) 通用 PP-OCR 路径（印刷体/非彩色背光照片）
        final lines = await PpOcrService().recognizeImage(image);
        result = parsePositionedLines(lines);
        lcdSummary += '；OCR 行数: ${lines.length}';
      }
    } on PlatformException catch (e) {
      debugPrint('OCR PlatformException: $e');
      errorMsg = '识别服务异常，请重试；若持续失败请改用手动录入';
    } catch (e) {
      debugPrint('OCR error: $e');
      errorMsg = '识别失败：$e';
    } finally {
      SevenSegmentReader.collectDebugArtifacts = false;
    }
    final reliable = result != null && result.isReliable && result.best != null;
    if (!reliable) {
      // 失败/低置信自诊断：留存实际处理的照片与 LCD 中间图，便于回放定位
      lcdSummary = await _saveDiagnostics(imagePath, lcdSummary);
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关掉加载框

    if (errorMsg != null) {
      // 服务级异常（解码/推理崩溃）仍需提示；识别读不出不算错误，
      // 直接进确认表单交由用户核对
      if (context.mounted) {
        showErrorDialog(context, '识别失败', '$errorMsg\n$lcdSummary');
      }
      return;
    }

    if (!context.mounted) return;
    await _openConfirm(
      context,
      imagePath,
      source: RecordSource.ocr,
      candidate: result?.best,
      lowConfidence: !reliable,
    );
  }

  /// 失败自诊断：留存输入照片、LCD 中间图与读数摘要到文档目录，
  /// 返回追加了诊断位置信息的摘要。
  static Future<String> _saveDiagnostics(
      String imagePath, String lcdSummary) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final dir = Directory(p.join(docs.path, 'ocr_debug', stamp));
      dir.createSync(recursive: true);
      final src = File(imagePath);
      if (src.existsSync()) {
        await src.copy(p.join(dir.path, 'input.jpg'));
      }
      final artifacts = SevenSegmentReader.debugOrientations;
      for (var i = 0; i < artifacts.length; i++) {
        final o = artifacts[i];
        final w = o[0] as int, h = o[1] as int;
        final gray = o[2] as Uint8List, clean = o[4] as Uint8List;
        void dumpPng(String name, Uint8List plane) {
          final im = img.Image.fromBytes(
            width: w,
            height: h,
            bytes: plane.buffer,
            numChannels: 1,
          );
          File(p.join(dir.path, name)).writeAsBytesSync(img.encodePng(im));
        }

        dumpPng('lcd$i.png', gray);
        dumpPng('clean$i.png', clean);
      }
      File(p.join(dir.path, 'summary.txt')).writeAsStringSync(
          '${DateTime.now()}\n$lcdSummary\n',
          flush: true);
      return '$lcdSummary\n（诊断已存 ocr_debug/${p.basename(dir.path)}）';
    } catch (e) {
      debugPrint('save diagnostics failed: $e');
      return lcdSummary;
    }
  }

  static Future<void> _openConfirm(
    BuildContext context,
    String imagePath, {
    required RecordSource source,
    BpCandidate? candidate,
    bool lowConfidence = false,
  }) async {
    // 持久化照片（用户已进入确认环节）
    String? persisted;
    try {
      if (File(imagePath).existsSync()) {
        persisted = await ImageUtils.persistImage(imagePath);
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RecordEditPage(
        initialSystolic: candidate?.systolic,
        initialDiastolic: candidate?.diastolic,
        initialPulse: candidate?.pulse,
        initialSource: source,
        initialPhotoPath: persisted,
        initialConfidence: candidate?.confidence,
        initialLowConfidence: lowConfidence,
      ),
    ));
  }

  static void showErrorDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 快捷入口（供其他页面调用）。
void startCameraOcrFlow(BuildContext context) =>
    OcrFlow.startCamera(context);

void startGalleryOcrFlow(BuildContext context) =>
    OcrFlow.startGallery(context);

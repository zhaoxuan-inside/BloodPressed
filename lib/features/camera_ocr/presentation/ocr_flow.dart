import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/vision_extract.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/features/camera_ocr/data/image_utils.dart';
import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/ppocr_service.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/position_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ppocr/seven_segment.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/common_widgets.dart' show showConfirmDialog;

/// OCR 识别总流程（拍照 / 相册 → ML Kit → 解析 → 确认表单；低置信度走大模型兜底）。
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
    if (result == null || !result.isReliable) {
      // 失败自诊断：留存实际处理的照片与 LCD 中间图，便于回放定位
      lcdSummary = await _saveDiagnostics(imagePath, lcdSummary);
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关掉加载框

    if (errorMsg != null) {
      if (context.mounted) {
        showErrorDialog(context, '识别失败', '$errorMsg\n$lcdSummary');
      }
      return;
    }

    // OCR 不可用（无 GMS 设备）
    if (result == null) {
      if (!context.mounted) return;
      await _onOcrUnavailable(context, imagePath);
      return;
    }

    if (result.isReliable && result.best != null) {
      if (!context.mounted) return;
      await _openConfirm(context, imagePath, result.best!,
          source: RecordSource.ocr);
      return;
    }

    // 不可靠：尝试大模型兜底 / 低置信度手填
    if (!context.mounted) return;
    await _onLowConfidence(context, imagePath, result, lcdSummary);
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

  static Future<void> _onOcrUnavailable(
      BuildContext context, String imagePath) async {
    final canUseAi = _hasVisionLlm(context);
    final action = await _chooseFallback(
      context,
      title: '无法使用本地文字识别',
      message: canUseAi
          ? '该设备不支持离线 OCR（缺少 Google 服务组件）。可以改用已配置的大模型识别，或手动录入。'
          : '该设备不支持离线 OCR（缺少 Google 服务组件）。可配置多模态大模型后使用 AI 识别，或手动录入。',
      allowAi: canUseAi,
    );
    if (action == _Fallback.manual && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const RecordEditPage(),
        fullscreenDialog: true,
      ));
    } else if (action == _Fallback.ai && context.mounted) {
      await _runAiRecognize(context, imagePath);
    }
  }

  static Future<void> _onLowConfidence(BuildContext context,
      String imagePath, OcrParseResult result, String lcdSummary) async {
    final canUseAi = _hasVisionLlm(context);
    final best = result.best;
    if (canUseAi) {
      final useAi = await showConfirmDialog(
        context,
        title: '识别结果不确定',
        content: best == null
            ? '未能从照片中识别出血压数值（$lcdSummary）。是否用已配置的大模型重新识别？'
            : '识别置信度较低（${(best.confidence * 100).toStringAsFixed(0)}%，${best.systolic}/${best.diastolic}${best.pulse == null ? '' : '/${best.pulse}'}，$lcdSummary），是否用大模型复核？',
        confirmText: '用大模型识别',
      );
      if (useAi && context.mounted) {
        await _runAiRecognize(context, imagePath);
      }
      return;
    }
    if (best == null) {
      if (!context.mounted) return;
      final manual = await _chooseFallback(
        context,
        title: '未能识别出血压数值',
        message: '请尝试光线充足、无反光的角度重新拍摄，或手动录入。\n$lcdSummary',
        allowAi: false,
      );
      if (manual == _Fallback.manual && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const RecordEditPage(),
          fullscreenDialog: true,
        ));
      } else if (manual == _Fallback.retake && context.mounted) {
        await startCamera(context);
      }
      return;
    }
    // 低置信度但存在候选 → 直接进入确认表单（用户会人工核对）
    if (context.mounted) {
      await _openConfirm(context, imagePath, best, source: RecordSource.ocr);
    }
  }

  static Future<void> _runAiRecognize(
      BuildContext context, String imagePath) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final profile = container.read(activeLlmProfileProvider);
    if (profile == null || !profile.supportsVision) {
      if (context.mounted) {
        OcrFlow.showErrorDialog(context, '未配置多模态模型',
            '请先在"AI 模型"设置中配置支持图片输入的远端模型。');
      }
      return;
    }
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
                Text('AI 识别中…'),
              ],
            ),
          ),
        ),
      ),
    );
    BpCandidate? candidate;
    String? error;
    try {
      final jpeg = await ImageUtils.compressForAi(imagePath);
      candidate = await extractBpFromImage(jpegBytes: jpeg, profile: profile);
    } catch (e) {
      error = e is InferenceException ? e.message : '$e';
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (error != null) {
      if (context.mounted) showErrorDialog(context, 'AI 识别失败', error);
      return;
    }
    if (candidate == null) {
      if (context.mounted) {
        showErrorDialog(context, 'AI 未能识别',
            '大模型未能从照片中提取血压数值，请尝试更清晰的照片或手动录入。');
      }
      return;
    }
    if (context.mounted) {
      await _openConfirm(context, imagePath, candidate,
          source: RecordSource.ai);
    }
  }

  static Future<void> _openConfirm(
    BuildContext context,
    String imagePath,
    BpCandidate best, {
    required RecordSource source,
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
        initialSystolic: best.systolic,
        initialDiastolic: best.diastolic,
        initialPulse: best.pulse,
        initialSource: source,
        initialPhotoPath: persisted,
        initialConfidence: best.confidence,
      ),
    ));
  }

  static bool _hasVisionLlm(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final profile = container.read(activeLlmProfileProvider);
    return profile?.supportsVision ?? false;
  }

  static Future<_Fallback> _chooseFallback(
    BuildContext context, {
    required String title,
    required String message,
    required bool allowAi,
  }) async {
    final result = await showDialog<_Fallback>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (allowAi)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_Fallback.ai),
              child: const Text('用大模型识别'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_Fallback.retake),
            child: const Text('重新拍摄'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_Fallback.manual),
            child: const Text('手动录入'),
          ),
        ],
      ),
    );
    return result ?? _Fallback.manual;
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

enum _Fallback { manual, retake, ai }

/// 快捷入口（供其他页面调用）。
void startCameraOcrFlow(BuildContext context) =>
    OcrFlow.startCamera(context);

void startGalleryOcrFlow(BuildContext context) =>
    OcrFlow.startGallery(context);

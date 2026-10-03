import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/vision_extract.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/features/camera_ocr/data/image_utils.dart';
import 'package:blood_pressed/features/camera_ocr/domain/ocr_parser.dart';
import 'package:blood_pressed/features/camera_ocr/data/ocr_service.dart';
import 'camera_capture_page.dart';
import '../../../core/widgets/common_widgets.dart' show showConfirmDialog;

/// OCR 识别总流程（拍照 / 相册 → ML Kit → 解析 → 确认表单；低置信度走大模型兜底）。
class OcrFlow {
  OcrFlow._();

  /// 从相机拍照开始。
  static Future<void> startCamera(BuildContext context) async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => const CameraCapturePage(), fullscreenDialog: true),
    );
    if (path == null || !context.mounted) return;
    await _runPipeline(context, path);
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
    try {
      final service = OcrService();
      result = await service.recognize(imagePath);
    } catch (e) {
      errorMsg = '$e';
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 关掉加载框

    if (errorMsg != null) {
      if (context.mounted) {
        showErrorDialog(context, '识别失败', errorMsg);
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
    await _onLowConfidence(context, imagePath, result);
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

  static Future<void> _onLowConfidence(
      BuildContext context, String imagePath, OcrParseResult result) async {
    final canUseAi = _hasVisionLlm(context);
    final best = result.best;
    if (canUseAi) {
      final useAi = await showConfirmDialog(
        context,
        title: '识别结果不确定',
        content: best == null
            ? '未能从照片中识别出血压数值。是否用已配置的大模型重新识别？'
            : '识别置信度较低（${(best.confidence * 100).toStringAsFixed(0)}%），是否用大模型复核？',
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
        message: '请尝试光线充足、无反光的角度重新拍摄，或手动录入。',
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

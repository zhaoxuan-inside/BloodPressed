import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:blood_pressed/features/export/presentation/share_card_widgets.dart';

/// 将任意分享卡渲染为 PNG 字节：以透明 dialog 临时承载卡片（RepaintBoundary
/// 只有在树上真实渲染才能截图，chg-013 验证过的机制），首帧后立即捕获并
/// 关闭。失败（含用户无感知的渲染异常）返回 null。
Future<Uint8List?> captureCard(BuildContext context, Widget card) {
  final completer = Completer<Uint8List?>();
  showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _AutoCapture(card: card, completer: completer),
  );
  return completer.future;
}

class _AutoCapture extends StatefulWidget {
  const _AutoCapture({required this.card, required this.completer});

  final Widget card;
  final Completer<Uint8List?> completer;

  @override
  State<_AutoCapture> createState() => _AutoCaptureState();
}

class _AutoCaptureState extends State<_AutoCapture> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Uint8List? bytes;
      try {
        bytes = await CardCapturer.capture(_key);
      } catch (_) {
        bytes = null;
      }
      if (mounted) Navigator.of(context).pop();
      if (!widget.completer.isCompleted) {
        widget.completer.complete(bytes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 透明遮罩中只露卡片本体；Material 保证文本/图标按主题渲染
    return Center(
      child: RepaintBoundary(
        key: _key,
        child: widget.card,
      ),
    );
  }
}

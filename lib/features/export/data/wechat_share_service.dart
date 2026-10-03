import 'dart:io';

import 'package:fluwx/fluwx.dart';
import 'package:share_plus/share_plus.dart';

/// 分享服务：微信（fluwx）优先，未配置 AppID 或未安装微信时回退系统分享。
class ShareService {
  ShareService({required this.wechatAppId, required this.universalLink});

  final String wechatAppId;
  final String universalLink;

  final Fluwx _fluwx = Fluwx();

  bool get _wechatConfigured =>
      wechatAppId.isNotEmpty && wechatAppId != 'wxYOUR_WECHAT_APPID';

  /// 尝试注册微信 API（App 启动时调用一次；未配置时静默跳过）。
  Future<void> registerWeChat() async {
    if (!_wechatConfigured) return;
    try {
      // iOS 必须提供 Universal Link；未配置时不注册 iOS 端
      await _fluwx.registerApi(
        appId: wechatAppId,
        doOnIOS: universalLink.startsWith('https'),
        doOnAndroid: true,
        universalLink:
            universalLink.startsWith('https') ? universalLink : null,
      );
    } catch (_) {
      // 注册失败不影响应用其余功能
    }
  }

  Future<bool> isWeChatAvailable() async {
    if (!_wechatConfigured) return false;
    try {
      return await _fluwx.isWeChatInstalled;
    } catch (_) {
      return false;
    }
  }

  /// 分享图片文件：微信可用时分享到会话/朋友圈，否则回退系统分享面板。
  ///
  /// 返回实际使用的通道描述（用于提示）。
  Future<String> shareImage(
    File image, {
    String? text,
    bool toTimeline = false,
  }) async {
    if (await isWeChatAvailable()) {
      final bytes = await image.readAsBytes();
      final model = WeChatShareImageModel(
        WeChatImageToShare(uint8List: bytes),
        title: text,
        description: text,
        scene: toTimeline ? WeChatScene.timeline : WeChatScene.session,
      );
      final ok = await _fluwx.share(model);
      return ok ? '已通过微信分享' : '微信分享未完成';
    }
    return shareFile(image, text: text);
  }

  /// 系统分享文件。
  Future<String> shareFile(File file, {String? text}) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
      ),
    );
    return result.status == ShareResultStatus.success
        ? '已分享'
        : '分享已取消';
  }

  /// 分享文本。
  Future<String> shareText(String text) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text),
    );
    return result.status == ShareResultStatus.success
        ? '已分享'
        : '分享已取消';
  }
}

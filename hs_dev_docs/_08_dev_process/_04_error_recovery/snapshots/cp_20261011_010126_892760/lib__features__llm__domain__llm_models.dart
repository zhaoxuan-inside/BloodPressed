/// 大模型相关领域模型：配置档案、对话消息。
library;

enum LlmKind { local, remote }

/// 一个可用的模型配置。
///
/// * [LlmKind.local]：config 含 {modelPath, contextSize, threads}
/// * [LlmKind.remote]：config 含 {baseUrl, apiKey, model, multimodal(bool)}
class LlmProfile {
  const LlmProfile({
    required this.id,
    required this.kind,
    required this.name,
    required this.config,
  });

  final String id;
  final LlmKind kind;
  final String name;
  final Map<String, Object?> config;

  // ---- 便捷读取 ----
  String get modelPath => config['modelPath'] as String? ?? '';
  int get contextSize => (config['contextSize'] as num?)?.toInt() ?? 2048;
  int get threads => (config['threads'] as num?)?.toInt() ?? 0;

  String get baseUrl => _trimSlash(config['baseUrl'] as String? ?? '');
  String get apiKey => config['apiKey'] as String? ?? '';
  String get remoteModel => config['model'] as String? ?? '';
  bool get multimodal => config['multimodal'] == true;

  LlmProfile copyWithConfig(Map<String, Object?> overrides) => LlmProfile(
        id: id,
        kind: kind,
        name: name,
        config: {...config, ...overrides},
      );

  /// 是否可直接用于对话（本地：文件已下载；远端：必填项齐全）。
  bool get usable {
    switch (kind) {
      case LlmKind.local:
        return modelPath.isNotEmpty;
      case LlmKind.remote:
        return baseUrl.isNotEmpty && remoteModel.isNotEmpty;
    }
  }

  /// 远端配置是否支持图片输入（多模态识别兜底）。
  bool get supportsVision => kind == LlmKind.remote && multimodal;

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

/// 统一的对话消息（本地/远端引擎共用）。
enum ChatRole { system, user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage copyWith({String? content}) => ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static ChatMessage fromMap(Map<String, Object?> map) => ChatMessage(
        id: map['id'] as String,
        role: ChatRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => ChatRole.assistant,
        ),
        content: (map['content'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['created_at'] as int?) ?? 0),
      );
}

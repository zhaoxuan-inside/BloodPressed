import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';

import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';
import 'package:blood_pressed/features/assistant/domain/gated_answer.dart';

class ChatUiState {
  const ChatUiState({
    this.messages = const [],
    this.sending = false,
    this.streamingContent,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool sending;

  /// 正在流式生成的回复内容（尚未入库）。
  final String? streamingContent;
  final String? error;

  ChatUiState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? streamingContent,
    bool clearStreaming = false,
    String? error,
    bool clearError = false,
  }) =>
      ChatUiState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        streamingContent:
            clearStreaming ? null : (streamingContent ?? this.streamingContent),
        error: clearError ? null : (error ?? this.error),
      );
}

/// 控制器对 Provider 容器的最小依赖：只读。
typedef AssistantRefReader = T Function<T>(ProviderListenable<T> listenable);

class AssistantController extends StateNotifier<ChatUiState> {
  /// [_gatedChatOverride] 仅测试注入：门槛路径的 JSON 问答出口。
  AssistantController(
    this._chatRepo,
    this._contextBuilder,
    this._read, {
    Future<Map<String, Object?>> Function(
            List<ChatMessage> messages, int maxTokens)?
        gatedChatOverride,
  })  : _gatedChatOverride = gatedChatOverride, // ignore: prefer_initializing_formals
        super(const ChatUiState()) {
    _load();
  }

  final ChatRepository _chatRepo;
  final HealthContextBuilder _contextBuilder;
  final AssistantRefReader _read;
  final Future<Map<String, Object?>> Function(
          List<ChatMessage> messages, int maxTokens)?
      _gatedChatOverride;
  StreamSubscription<String>? _sub;

  /// 门槛问答的会话序号：stopStreaming 自增作废在途请求。
  int _gatedSeq = 0;

  Future<void> _load() async {
    final history = await _chatRepo.history();
    state = state.copyWith(messages: history);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final engineController = _read(llmEngineProvider.notifier);
    final err = await engineController.ensureReady();
    if (err != null) {
      state = state.copyWith(error: err);
      return;
    }

    state = state.copyWith(error: null, clearError: true, sending: true);

    final userMsg = await _chatRepo.append(ChatRole.user, trimmed);
    final systemPrompt = await _contextBuilder.buildSystemPrompt();

    final messages = <ChatMessage>[
      ChatMessage(
        id: 'system',
        role: ChatRole.system,
        content: systemPrompt,
        createdAt: DateTime.now(),
      ),
      ...state.messages,
      userMsg,
    ];

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      clearStreaming: true,
    );

    // 内置默认模型 → 90 分置信度门槛路径（非流式 JSON 问答）；
    // 用户自配模型 → 现有流式路径（零门槛）。
    if (_read(isBuiltinActiveProvider)) {
      // 空流式占位：UI 显示"思考中"气泡
      state = state.copyWith(streamingContent: '');
      await _sendGated(systemPrompt: systemPrompt);
      return;
    }

    final buffer = StringBuffer();
    try {
      final stream = engineController.chatStream(messages);
      _sub = stream.listen(
        (chunk) {
          buffer.write(chunk);
          state = state.copyWith(streamingContent: buffer.toString());
        },
        onDone: () async {
          final reply =
              await _chatRepo.append(ChatRole.assistant, buffer.toString());
          state = ChatUiState(messages: [...state.messages, reply]);
        },
        onError: (Object e) async {
          final partial = buffer.toString();
          String errMsg;
          if (partial.isNotEmpty) {
            await _chatRepo.append(ChatRole.assistant, partial);
            errMsg = AppLocaleService.auto.replyInterrupted(e.toString());
          } else {
            errMsg = e.toString();
          }
          state = ChatUiState(
            messages: state.messages,
            error: errMsg,
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      state = state.copyWith(
        sending: false,
        error: '$e',
      );
    }
  }

  void stopStreaming() {
    _sub?.cancel();
    _gatedSeq++; // 作废在途的门槛问答（结果不再入库）
    final partial = state.streamingContent;
    if (partial != null && partial.isNotEmpty) {
      _chatRepo
          .append(ChatRole.assistant, partial)
          .then((msg) {
        state = ChatUiState(messages: [...state.messages, msg]);
      });
    } else {
      state = state.copyWith(sending: false, clearStreaming: true);
    }
  }

  /// 门槛路径：grammar 约束 JSON 问答 + 90 分置信度硬门槛。
  ///
  /// 历史 [kGatedHistoryLimit] 条 + 健康上下文 + maxTokens 512 适配
  /// 内置档案 contextSize=2048。置信度不足或解析失败一律以拒答文案
  /// 入库——宁可说不知道，不给不可靠的健康建议。
  Future<void> _sendGated({required String systemPrompt}) async {
    final seq = ++_gatedSeq;
    final history = state.messages;
    final trimmedHistory = history.length > kGatedHistoryLimit
        ? history.sublist(history.length - kGatedHistoryLimit)
        : history;
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'system',
        role: ChatRole.system,
        content: '$systemPrompt\n\n$gatedAnswerInstruction',
        createdAt: DateTime.now(),
      ),
      ...trimmedHistory,
    ];
    try {
      final json = _gatedChatOverride != null
          ? await _gatedChatOverride(messages, 512)
          : await _read(llmEngineProvider.notifier)
              .chatJson(messages, schema: gatedAnswerSchema, maxTokens: 512);
      if (seq != _gatedSeq) return; // 已被 stopStreaming 作废
      final parsed = parseGatedAnswer(json);
      final text = parsed != null && parsed.isReliable
          ? parsed.answer
          : AppLocaleService.auto.gatedRefusal;
      final reply = await _chatRepo.append(ChatRole.assistant, text);
      state = ChatUiState(messages: [...state.messages, reply]);
    } catch (e) {
      if (seq != _gatedSeq) return;
      state = state.copyWith(sending: false, error: '$e', clearStreaming: true);
    }
  }

  Future<void> clearConversation() async {
    await _sub?.cancel();
    await _chatRepo.clear();
    state = const ChatUiState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final assistantProvider =
    StateNotifierProvider<AssistantController, ChatUiState>((ref) {
  throw UnimplementedError('需在 main() 中覆盖');
});

/// 待自动发送的分析请求：其它页面（如趋势页「AI 分析」）写入后跳转
/// 助手页，助手页 initState 消费并清空。模型不可用时由 send() 的
/// ensureReady 错误兜底。
final pendingAssistantPromptProvider = StateProvider<String?>((ref) => null);

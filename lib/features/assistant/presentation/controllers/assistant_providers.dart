import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';

import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/assistant/data/chat_repository.dart';
import 'package:blood_pressed/features/assistant/data/health_context_builder.dart';

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

class AssistantController extends StateNotifier<ChatUiState> {
  AssistantController(this._chatRepo, this._contextBuilder, this._engineRef)
      : super(const ChatUiState()) {
    _load();
  }

  final ChatRepository _chatRepo;
  final HealthContextBuilder _contextBuilder;
  final Ref _engineRef;
  StreamSubscription<String>? _sub;

  Future<void> _load() async {
    final history = await _chatRepo.history();
    state = state.copyWith(messages: history);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final engineController = _engineRef.read(llmEngineProvider.notifier);
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

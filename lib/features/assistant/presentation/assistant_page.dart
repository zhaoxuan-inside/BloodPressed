import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/assistant/presentation/controllers/assistant_providers.dart';

/// AI 健康指导聊天页。
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text;
    _inputCtrl.clear();
    await ref.read(assistantProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(assistantProvider);
    final activeProfile = ref.watch(activeLlmProfileProvider);
    final engineState = ref.watch(llmEngineProvider);

    final hasModel = activeProfile != null &&
        (engineState.status == LlmEngineStatus.ready ||
            engineState.status == LlmEngineStatus.idle ||
            engineState.status == LlmEngineStatus.loading);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('健康指导'),
            if (activeProfile != null)
              Text(
                '模型：${activeProfile.name}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: '清空对话',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: '清空对话',
                  content: '确定删除全部对话记录吗？',
                  danger: true,
                  confirmText: '清空',
                );
                if (ok) {
                  await ref.read(assistantProvider.notifier).clearConversation();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !hasModel
                ? _NoModelHint(onConfigure: () => context.push('/llm'))
                : state.messages.isEmpty && state.streamingContent == null
                    ? _Welcome(onSuggest: (s) {
                        _inputCtrl.text = s;
                      })
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: state.messages.length +
                            (state.streamingContent != null ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < state.messages.length) {
                            final m = state.messages[i];
                            if (m.role == ChatRole.system) {
                              return const SizedBox.shrink();
                            }
                            return _Bubble(
                              isUser: m.role == ChatRole.user,
                              text: m.content,
                            );
                          }
                          return _Bubble(
                            isUser: false,
                            text: state.streamingContent ?? '',
                            streaming: true,
                          );
                        },
                      ),
          ),
          if (state.error != null)
            ErrorBanner(state.error!),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: hasModel
                            ? '例如：我最近血压偏高，饮食上要注意什么？'
                            : '请先配置模型',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.sending)
                    IconButton.filled(
                      onPressed: () =>
                          ref.read(assistantProvider.notifier).stopStreaming(),
                      icon: const Icon(Icons.stop),
                    )
                  else
                    IconButton.filled(
                      onPressed: hasModel ? _send : null,
                      icon: const Icon(Icons.send),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'AI 建议仅供参考，不能替代专业医疗意见',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isUser,
    required this.text,
    this.streaming = false,
  });

  final bool isUser;
  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Text(
          text.isEmpty && streaming ? '…' : text,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
    );
  }
}

class _NoModelHint extends StatelessWidget {
  const _NoModelHint({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('尚未配置 AI 模型', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '配置本地模型（离线可用）或远端 API 后，\n即可获得个性化血压健康指导。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('去配置模型'),
              onPressed: onConfigure,
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  static const _suggestions = [
    '帮我分析一下最近的血压情况',
    '血压偏高，饮食上应该注意什么？',
    '如何正确测量血压？',
    '运动对降压有帮助吗？怎么运动？',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Text('👋 你好，我是你的血压健康助手',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '我会结合你近 30 天的血压记录给出建议。\n你可以这样问我：',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
        ),
        const SizedBox(height: 16),
        ..._suggestions.map((s) => Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.chat_bubble_outline, size: 18),
                title: Text(s, style: theme.textTheme.bodyMedium),
                onTap: () => onSuggest(s),
              ),
            )),
      ],
    );
  }
}

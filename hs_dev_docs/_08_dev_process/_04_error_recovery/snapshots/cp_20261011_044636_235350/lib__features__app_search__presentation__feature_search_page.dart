import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/app_search/domain/feature_registry.dart';
import 'package:blood_pressed/features/app_search/domain/feature_search_service.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 功能搜索页：确定性匹配实时过滤；无结果且模型就绪时语义匹配兜底。
class FeatureSearchPage extends ConsumerStatefulWidget {
  const FeatureSearchPage({super.key});

  @override
  ConsumerState<FeatureSearchPage> createState() => _FeatureSearchPageState();
}

class _FeatureSearchPageState extends ConsumerState<FeatureSearchPage> {
  final FeatureSearchService _service = FeatureSearchService();
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<AppFeatureEntry>? _results;
  bool _smartMatching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _results = _service.match(value);
        _smartMatching = false;
      });
      if ((_results ?? const []).isEmpty && value.trim().isNotEmpty) {
        _smartFallback(value);
      }
    });
  }

  /// 语义匹配兜底：模型就绪时用本地引擎做相关性判断。
  Future<void> _smartFallback(String query) async {
    final engine = ref.read(llmEngineProvider.notifier);
    if (!ref.read(builtinModelReadyProvider) &&
        ref.read(activeLlmProfileProvider) == null) {
      return; // 模型不可用：保持确定性层的"无结果"
    }
    setState(() => _smartMatching = true);
    List<AppFeatureEntry> smart = const [];
    try {
      await engine.ensureReady();
      smart = await _service.semanticMatch(
        query,
        chatJson: (messages, maxTokens) =>
            engine.chatJson(messages, schema: _searchSchema, maxTokens: maxTokens),
      );
    } catch (_) {
      // 模型异常：静默保持无结果
    }
    if (!mounted) return;
    // 用户已继续输入（查询已变）则丢弃过期结果
    if (_ctrl.text.trim() == query.trim()) {
      setState(() {
        _smartMatching = false;
        if (smart.isNotEmpty && (_results ?? const []).isEmpty) {
          _results = smart;
        }
      });
    }
  }

  static const _searchSchema = {
    'type': 'object',
    'properties': {
      'matches': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'score': {'type': 'integer'},
          },
          'required': ['id', 'score'],
        },
      },
    },
    'required': ['matches'],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _results ?? const [];
    final hasQuery = _ctrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _smartMatching
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l10n.searchSmartMatching,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: hasQuery
                            ? l10n.searchNoResults
                            : l10n.searchTitle,
                        subtitle:
                            hasQuery ? null : l10n.searchHint,
                      )
                    : ListView(
                        children: [
                          for (final entry in results)
                            ListTile(
                              leading: Icon(entry.icon),
                              title: Text(entry.title(l10n)),
                              trailing:
                                  const Icon(Icons.chevron_right),
                              // Tab 分支目的地 go 切换；根导航页 push 叠加
                              onTap: () => entry.rootNavigator
                                  ? context.push(entry.route)
                                  : context.go(entry.route),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

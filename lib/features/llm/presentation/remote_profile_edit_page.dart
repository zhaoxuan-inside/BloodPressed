import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/llm/data/remote_chat_engine.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 常用远端 API 预设（name/desc 的展示文案经 l10n 按 [id] 映射）。
class _RemotePreset {
  const _RemotePreset(this.id, this.name, this.baseUrl, this.modelHint,
      this.desc,
      {this.clearModelOnSelect = false});

  final String id;
  final String name;
  final String baseUrl;
  final String modelHint;
  final String desc;

  /// 选中该预设时是否清空模型名（预设给出的只是示例而非可用模型名）。
  final bool clearModelOnSelect;
}

const _presets = [
  _RemotePreset(
    'modelscope',
    'ModelScope API-Inference（魔搭）',
    'https://api-inference.modelscope.cn/v1',
    '如 Qwen/Qwen3-32B',
    '魔搭社区提供的免费推理 API，需在魔搭官网获取 Token',
    clearModelOnSelect: true,
  ),
  _RemotePreset(
    'ark',
    '火山方舟 Ark',
    'https://ark.cn-beijing.volces.com/api/v3',
    '如 doubao-seed-1-6 或推理接入点 ep-xxxxxxxx',
    '字节跳动火山引擎；API Key 在方舟控制台「API Key 管理」获取',
  ),
  _RemotePreset(
    'dashscope',
    '阿里云百炼 DashScope',
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    '如 qwen-plus、qwen-vl-plus（多模态）',
    '阿里云百炼 OpenAI 兼容模式',
  ),
  _RemotePreset(
    'deepseek',
    'DeepSeek',
    'https://api.deepseek.com/v1',
    '如 deepseek-chat',
    'DeepSeek 官方 API',
    clearModelOnSelect: true,
  ),
  _RemotePreset(
    'openai',
    'OpenAI',
    'https://api.openai.com/v1',
    '如 gpt-4o-mini（多模态）',
    'OpenAI 官方 API（国内访问需自行解决网络）',
  ),
  _RemotePreset(
    'ollama',
    'Ollama（本地/局域网）',
    'http://127.0.0.1:11434/v1',
    '如 qwen2.5:3b',
    '电脑上运行 Ollama 并开放端口，手机与电脑同一局域网',
  ),
];

/// 远端模型配置编辑页。
class RemoteProfileEditPage extends ConsumerStatefulWidget {
  const RemoteProfileEditPage({super.key, this.existing});

  final LlmProfile? existing;

  @override
  ConsumerState<RemoteProfileEditPage> createState() =>
      _RemoteProfileEditPageState();
}

class _RemoteProfileEditPageState
    extends ConsumerState<RemoteProfileEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  late bool _multimodal;
  String? _preset;
  bool _fetchingModels = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _baseUrlCtrl = TextEditingController(text: e?.baseUrl ?? '');
    _apiKeyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _modelCtrl = TextEditingController(text: e?.remoteModel ?? '');
    _multimodal = e?.multimodal ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(_RemotePreset p) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _preset = p.name;
      _baseUrlCtrl.text = p.baseUrl;
      final displayName = _presetName(l10n, p.id);
      _nameCtrl.text =
          _nameCtrl.text.isEmpty ? displayName : _nameCtrl.text;
      _modelCtrl.text =
          p.clearModelOnSelect ? '' : _modelCtrl.text;
      _multimodal = p.baseUrl.contains('dashscope') && p.modelHint.contains('vl');
    });
  }

  String _presetName(AppLocalizations l10n, String id) => switch (id) {
        'modelscope' => l10n.presetNameModelscope,
        'ark' => l10n.presetNameArk,
        'dashscope' => l10n.presetNameDashScope,
        'deepseek' => l10n.presetNameDeepSeek,
        'openai' => l10n.presetNameOpenAI,
        'ollama' => l10n.presetNameOllama,
        _ => id,
      };

  String _presetDesc(AppLocalizations l10n, String id) => switch (id) {
        'modelscope' => l10n.presetDescModelscope,
        'ark' => l10n.presetDescArk,
        'dashscope' => l10n.presetDescDashScope,
        'deepseek' => l10n.presetDescDeepSeek,
        'openai' => l10n.presetDescOpenAI,
        'ollama' => l10n.presetDescOllama,
        _ => '',
      };

  /// 拉取远端可用模型列表，弹出选择器；选中后填入 model 字段。
  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).needBaseUrl)));
      return;
    }
    setState(() => _fetchingModels = true);
    final engine = RemoteChatEngine(LlmProfile(
      id: 'tmp',
      kind: LlmKind.remote,
      name: 'tmp',
      config: {
        'baseUrl': baseUrl,
        'apiKey': _apiKeyCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
      },
    ));
    try {
      final models = await engine.listModels();
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => _ModelPickerSheet(models: models),
      );
      if (picked != null) {
        setState(() => _modelCtrl.text = picked);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is InferenceException
          ? e.message
          : AppLocalizations.of(context).fetchFailed(e.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
    } finally {
      engine.dispose();
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (name.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).needAllFields)));
      return;
    }
    final controller = ref.read(llmProfilesProvider.notifier);
    if (_isEditing) {
      await controller.updateRemote(
        widget.existing!,
        name: name,
        baseUrl: baseUrl,
        apiKey: _apiKeyCtrl.text.trim(),
        model: model,
        multimodal: _multimodal,
      );
    } else {
      final profile = await controller.addRemote(
        name: name,
        baseUrl: baseUrl,
        apiKey: _apiKeyCtrl.text.trim(),
        model: model,
        multimodal: _multimodal,
      );
      // 新建的远端配置自动激活
      final err = await ref.read(llmEngineProvider.notifier).activate(profile);
      if (err == null && mounted) {
        ref.read(activeLlmProfileIdProvider.notifier).state = profile.id;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? l10n.remoteEditTitle : l10n.remoteAddTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.presetSectionTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets
                .map((p) => ChoiceChip(
                      label: Text(_presetName(l10n, p.id)),
                      selected: _preset == p.name,
                      onSelected: (_) => _applyPreset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _presetDesc(
                l10n,
                _presets
                    .firstWhere((p) => p.name == _preset,
                        orElse: () => const _RemotePreset('', '', '', '', ''))
                    .id),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
                labelText: l10n.fieldName, hintText: l10n.nameHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.fieldBaseUrl,
              hintText: 'https://api.example.com/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.fieldApiKey,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: InputDecoration(
              labelText: l10n.fieldModel,
              hintText: l10n.modelHint,
              suffixIcon: _fetchingModels
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: l10n.fetchModelsTooltip,
                      icon: const Icon(Icons.cloud_download_outlined),
                      onPressed: _fetchModels,
                    ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.multimodalTitle),
            subtitle: Text(l10n.multimodalSubtitle),
            value: _multimodal,
            onChanged: (v) => setState(() => _multimodal = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? l10n.saveBtn : l10n.addActivateBtn),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}


/// 模型选择底部弹层：支持关键字过滤。
class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({required this.models});

  final List<String> models;

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _query.isEmpty
        ? widget.models
        : widget.models
            .where((m) => m.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchModels(widget.models.length),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.noMatchModels))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => ListTile(
                        dense: true,
                        title: Text(filtered[i],
                            style: const TextStyle(fontSize: 13)),
                        onTap: () => Navigator.of(ctx).pop(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

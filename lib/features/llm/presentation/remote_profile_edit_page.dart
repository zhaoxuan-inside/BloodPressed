import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/llm/data/remote_chat_engine.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';

/// 常用远端 API 预设。
class _RemotePreset {
  const _RemotePreset(this.name, this.baseUrl, this.modelHint, this.desc);

  final String name;
  final String baseUrl;
  final String modelHint;
  final String desc;
}

const _presets = [
  _RemotePreset(
    'ModelScope API-Inference（魔搭）',
    'https://api-inference.modelscope.cn/v1',
    '如 Qwen/Qwen3-32B',
    '魔搭社区提供的免费推理 API，需在魔搭官网获取 Token',
  ),
  _RemotePreset(
    '火山方舟 Ark',
    'https://ark.cn-beijing.volces.com/api/v3',
    '如 doubao-seed-1-6 或推理接入点 ep-xxxxxxxx',
    '字节跳动火山引擎；API Key 在方舟控制台「API Key 管理」获取',
  ),
  _RemotePreset(
    '阿里云百炼 DashScope',
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    '如 qwen-plus、qwen-vl-plus（多模态）',
    '阿里云百炼 OpenAI 兼容模式',
  ),
  _RemotePreset(
    'DeepSeek',
    'https://api.deepseek.com/v1',
    '如 deepseek-chat',
    'DeepSeek 官方 API',
  ),
  _RemotePreset(
    'OpenAI',
    'https://api.openai.com/v1',
    '如 gpt-4o-mini（多模态）',
    'OpenAI 官方 API（国内访问需自行解决网络）',
  ),
  _RemotePreset(
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
    setState(() {
      _preset = p.name;
      _baseUrlCtrl.text = p.baseUrl;
      _nameCtrl.text = _nameCtrl.text.isEmpty ? p.name : _nameCtrl.text;
      _modelCtrl.text = p.modelHint.startsWith('如')
          ? ''
          : _modelCtrl.text;
      _multimodal = p.baseUrl.contains('dashscope') && p.modelHint.contains('vl');
    });
  }

  /// 拉取远端可用模型列表，弹出选择器；选中后填入 model 字段。
  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先填写 API 地址（baseUrl）')));
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
      final msg = e is InferenceException ? e.message : '获取失败：$e';
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
          const SnackBar(content: Text('请填写名称、服务地址和模型名称')));
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑远端模型' : '添加远端模型')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('选择服务预设（可选）', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets
                .map((p) => ChoiceChip(
                      label: Text(p.name),
                      selected: _preset == p.name,
                      onSelected: (_) => _applyPreset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _presets.firstWhere((p) => p.name == _preset,
                    orElse: () => const _RemotePreset('', '', '', ''))
                .desc,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: '名称', hintText: '如：魔搭 Qwen / DeepSeek'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API 地址（baseUrl，无需以 / 结尾）',
              hintText: 'https://api.example.com/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key（部分服务可留空）',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: InputDecoration(
              labelText: '模型名称（model）',
              hintText: '如 Qwen/Qwen3-32B 或 deepseek-chat',
              suffixIcon: _fetchingModels
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: '获取模型列表',
                      icon: const Icon(Icons.cloud_download_outlined),
                      onPressed: _fetchModels,
                    ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('支持图片输入（多模态）'),
            subtitle: const Text('开启后可用该模型识别血压计照片（OCR 兜底）'),
            value: _multimodal,
            onChanged: (v) => setState(() => _multimodal = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? '保存' : '添加并启用'),
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
                  hintText: '搜索模型（共 ${widget.models.length} 个）',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('无匹配模型'))
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

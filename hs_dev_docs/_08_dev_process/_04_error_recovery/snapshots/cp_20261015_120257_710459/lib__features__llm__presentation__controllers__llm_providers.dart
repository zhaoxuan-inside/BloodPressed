import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:uuid/uuid.dart';

import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/llm/data/huggingface_client.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/data/model_center_service.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
import 'package:blood_pressed/features/llm/domain/builtin_model.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';
import 'package:blood_pressed/features/llm/data/local_chat_engine.dart';
import 'package:blood_pressed/features/llm/data/remote_chat_engine.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

// ---------------- 配置档案 ----------------

class LlmProfilesController
    extends StateNotifier<AsyncValue<List<LlmProfile>>> {
  LlmProfilesController(this._store, this._settings)
      : super(const AsyncLoading()) {
    refresh();
  }

  final LlmProfileStore _store;
  final AppSettings _settings;

  Future<void> refresh() async {
    try {
      state = AsyncData(await _store.list());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<LlmProfile> addRemote({
    required String name,
    required String baseUrl,
    required String apiKey,
    required String model,
    required bool multimodal,
  }) async {
    final profile = LlmProfile(
      id: const Uuid().v4(),
      kind: LlmKind.remote,
      name: name,
      config: {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'multimodal': multimodal,
      },
    );
    await _store.upsert(profile);
    await refresh();
    return profile;
  }

  Future<LlmProfile> addLocalModel({
    required String name,
    required String modelPath,
    int contextSize = 2048,
  }) async {
    final profile = LlmProfile(
      id: const Uuid().v4(),
      kind: LlmKind.local,
      name: name,
      config: {
        'modelPath': modelPath,
        'contextSize': contextSize,
        'threads': 0,
      },
    );
    await _store.upsert(profile);
    await refresh();
    return profile;
  }

  Future<void> updateLocalParams(LlmProfile profile, int contextSize) async {
    await _store
        .upsert(profile.copyWithConfig({'contextSize': contextSize}));
    await refresh();
  }

  Future<void> updateRemote(
    LlmProfile profile, {
    required String name,
    required String baseUrl,
    required String apiKey,
    required String model,
    required bool multimodal,
  }) async {
    await _store.upsert(LlmProfile(
      id: profile.id,
      kind: LlmKind.remote,
      name: name,
      config: profile.copyWithConfig({
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'multimodal': multimodal,
      }).config,
    ));
    await refresh();
  }

  /// 为已下载的模型文件幂等建档（模型中心「安装」语义）：
  /// 同一 modelPath 只建一份档案；返回是否新建。
  Future<bool> ensureLocalProfileForFile(
    String modelPath,
    String name,
  ) async {
    final existing = await _store.list();
    if (existing.any((p) => p.modelPath == modelPath)) return false;
    await addLocalModel(name: name, modelPath: modelPath);
    return true;
  }

  Future<void> delete(String id) async {
    if (_settings.activeLlmProfileId == id) {
      await _settings.setActiveLlmProfile(null);
    }
    await _store.delete(id);
    await refresh();
  }
}

final llmProfilesProvider =
    StateNotifierProvider<LlmProfilesController, AsyncValue<List<LlmProfile>>>(
        (ref) {
  throw UnimplementedError('需在 main() 中覆盖');
});

/// 当前激活的 LLM 档案 id（与 AppSettings 双写保持一致）。
final activeLlmProfileIdProvider = StateProvider<String?>((ref) => null);

/// 当前激活的档案实体（null = 未配置）。
final activeLlmProfileProvider = Provider<LlmProfile?>((ref) {
  final id = ref.watch(activeLlmProfileIdProvider);
  final profiles = ref.watch(llmProfilesProvider).valueOrNull ?? const [];
  for (final p in profiles) {
    if (p.id == id) return p;
  }
  return null;
});

// ---------------- 内置默认模型（Qwen3-1.7B） ----------------

/// 内置模型权重文件路径（main() 启动时播种，始终非空——下载引导需要目标路径）。
final builtinModelPathProvider = StateProvider<String>((ref) => '');

/// 内置模型文件是否已就绪（启动时按文件存在性播种；下载完成后置 true）。
final builtinModelReadyProvider = StateProvider<bool>((ref) => false);

/// 内置默认档案（virtual，不落库）。路径就绪即返回。
final builtinLlmProfileProvider = Provider<LlmProfile?>((ref) {
  final path = ref.watch(builtinModelPathProvider);
  if (path.isEmpty) return null;
  return builtinProfile(path);
});

/// 实际生效的档案：用户激活档案优先；未配置时回落内置默认（已就绪才可用）。
final effectiveLlmProfileProvider = Provider<LlmProfile?>((ref) {
  final user = ref.watch(activeLlmProfileProvider);
  if (user != null) return user;
  if (!ref.watch(builtinModelReadyProvider)) return null;
  return ref.watch(builtinLlmProfileProvider);
});

/// 当前生效的是否为内置默认模型（决定问答是否走 90 分置信度门槛）。
final isBuiltinActiveProvider = Provider<bool>((ref) {
  final p = ref.watch(effectiveLlmProfileProvider);
  return p != null && isBuiltinProfile(p);
});

/// 激活引擎并把激活 id 双写（内存 Provider + 持久化存储）。
///
/// 所有「启用某档案」的入口（设置页 / 远端编辑页 / 内置模型下载完成）
/// 必须走本函数：激活 id 若只写内存，重启后会回落到旧的持久化值
/// （曾因此丢失远端配置的激活态）。[setActiveId] 由调用方注入，
/// 用于在 WidgetRef 场景更新 StateProvider。
/// 返回引擎激活错误信息；null 表示成功且已持久化。
Future<String?> activateAndPersist({
  required LlmEngineController engine,
  required AppSettings settings,
  required void Function(String? id) setActiveId,
  required LlmProfile profile,
}) async {
  final err = await engine.activate(profile);
  if (err != null) return err;
  setActiveId(profile.id);
  await settings.setActiveLlmProfile(profile.id);
  return null;
}

// ---------------- 引擎生命周期 ----------------

enum LlmEngineStatus { idle, loading, ready, error }

class LlmEngineState {
  const LlmEngineState({
    this.status = LlmEngineStatus.idle,
    this.activeProfileId,
    this.error,
  });

  final LlmEngineStatus status;
  final String? activeProfileId;
  final String? error;
}

/// 引擎控制器：负责本地模型的加载/卸载与远端引擎的构建。
class LlmEngineController extends StateNotifier<LlmEngineState> {
  LlmEngineController(this._ref) : super(const LlmEngineState()) {
    _localEngine = LocalChatEngine();
  }

  final Ref _ref;

  LocalChatEngine? _localEngine;
  InferenceEngine? _engine;

  LlmProfile? activeProfile() => _ref.read(activeLlmProfileProvider);

  /// 实际生效档案（用户激活优先，否则内置默认）。
  LlmProfile? effectiveProfile() => _ref.read(effectiveLlmProfileProvider);

  /// 激活（切换）模型配置。返回错误信息，null 表示成功。
  Future<String?> activate(LlmProfile profile) async {
    // 防止重复加载（启动预热与页面 ensureReady 并发触发）
    if ((state.status == LlmEngineStatus.loading ||
            state.status == LlmEngineStatus.ready) &&
        state.activeProfileId == profile.id) {
      return null;
    }
    state = LlmEngineState(status: LlmEngineStatus.loading);
    try {
      if (profile.kind == LlmKind.local) {
        await _localEngine!.load(profile);
        _engine = _localEngine;
      } else {
        await _localEngine?.unload();
        _engine = RemoteChatEngine(profile);
      }
      state = LlmEngineState(
        status: LlmEngineStatus.ready,
        activeProfileId: profile.id,
      );
      return null;
    } catch (e) {
      _engine = null;
      final msg = e is InferenceException
          ? e.message
          : AppLocaleService.auto.loadFailed(e.toString());
      state = LlmEngineState(status: LlmEngineStatus.error, error: msg);
      return msg;
    }
  }

  /// 确保引擎就绪（未配置/未加载时按实际生效档案加载）。
  ///
  /// 用户已激活模型按现状启动预热；内置默认模型在此懒激活
  /// （首次进入 AI 功能时才加载，避免启动常驻约 2GB 内存）。
  Future<String?> ensureReady() async {
    final p = effectiveProfile();
    if (p == null) return AppLocaleService.auto.llmNotConfigured;
    if (state.status == LlmEngineStatus.ready &&
        state.activeProfileId == p.id) {
      return null;
    }
    return activate(p);
  }

  /// 流式对话。
  Stream<String> chatStream(List<ChatMessage> messages,
      {double temperature = 0.7}) async* {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw InferenceException(AppLocaleService.auto.llmNotReady);
    }
    yield* engine.chatStream(messages, temperature: temperature);
  }

  /// 结构化 JSON 问答（仅本地引擎支持 grammar 约束；远端引擎无此通道）。
  /// 用于内置默认模型的置信度门槛问答。
  Future<Map<String, Object?>> chatJson(
    List<ChatMessage> messages, {
    required Map<String, Object?> schema,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    final engine = _engine;
    if (engine is! LocalChatEngine || !engine.isReady) {
      throw InferenceException(AppLocaleService.auto.llmNotReady);
    }
    return engine.chatJson(
      messages,
      schema: schema,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<void> deactivate() async {
    await _localEngine?.unload();
    _engine = null;
    state = const LlmEngineState(status: LlmEngineStatus.idle);
  }

  @override
  void dispose() {
    _localEngine?.dispose();
    super.dispose();
  }
}

final llmEngineProvider =
    StateNotifierProvider<LlmEngineController, LlmEngineState>((ref) {
  throw UnimplementedError('需在 main() 中覆盖');
});

// ---------------- 模型下载 / 模型中心（双社区） ----------------

final modelscopeClientProvider =
    Provider<ModelScopeClient>((ref) => ModelScopeClient());

final huggingFaceClientProvider =
    Provider<HuggingFaceClient>((ref) => HuggingFaceClient());

/// 模型中心：并行搜索/查找多个模型社区，能搜到哪个就用哪个。
final modelCenterServiceProvider = Provider<ModelCenterService>(
    (ref) => ModelCenterService({
          ref.watch(modelscopeClientProvider).id:
              ref.watch(modelscopeClientProvider),
          ref.watch(huggingFaceClientProvider).id:
              ref.watch(huggingFaceClientProvider),
        }));

final modelDownloaderProvider = ChangeNotifierProvider<ModelDownloadService>(
    (ref) {
  final scopeClient = ref.watch(modelscopeClientProvider);
  final hfClient = ref.watch(huggingFaceClientProvider);
  final service = ModelDownloadService(scopeClient)
    ..communities = {
      scopeClient.id: scopeClient,
      hfClient.id: hfClient,
    };
  // 下载完成 → 自动建档（「安装」）。幂等：同一路径只建一份。
  service.onCompleted = (communityId, repoId, filePath) async {
    final target = await ModelDownloadService.targetPath(repoId, filePath);
    final name = filePath.contains('/')
        ? filePath.split('/').last
        : filePath;
    await ref
        .read(llmProfilesProvider.notifier)
        .ensureLocalProfileForFile(target, name);
  };
  return service;
});

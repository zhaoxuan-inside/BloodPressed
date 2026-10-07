import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:uuid/uuid.dart';

import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/llm/data/llm_profile_store.dart';
import 'package:blood_pressed/features/llm/data/model_downloader.dart';
import 'package:blood_pressed/features/llm/data/modelscope_client.dart';
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

  /// 确保引擎就绪（未配置/未加载时按激活档案加载）。
  Future<String?> ensureReady() async {
    final p = activeProfile();
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

// ---------------- 模型下载 / 魔搭 ----------------

final modelscopeClientProvider =
    Provider<ModelScopeClient>((ref) => ModelScopeClient());

final modelDownloaderProvider = ChangeNotifierProvider<ModelDownloadService>(
    (ref) => ModelDownloadService(ref.watch(modelscopeClientProvider)));

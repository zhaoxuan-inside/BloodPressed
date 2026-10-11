/// 内置默认模型（Qwen3-1.7B）：不落 llm_profiles 表的 virtual 档案。
///
/// APK 无法内置 1.8GB 模型文件，「内置」的语义是：
/// * 档案 id 固定（区别于用户档案的 UUID），用户不可删除、不可编辑；
/// * 模型文件由 ModelDownloadService 按既有路径规则从魔搭下载（首次使用
///   时经用户确认）；
/// * 仅当用户未配置/未激活任何模型时作为兜底生效，且懒激活（不随启动
///   预热，避免每次启动常驻约 2GB 内存）；
/// * 命中内置模型问答时走 90 分置信度门槛（见 AssistantController）。
library;

import 'dart:io';

import 'llm_models.dart';

/// 内置默认档案的固定 id。
const String kBuiltinProfileId = 'builtin-qwen3-1.7b';

/// 内置模型的魔搭仓库与权重文件（Q8_0 量化，约 1.8GB，
/// 已通过 ModelScope files API 验证存在）。
const String kBuiltinRepoId = 'Qwen/Qwen3-1.7B-GGUF';
const String kBuiltinFileName = 'Qwen3-1.7B-Q8_0.gguf';

/// 内置模型的下载任务 key（与 ModelDownloadService 的 key 规则一致）。
String builtinDownloadKey() => '$kBuiltinRepoId/$kBuiltinFileName';

/// 内置模型文件的最终本地路径。
///
/// 与 `ModelDownloadService.targetPath` 的落盘规则保持一致：
/// `{docs}/models/{repoId 中 '/' 替换为 '_'}/{fileName}`。
/// [docsDirPath] 为应用文档目录，使本函数保持纯函数、可单测。
String builtinModelFilePath(String docsDirPath) {
  final safe = kBuiltinRepoId.replaceAll('/', '_');
  final sep = Platform.pathSeparator;
  return '$docsDirPath${sep}models$sep$safe$sep$kBuiltinFileName';
}

/// 构造内置默认档案（virtual，不落库）。
///
/// [modelPath] 为已下载的权重文件路径（见 [builtinModelFilePath]）。
LlmProfile builtinProfile(String modelPath) => LlmProfile(
      id: kBuiltinProfileId,
      kind: LlmKind.local,
      name: 'Qwen3-1.7B',
      config: {
        'modelPath': modelPath,
        'contextSize': 2048,
        'threads': 0,
      },
    );

/// 该档案是否为内置默认模型。
bool isBuiltinProfile(LlmProfile profile) => profile.id == kBuiltinProfileId;

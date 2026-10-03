import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

/// 远端引擎：OpenAI 兼容 Chat Completions（支持 SSE 流式与多模态图片输入）。
///
/// 兼容：ModelScope API-Inference、DashScope 兼容模式、DeepSeek、
/// OpenAI、Ollama(/v1)、vLLM 等一切 OpenAI 格式端点。
class RemoteChatEngine implements InferenceEngine {
  RemoteChatEngine(this.profile, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(seconds: 60),
            ));

  final LlmProfile profile;
  final Dio _dio;

  @override
  bool get isReady => profile.kind == LlmKind.remote && profile.usable;

  @override
  String? get profileId => profile.id;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (profile.apiKey.isNotEmpty) 'Authorization': 'Bearer ${profile.apiKey}',
      };

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async* {
    if (!isReady) {
      throw const InferenceException('远端模型配置不完整');
    }
    final body = {
      'model': profile.remoteModel,
      'messages': messages
          .map((m) => {
                'role': m.role.name,
                'content': m.content,
              })
          .toList(),
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    yield* _streamSse(body);
  }

  /// 多模态图片识别（OCR 兜底）。
  ///
  /// [jpegBytes] 为压缩后的图片；[prompt] 要求模型输出结构化 JSON。
  Future<String> recognizeImage({
    required Uint8List jpegBytes,
    required String prompt,
    String mimeType = 'image/jpeg',
  }) async {
    if (!isReady) throw const InferenceException('远端模型配置不完整');
    final dataUrl = 'data:$mimeType;base64,${base64Encode(jpegBytes)}';
    final body = {
      'model': profile.remoteModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        }
      ],
      'temperature': 0.1,
      'max_tokens': 512,
    };
    final resp = await _dio.post(
      '${profile.baseUrl}/chat/completions',
      options: Options(headers: _headers, responseType: ResponseType.json),
      data: body,
    );
    final content = resp.data['choices']?[0]?['message']?['content'];
    if (content is String) return content;
    throw const InferenceException('远端返回格式异常');
  }

  /// 发起流式请求并解析 SSE。
  Stream<String> _streamSse(Map<String, Object?> body) async* {
    final Response<ResponseBody> resp;
    try {
      resp = await _dio.post<ResponseBody>(
        '${profile.baseUrl}/chat/completions',
        options: Options(
          headers: _headers,
          responseType: ResponseType.stream,
        ),
        data: body,
      );
    } on DioException catch (e) {
      throw InferenceException(
        _friendlyDioError(e),
        e,
      );
    }

    final stream = resp.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final json = jsonDecode(payload) as Map<String, Object?>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'] as Map?;
        final content = delta?['content'];
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {
        // 单个 chunk 解析失败不影响整体流
      }
    }
  }

  static String _friendlyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络或服务地址';
      case DioExceptionType.connectionError:
        return '无法连接到服务端，请检查网络与 baseUrl';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final data = e.response?.data;
        String detail = '';
        if (data is Map && data['error'] != null) {
          detail = '：${data['error']}';
        } else if (data is String && data.isNotEmpty) {
          detail = '：${data.takeChars(120)}';
        }
        return '服务端返回错误（HTTP $code）$detail';
      default:
        return '请求失败：${e.message ?? e.type.name}';
    }
  }

  /// 拉取可用模型列表（OpenAI 兼容 `GET /models`）。
  ///
  /// 兼容标准返回 `{"data":[{"id":"..."}]}` 以及部分网关的
  /// `{"data":[{"model":"..."}]}` / 纯数组等变体。
  /// apiKey 未填时直接抛出提示，避免必然失败的请求。
  Future<List<String>> listModels() async {
    if (!isReady) {
      throw const InferenceException('远端模型配置不完整');
    }
    if (profile.apiKey.isEmpty) {
      throw const InferenceException('请先填写 API Key 再获取模型列表');
    }
    final Response resp;
    try {
      resp = await _dio.get(
        '${profile.baseUrl}/models',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw InferenceException(_friendlyDioError(e), e);
    }

    final data = resp.data;
    final List items;
    if (data is Map && data['data'] is List) {
      items = data['data'] as List;
    } else if (data is List) {
      items = data; // 部分网关直接返回数组
    } else {
      throw InferenceException('响应格式无法识别（HTTP ${resp.statusCode}），'
          '该服务可能不支持模型列表接口，请手动填写模型名称');
    }

    final ids = <String>[];
    for (final item in items) {
      if (item is Map) {
        final id = item['id'] ?? item['model'] ?? item['name'];
        if (id is String && id.isNotEmpty) ids.add(id);
      } else if (item is String && item.isNotEmpty) {
        ids.add(item);
      }
    }
    ids.sort();
    if (ids.isEmpty) {
      throw const InferenceException('服务返回了空的模型列表，请手动填写模型名称');
    }
    return ids;
  }

  @override
  Future<void> dispose() async {
    _dio.close();
  }
}

extension on String {
  String takeChars(int n) => length <= n ? this : substring(0, n);
}

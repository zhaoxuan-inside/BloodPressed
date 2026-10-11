/// 门槛问答（内置默认模型专用）：输出协议、解析与置信度阈值。
///
/// 内置 Qwen3-1.7B 没有校准过的置信度，采用「自报置信度 + 硬门槛」：
/// 引擎以 grammar 约束输出 {answer, confidence}（形状由 llama.cpp
/// GBNF 保证），本模块再对语义做最终校验与门槛判断——低于
/// [kGatedAnswerThreshold] 一律拒答，宁可说不知道也不给不可靠的
/// 健康建议。用户自配模型不走此协议。
library;

/// 置信度门槛（百分制）。
const int kGatedAnswerThreshold = 90;

/// 引擎 grammar 约束用的输出 schema（chatJson 的 schema 参数）。
///
/// 注意：llamadart 的 JSON-schema→GBNF 子集不支持数值 minimum/maximum，
/// 0~100 的范围校验由 [parseGatedAnswer] 兜底（grammar 保证其为整数）。
const Map<String, Object?> gatedAnswerSchema = {
  'type': 'object',
  'properties': {
    'answer': {'type': 'string'},
    'confidence': {'type': 'integer'},
  },
  'required': ['answer', 'confidence'],
};

/// 一次门槛问答的解析结果。
class GatedAnswer {
  const GatedAnswer({required this.answer, required this.confidence});

  final String answer;
  final int confidence;

  /// 是否达到可回答门槛。
  bool get isReliable => confidence >= kGatedAnswerThreshold;
}

/// 校验并解析引擎输出的 JSON 对象。
///
/// 返回 null 表示输出不可用（缺字段/空答案/置信度越界），调用方应按
/// 拒答处理——grammar 约束已保证形状，这里是防御性兜底。
GatedAnswer? parseGatedAnswer(Map<String, Object?> json) {
  final answer = json['answer'];
  final confidence = json['confidence'];
  if (answer is! String || answer.trim().isEmpty) return null;
  if (confidence is! int || confidence < 0 || confidence > 100) return null;
  return GatedAnswer(answer: answer.trim(), confidence: confidence);
}

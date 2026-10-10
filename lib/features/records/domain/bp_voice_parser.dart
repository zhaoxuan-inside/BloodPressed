/// 语音口令解析器：从 STT 识别文本中提取血压 & 脉搏数值。
///
/// 纯 Dart 无副作用，可独立单元测试。
library;

/// 语音解析结果。
class VoiceParseResult {
  const VoiceParseResult({
    this.systolic,
    this.diastolic,
    this.pulse,
  });

  final int? systolic;
  final int? diastolic;
  final int? pulse;

  /// 是否至少识别到一个有效数值。
  bool get hasAny => systolic != null || diastolic != null || pulse != null;

  /// 是否三值齐全。
  bool get isComplete => systolic != null && diastolic != null;

  /// 识别到的字段数。
  int get recognizedCount =>
      (systolic != null ? 1 : 0) +
      (diastolic != null ? 1 : 0) +
      (pulse != null ? 1 : 0);

  @override
  String toString() =>
      'VoiceParseResult(sys=$systolic, dia=$diastolic, pulse=$pulse)';
}

/// 血压语音口令解析器。
///
/// 支持中英文混合口令，例如：
/// - 「收缩压 120 舒张压 80 脉搏 72」
/// - 「高压 130 低压 85 心率 68」
/// - 「120/80 脉搏 72」
/// - 「systolic 120 diastolic 80 pulse 72」
/// - 「一百二十 八十 七十二」（中文数字）
class BpVoiceParser {
  BpVoiceParser._();

  // ── 关键词 → 字段映射 ────────────────────────────────────────────────────

  static const _sysKeywords = [
    '收缩压', '高压', '上压', 'systolic', 'sys', 'sbp',
  ];
  static const _diaKeywords = [
    '舒张压', '低压', '下压', '舒张', 'diastolic', 'dia', 'dbp',
  ];
  static const _pulseKeywords = [
    '脉搏', '脉率', '心率', '心跳', 'pulse', 'heart rate', 'hr',
  ];

  // ── 中文数字 → 阿拉伯数字转换表 ──────────────────────────────────────────

  static const _zhDigits = {
    '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    '十': 10, '百': 100,
  };

  // ── 公共入口 ──────────────────────────────────────────────────────────────

  /// 从 STT 识别文本中提取血压数值。
  static VoiceParseResult parse(String text) {
    // 1. 预处理：转小写，全角数字转半角，中文数字转阿拉伯数字
    var normalized = _normalize(text);

    // 2. 先尝试关键词匹配（优先级高）
    final result = _parseByKeyword(normalized);
    if (result.hasAny) return result;

    // 3. 降级：尝试裸数字序列匹配（如「120 80 72」）
    return _parseByPosition(normalized);
  }

  // ── 预处理 ───────────────────────────────────────────────────────────────

  static String _normalize(String text) {
    var s = text.toLowerCase();
    // 全角数字 → 半角
    s = s.replaceAllMapped(RegExp(r'[０-９]'), (m) {
      return String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFF10 + 0x30);
    });
    // 中文数字转阿拉伯（简单：一百二十 → 120，七十二 → 72）
    s = _convertChineseNumbers(s);
    // 去除常见噪声词（标点、助词等）
    s = s.replaceAll(RegExp(r'[，。、：:,.]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String _convertChineseNumbers(String s) {
    // 匹配：[一二三四五六七八九]百[零一二三四五六七八九十]?[十一二三四五六七八九]?
    // 覆盖血压范围：40～299
    return s.replaceAllMapped(
      RegExp(r'([一二三四五六七八九两])[百佰]([零一二三四五六七八九]?)[十拾]?([一二三四五六七八九]?)'),
      (m) {
        final hundreds = (_zhDigits[m[1]] ?? 0) * 100;
        final tens = m[2]!.isEmpty ? 0 : (_zhDigits[m[2]] ?? 0) * 10;
        final ones = m[3]!.isEmpty ? 0 : (_zhDigits[m[3]] ?? 0);
        final value = hundreds + tens + ones;
        return value > 0 ? '$value' : '';
      },
    ).replaceAllMapped(
      // [七八九]十[一二三四五六七八九]? — 覆盖 70～99
      RegExp(r'([四五六七八九])[十拾]([零一二三四五六七八九]?)'),
      (m) {
        final tens = (_zhDigits[m[1]] ?? 0) * 10;
        final ones = m[2]!.isEmpty ? 0 : (_zhDigits[m[2]] ?? 0);
        return '${tens + ones}';
      },
    );
  }

  // ── 关键词匹配策略 ────────────────────────────────────────────────────────

  static VoiceParseResult _parseByKeyword(String text) {
    int? sys = _extractAfterKeyword(text, _sysKeywords);
    int? dia = _extractAfterKeyword(text, _diaKeywords);
    int? pulse = _extractAfterKeyword(text, _pulseKeywords);

    // 尝试 "120/80" 斜杠格式
    if (sys == null && dia == null) {
      final slashMatch = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(text);
      if (slashMatch != null) {
        final a = int.tryParse(slashMatch[1]!);
        final b = int.tryParse(slashMatch[2]!);
        if (a != null && b != null && _isSysRange(a) && _isDiaRange(b)) {
          sys = a;
          dia = b;
        }
      }
    }

    return VoiceParseResult(
      systolic: sys != null && _isSysRange(sys) ? sys : null,
      diastolic: dia != null && _isDiaRange(dia) ? dia : null,
      pulse: pulse != null && _isPulseRange(pulse) ? pulse : null,
    );
  }

  static int? _extractAfterKeyword(String text, List<String> keywords) {
    for (final kw in keywords) {
      final idx = text.indexOf(kw);
      if (idx < 0) continue;
      final after = text.substring(idx + kw.length);
      final m = RegExp(r'^\s*(\d{2,3})').firstMatch(after);
      if (m != null) return int.tryParse(m[1]!);
    }
    return null;
  }

  // ── 位置匹配降级策略 ──────────────────────────────────────────────────────

  /// 从文本中提取全部 2-3 位数字，按位置推断：第1个→sys, 第2个→dia, 第3个→pulse
  static VoiceParseResult _parseByPosition(String text) {
    final nums = RegExp(r'\b(\d{2,3})\b')
        .allMatches(text)
        .map((m) => int.tryParse(m[1]!))
        .whereType<int>()
        .toList();

    int? sys, dia, pulse;
    for (final n in nums) {
      if (sys == null && _isSysRange(n)) {
        sys = n;
      } else if (dia == null && _isDiaRange(n) && (sys == null || n < sys)) {
        dia = n;
      } else if (pulse == null && _isPulseRange(n)) {
        pulse = n;
      }
    }
    return VoiceParseResult(systolic: sys, diastolic: dia, pulse: pulse);
  }

  // ── 范围校验（复用 domain 知识，避免依赖 validateBpValues） ───────────────

  static bool _isSysRange(int v) => v >= 60 && v <= 300;
  static bool _isDiaRange(int v) => v >= 30 && v <= 200;
  static bool _isPulseRange(int v) => v >= 20 && v <= 300;
}

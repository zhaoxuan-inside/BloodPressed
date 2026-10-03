/// 血压计照片 OCR 结果解析引擎（纯 Dart，无 Flutter 依赖，便于单元测试）。
///
/// 支持常见电子血压计的显示/打印格式：
/// * 分数式：`120/80`、`120 / 80 mmHg`、`120／80`
/// * 标签式：`高压 120 低压 80 脉搏 72`、`收缩压 120  舒张压 80`、
///   `SYS 120 DIA 80 PUL 72`、`HYP 120 DIA 80 PUL 72`
/// * 上下行无标签：`mmHg` 附近成对出现的两个 2~3 位数
///
/// 输出多个候选并按置信度排序，由调用方决定是否需要大模型兜底复核。
library;

class BpCandidate {
  const BpCandidate({
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.confidence,
    required this.pattern,
  });

  final int systolic;
  final int diastolic;
  final int? pulse;
  final double confidence; // 0~1
  final String pattern; // 命中的模式（调试/展示用）

  bool get plausible =>
      inRange(systolic, 60, 260) &&
      inRange(diastolic, 40, 160) &&
      systolic > diastolic &&
      (pulse == null || inRange(pulse!, 30, 220));

  static bool inRange(int v, int lo, int hi) => v >= lo && v <= hi;
}

class OcrParseResult {
  const OcrParseResult({required this.candidates});

  final List<BpCandidate> candidates;

  bool get isEmpty => candidates.isEmpty;
  BpCandidate? get best =>
      candidates.isEmpty ? null : candidates.first;

  /// 最高置信度是否达到"可直接预填"的水平。
  bool get isReliable => best != null && best!.confidence >= 0.6;
}

class OcrBpParser {
  const OcrBpParser();

  // 合理区间
  static const int _sysLo = 60, _sysHi = 260;
  static const int _diaLo = 40, _diaHi = 160;
  static const int _pulseLo = 30, _pulseHi = 220;

  /// 主入口：把 OCR 全文解析为候选列表（置信度降序）。
  OcrParseResult parse(String rawText) {
    final text = normalize(rawText);
    final candidates = <BpCandidate>[];

    // 1) 分数式 a/b（+ 可选脉搏）
    candidates.addAll(_parseFraction(text));

    // 2) 标签式：高压/低压（收缩压/舒张压，SYS/DIA 等）
    candidates.addAll(_parseLabeled(text));

    // 3) 兜底：mmHg 附近相邻的两个独立数值
    candidates.addAll(_parseAdjacent(text));

    // 去重（同值保留置信度高者）
    final seen = <String, BpCandidate>{};
    for (final c in candidates) {
      final key = '${c.systolic}-${c.diastolic}-${c.pulse ?? "_"}';
      final old = seen[key];
      if (old == null || c.confidence > old.confidence) {
        seen[key] = c;
      }
    }
    final list = seen.values.where((c) => c.plausible).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return OcrParseResult(candidates: list);
  }

  /// 全角转半角、统一常见分隔、剔除逗号。
  String normalize(String raw) {
    final sb = StringBuffer();
    for (final rune in raw.runes) {
      var ch = String.fromCharCode(rune);
      final code = rune;
      if (code >= 0xFF10 && code <= 0xFF19) {
        ch = String.fromCharCode(code - 0xFEE0); // 全角数字 → 半角
      } else if (ch == '／') {
        ch = '/';
      } else if (ch == '，' || ch == '，') {
        ch = ' ';
      }
      sb.write(ch);
    }
    var t = sb.toString();
    t = t.replaceAll(',', ' ');
    return t;
  }

  // ---------------- 模式 1：分数式 ----------------

  static final RegExp _fraction = RegExp(
    r'(\d{2,3})\s*[/／]\s*(\d{2,3})',
    multiLine: true,
  );

  static final RegExp _pulseAfter = RegExp(
    r'(?:脉搏|脉率|心率|PUL|PULSE|HR|BPM|PPM)[^\d]{0,8}(\d{2,3})|'
    r'(\d{2,3})\s*(?:BPM|PPM)',
    caseSensitive: false,
  );

  List<BpCandidate> _parseFraction(String text) {
    final out = <BpCandidate>[];
    for (final m in _fraction.allMatches(text)) {
      final sys = int.tryParse(m.group(1)!);
      final dia = int.tryParse(m.group(2)!);
      if (sys == null || dia == null) continue;
      if (!_inRange(sys, _sysLo, _sysHi) || !_inRange(dia, _diaLo, _diaHi)) {
        continue;
      }
      if (sys <= dia) continue;

      var pulse = _findPulseNear(text, m.end);
      var confidence = 0.45;
      if (_hasUnitNear(text, m.start, m.end)) confidence += 0.2;
      if (pulse != null) confidence += 0.15;
      // 血压计显示的分数式几乎总是"收缩/舒张"顺序，进一步加权
      confidence += 0.1;
      out.add(BpCandidate(
        systolic: sys,
        diastolic: dia,
        pulse: pulse,
        confidence: confidence.clamp(0.0, 0.98),
        pattern: 'fraction',
      ));

      // 有些屏幕把脉搏放在分数左侧，也尝试解析
      final altPulse = _findPulseNear(text, 0, end: m.start);
      if (altPulse != null && altPulse != pulse) {
        out.add(BpCandidate(
          systolic: sys,
          diastolic: dia,
          pulse: altPulse,
          confidence: (confidence - 0.1).clamp(0.0, 0.98),
          pattern: 'fraction+leftPulse',
        ));
      }
    }
    return out;
  }

  // ---------------- 模式 2：标签式 ----------------

  static final RegExp _sysLabeled = RegExp(
    r'(?:高压|收缩压|收缩|SYS|HYP|SYST|S)[^\d\-]{0,6}(\d{2,3})',
    caseSensitive: false,
  );
  static final RegExp _diaLabeled = RegExp(
    r'(?:低压|舒张压|舒张|DIA|DIAS|D)[^\d\-]{0,6}(\d{2,3})',
    caseSensitive: false,
  );
  static final RegExp _pulseLabeled = RegExp(
    r'(?:脉搏|脉率|心率|PUL|PULSE|HR|PPM)[^\d\-]{0,6}(\d{2,3})',
    caseSensitive: false,
  );

  List<BpCandidate> _parseLabeled(String text) {
    final sysM = _sysLabeled.firstMatch(text);
    final diaM = _diaLabeled.firstMatch(text);
    if (sysM == null || diaM == null) return [];
    final sys = int.tryParse(sysM.group(1)!);
    final dia = int.tryParse(diaM.group(1)!);
    if (sys == null || dia == null) return [];
    if (!_inRange(sys, _sysLo, _sysHi) || !_inRange(dia, _diaLo, _diaHi)) {
      return [];
    }
    if (sys <= dia) return [];

    final pulseM = _pulseLabeled.firstMatch(text);
    final pulse = pulseM == null ? null : int.tryParse(pulseM.group(1)!);

    var confidence = 0.6;
    if (_hasUnitNear(text, 0, text.length)) confidence += 0.15;
    if (pulse != null && _inRange(pulse, _pulseLo, _pulseHi)) {
      confidence += 0.15;
    }
    return [
      BpCandidate(
        systolic: sys,
        diastolic: dia,
        pulse: (pulse != null && _inRange(pulse, _pulseLo, _pulseHi))
            ? pulse
            : null,
        confidence: confidence.clamp(0.0, 0.98),
        pattern: 'labeled',
      )
    ];
  }

  // ---------------- 模式 3：相邻数值兜底 ----------------

  static final RegExp _twoNumbers = RegExp(
    r'(\d{2,3})\s+[-–—]?\s*(\d{2,3})(?!\s*[/／])',
  );

  List<BpCandidate> _parseAdjacent(String text) {
    final hasUnit = text.toLowerCase().contains('mmhg');
    if (!hasUnit) return [];
    final out = <BpCandidate>[];
    for (final m in _twoNumbers.allMatches(text)) {
      final sys = int.tryParse(m.group(1)!);
      final dia = int.tryParse(m.group(2)!);
      if (sys == null || dia == null) continue;
      if (!_inRange(sys, _sysLo, _sysHi) || !_inRange(dia, _diaLo, _diaHi)) {
        continue;
      }
      if (sys <= dia) continue;
      final pulse = _findPulseNear(text, m.end);
      out.add(BpCandidate(
        systolic: sys,
        diastolic: dia,
        pulse: pulse,
        confidence: (pulse != null ? 0.5 : 0.4).clamp(0.0, 0.98),
        pattern: 'adjacent',
      ));
    }
    return out;
  }

  // ---------------- 工具 ----------------

  /// 在 [from] 附近（后向一小段）寻找脉搏数值。
  int? _findPulseNear(String text, int from, {int? end}) {
    final to = (end ?? from + 30).clamp(0, text.length);
    final start = (from - 5).clamp(0, to);
    final region = text.substring(start, to);
    for (final m in _pulseAfter.allMatches(region)) {
      final g = m.group(1) ?? m.group(2);
      final v = g == null ? null : int.tryParse(g);
      if (v != null && _inRange(v, _pulseLo, _pulseHi)) return v;
    }
    return null;
  }

  bool _hasUnitNear(String text, int start, int end) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf('mmhg');
    return idx >= 0 && idx >= start - 10 && idx <= end + 10;
  }

  static bool _inRange(int v, int lo, int hi) => v >= lo && v <= hi;
}

/// 从大模型返回的文本中提取结构化识别结果（多模态兜底用）。
///
/// 期望模型输出 JSON：{"systolic":120,"diastolic":80,"pulse":72}
/// 模型可能包裹在 ```json ``` 中或夹带说明文字，这里做宽容提取。
BpCandidate? parseLlmExtraction(String output) {
  final jsonMatch =
      RegExp(r'\{[^{}]*\}', dotAll: true).allMatches(output).toList();
  for (final m in jsonMatch.reversed) {
    final raw = m.group(0)!;
    final sys = RegExp(r'"?systolic"?\s*[:：]\s*"?(\d{2,3})')
        .firstMatch(raw)
        ?.group(1);
    final dia = RegExp(r'"?diastolic"?\s*[:：]\s*"?(\d{2,3})')
        .firstMatch(raw)
        ?.group(1);
    final pulse = RegExp(r'"?pulse"?\s*[:：]\s*"?(\d{2,3})')
        .firstMatch(raw)
        ?.group(1);
    final sysV = sys == null ? null : int.tryParse(sys);
    final diaV = dia == null ? null : int.tryParse(dia);
    final pulseV = pulse == null ? null : int.tryParse(pulse);
    if (sysV == null || diaV == null) continue;
    final c = BpCandidate(
      systolic: sysV,
      diastolic: diaV,
      pulse: pulseV,
      confidence: 0.75,
      pattern: 'llm',
    );
    if (c.plausible) return c;
  }
  return null;
}

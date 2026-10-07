import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/features/records/presentation/controllers/records_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 录入 / 编辑页。同时承担"OCR/AI 识别结果确认"角色。
class RecordEditPage extends ConsumerStatefulWidget {
  const RecordEditPage({
    super.key,
    this.existing,
    this.initialSystolic,
    this.initialDiastolic,
    this.initialPulse,
    this.initialSource = RecordSource.manual,
    this.initialPhotoPath,
    this.initialConfidence,
    this.initialLowConfidence = false,
  });

  final BpRecord? existing;
  final int? initialSystolic;
  final int? initialDiastolic;
  final int? initialPulse;
  final RecordSource initialSource;
  final String? initialPhotoPath;
  final double? initialConfidence;

  /// 低置信度/未识别：预填值仅供参考，所有数值输入框红框强调。
  final bool initialLowConfidence;

  @override
  ConsumerState<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends ConsumerState<RecordEditPage> {
  late final TextEditingController _sysCtrl;
  late final TextEditingController _diaCtrl;
  late final TextEditingController _pulseCtrl;
  late final TextEditingController _noteCtrl;

  late MeasureArm _arm;
  MeasurePosture? _posture;
  late DateTime _measuredAt;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _sysCtrl = TextEditingController(
      text: (e?.systolic ?? widget.initialSystolic)?.toString() ?? '',
    );
    _diaCtrl = TextEditingController(
      text: (e?.diastolic ?? widget.initialDiastolic)?.toString() ?? '',
    );
    _pulseCtrl = TextEditingController(
      text: (e?.pulse ?? widget.initialPulse)?.toString() ?? '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _arm = e?.arm ?? ref.read(appSettingsProvider).defaultArm;
    _posture = e?.posture;
    _measuredAt = e?.measuredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _pulseCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
    );
    if (time == null) return;
    setState(() {
      _measuredAt = DateTime(date.year, date.month, date.day, time.hour,
          time.minute);
    });
  }

  Future<void> _save() async {
    final sys = int.tryParse(_sysCtrl.text.trim());
    final dia = int.tryParse(_diaCtrl.text.trim());
    final pulse =
        _pulseCtrl.text.trim().isEmpty ? null : int.tryParse(_pulseCtrl.text.trim());
    final error = validateBpValues(
        systolic: sys, diastolic: dia, pulse: pulse);
    if (error != null) {
      final l10n = AppLocalizations.of(context);
      final message = switch (error) {
        BpValidationError.needSysDia => l10n.errNeedSysDia,
        BpValidationError.sysRange => l10n.errSysRange,
        BpValidationError.diaRange => l10n.errDiaRange,
        BpValidationError.sysGreater => l10n.errSysGreater,
        BpValidationError.pulseRange => l10n.errPulseRange,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await ref.read(recordsControllerProvider.notifier).save(
          systolic: sys!,
          diastolic: dia!,
          pulse: pulse,
          measuredAt: _measuredAt,
          arm: _arm,
          posture: _posture,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          source: _isEditing
              ? widget.existing!.source
              : widget.initialSource,
          photoPath: _isEditing
              ? widget.existing!.photoPath
              : widget.initialPhotoPath,
          editId: widget.existing?.id,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  BpCategory? get _previewCategory {
    final sys = int.tryParse(_sysCtrl.text.trim());
    final dia = int.tryParse(_diaCtrl.text.trim());
    if (sys == null || dia == null || sys <= dia) return null;
    return BpCategory.fromValues(sys, dia);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _previewCategory;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editRecordTitle : l10n.newRecordTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEditing && widget.initialSource != RecordSource.manual)
              _RecognitionSourceBanner(
                source: widget.initialSource,
                confidence: widget.initialConfidence,
                lowConfidence: widget.initialLowConfidence,
              ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _sysCtrl,
                    label: l10n.sysLabel,
                    highlight: widget.initialLowConfidence,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _diaCtrl,
                    label: l10n.diaLabel,
                    highlight: widget.initialLowConfidence,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: _pulseCtrl,
              label: l10n.pulseLabel,
              suffix: l10n.pulseUnit,
              highlight: widget.initialLowConfidence,
            ),
            const SizedBox(height: 12),
            SegmentedButton<MeasureArm>(
              segments: [
                ButtonSegment(
                    value: MeasureArm.left, label: Text(l10n.armLeft)),
                ButtonSegment(
                    value: MeasureArm.right, label: Text(l10n.armRight)),
              ],
              selected: {_arm},
              onSelectionChanged: (s) => setState(() => _arm = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<MeasurePosture?>(
                    initialValue: _posture,
                    decoration: InputDecoration(labelText: l10n.postureField),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l10n.postureNotRecorded)),
                      ...MeasurePosture.values.map(
                        (p) => DropdownMenuItem(
                            value: p, child: Text(postureLabel(l10n, p))),
                      ),
                    ],
                    onChanged: (v) => setState(() => _posture = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(Fmt.full(_measuredAt)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.noteField),
            ),
            if (category != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 36,
                    decoration: BoxDecoration(
                      color: BpCategoryStyle.colorOf(category),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${categoryLabel(l10n, category)} — ${categoryAdvice(l10n, category)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? l10n.saveEdit : l10n.saveNew),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

}

class _RecognitionSourceBanner extends StatelessWidget {
  const _RecognitionSourceBanner({
    required this.source,
    this.confidence,
    this.lowConfidence = false,
  });

  final RecordSource source;
  final double? confidence;
  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final text =
        source == RecordSource.ocr ? l10n.bannerSourceOcr : l10n.bannerSourceAi;
    if (lowConfidence) {
      final detail = confidence == null
          ? l10n.bannerLowNoValue(text)
          : l10n.bannerLowConfidence(text, (confidence! * 100).round());
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }
    final conf = confidence == null
        ? ''
        : l10n.confidenceSuffix((confidence! * 100).round());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.bannerAutoFilled(text, conf),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.suffix,
    this.onChanged,
    this.highlight = false,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 3,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixText: suffix,
        filled: highlight,
        fillColor: highlight ? error.withValues(alpha: 0.06) : null,
        enabledBorder: highlight
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: error, width: 1.6),
              )
            : null,
        focusedBorder: highlight
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: error, width: 2),
              )
            : null,
      ),
      onChanged: onChanged,
    );
  }
}

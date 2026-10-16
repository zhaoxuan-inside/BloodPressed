import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/records/presentation/record_edit_page.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

import 'controllers/trend_providers.dart';
import 'widgets/trend_chart.dart';

/// Day drilldown: every measurement gets enough space, including repeated timestamps.
class DailyTrendPage extends ConsumerStatefulWidget {
  const DailyTrendPage({
    super.key,
    required this.range,
    required this.initialDate,
    this.pulse = false,
  });
  final TrendQuery range;
  final DateTime initialDate;
  final bool pulse;
  @override
  ConsumerState<DailyTrendPage> createState() => _DailyTrendPageState();
}

class _DailyTrendPageState extends ConsumerState<DailyTrendPage> {
  late DateTime _date;
  late bool _pulse;
  late final DateTime _first;
  late final DateTime _last;

  @override
  void initState() {
    super.initState();
    final end = widget.range.endDate;
    _last = DateTime(end.year, end.month, end.day);
    _first = DateTime(end.year, end.month, end.day - widget.range.days + 1);
    final initial = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _date = initial.isBefore(_first)
        ? _first
        : initial.isAfter(_last)
        ? _last
        : initial;
    _pulse = widget.pulse;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _first,
      lastDate: _last,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = TrendQuery.custom(_date, _date, arm: widget.range.arm);
    final data = ref.watch(trendDataProvider(query));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dayTrendTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l10n.previousDay,
                icon: const Icon(Icons.chevron_left),
                onPressed: _date.isAfter(_first)
                    ? () => setState(
                        () => _date = DateTime(
                          _date.year,
                          _date.month,
                          _date.day - 1,
                        ),
                      )
                    : null,
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(Fmt.day(_date)),
              ),
              IconButton(
                tooltip: l10n.nextDay,
                icon: const Icon(Icons.chevron_right),
                onPressed: _date.isBefore(_last)
                    ? () => setState(
                        () => _date = DateTime(
                          _date.year,
                          _date.month,
                          _date.day + 1,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          Center(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.seriesBp)),
                ButtonSegment(value: true, label: Text(l10n.seriesPulse)),
              ],
              selected: {_pulse},
              onSelectionChanged: (values) =>
                  setState(() => _pulse = values.first),
            ),
          ),
          const SizedBox(height: 16),
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(l10n.trendLoadFailed('$error')),
            data: (days) => days.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.noMeasurementsThisDay)),
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: (MediaQuery.sizeOf(context).height * 0.55)
                            .clamp(380.0, 480.0),
                        child: _pulse
                            ? PulseTrendChart(
                                points: days,
                                query: query,
                                measurementOrder: true,
                              )
                            : MeasurementTrendChart(
                                points: days,
                                query: query,
                                measurementOrder: true,
                              ),
                      ),
                      const Divider(height: 28),
                      for (final record in days.expand((d) => d.records))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${Fmt.time(record.measuredAt)} · ${record.systolic ?? '—'}/${record.diastolic ?? '—'} mmHg',
                          ),
                          subtitle: Text(
                            '${l10n.pulsePressure}: ${record.pulsePressure ?? '—'} mmHg · ${l10n.seriesPulse}: ${record.pulse ?? '—'}',
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RecordEditPage(existing: record),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

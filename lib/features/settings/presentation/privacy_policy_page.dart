import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:blood_pressed/l10n/app_localizations.dart';

/// Offline policy, rendered from the same source as the public static page.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final Future<Map<String, dynamic>> _policy = rootBundle
      .loadString('assets/legal/privacy-policy.zh.json')
      .then((value) => jsonDecode(value) as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _policy,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.privacyPolicyLoadError));
          }
          final policy = snapshot.data;
          if (policy == null) {
            return const Center(child: CircularProgressIndicator());
          }
          Widget paragraph(String text, {bool bold = false}) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.7,
                fontWeight: bold ? FontWeight.bold : null,
              ),
            ),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy['title'] as String,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                paragraph(
                  '更新日期：${policy['updated']}　生效日期：${policy['effective']}',
                ),
                paragraph('运营者：${policy['operator']}'),
                paragraph(policy['contact'] as String),
                paragraph(policy['intro'] as String),
                paragraph(policy['sensitive'] as String, bold: true),
                for (final section in policy['sections'] as List) ...[
                  Text(
                    section['title'] as String,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final text in section['paragraphs'] as List)
                    paragraph(text as String),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

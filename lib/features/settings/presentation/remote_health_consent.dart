import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

Future<bool> ensureRemoteHealthConsent(
  BuildContext context,
  WidgetRef ref,
) async {
  final profile = ref.read(effectiveLlmProfileProvider);
  if (profile == null || profile.kind == LlmKind.local) return true;
  final settings = ref.read(appSettingsProvider);
  if (settings.hasRemoteConsent(profile)) return true;
  final l10n = AppLocalizations.of(context);
  if (!profile.healthDisclosureComplete) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.remoteConsentTitle),
        content: Text(l10n.remoteDisclosureMissing),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.privacyDecline),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/llm');
            },
            child: Text(l10n.goConfigure),
          ),
        ],
      ),
    );
    return false;
  }
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.remoteConsentTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              '${profile.recipientName}\n${profile.baseUrl}\n${profile.remoteModel}\n${profile.recipientPolicyUrl}',
            ),
            const SizedBox(height: 16),
            Text(l10n.remoteConsentBody),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.privacyDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.remoteConsentAccept),
        ),
      ],
    ),
  );
  if (agreed != true || !context.mounted || !settings.hasPrivacyConsent) {
    return false;
  }
  // A profile may change while the disclosure is open. Never authorize a replacement.
  final current = ref.read(effectiveLlmProfileProvider);
  if (current == null ||
      settings.remoteConsentKey(current) !=
          settings.remoteConsentKey(profile)) {
    return false;
  }
  await settings.allowRemote(profile);
  return true;
}

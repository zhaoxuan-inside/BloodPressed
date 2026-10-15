import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/settings/presentation/privacy_policy_page.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

final withdrawPrivacyProvider = Provider<Future<void> Function()>(
  (ref) => throw StateError('Privacy startup callback is required'),
);

/// No business ProviderScope, database or platform SDK is mounted before consent.
class PrivacyStartup extends StatefulWidget {
  const PrivacyStartup({
    super.key,
    required this.settings,
    required this.initialize,
    this.cleanup,
  });
  final AppSettings settings;
  final Future<Widget> Function(Future<void> Function() withdraw) initialize;
  final Future<void> Function()? cleanup;
  @override
  State<PrivacyStartup> createState() => _PrivacyStartupState();
}

class _PrivacyStartupState extends State<PrivacyStartup> {
  Future<Widget>? _app;
  bool _busy = false;
  bool _refused = false;
  @override
  void initState() {
    super.initState();
    if (widget.settings.hasPrivacyConsent) _app = widget.initialize(_withdraw);
  }

  Future<void> _withdraw() async {
    await widget.settings.withdrawPrivacy();
    if (!mounted) return;
    setState(() {
      _app = null;
      _busy = true;
    });
    // Removing the business tree disposes streaming, model and router state.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await widget.cleanup?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.settings.acceptPrivacy();
      if (mounted) {
        final app = widget.initialize(_withdraw);
        setState(() {
          _app = app;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = widget.settings.localePref;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: pref == 'system' ? null : Locale(pref),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          if (_app != null) {
            return FutureBuilder<Widget>(
              future: _app,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.privacyStartupError),
                          TextButton(
                            onPressed: _withdraw,
                            child: Text(l10n.privacyWithdraw),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return snapshot.data ??
                    const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
              },
            );
          }
          return PopScope(
            canPop: false,
            child: Scaffold(
              appBar: AppBar(title: Text(l10n.privacyWelcomeTitle)),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Icon(Icons.health_and_safety_outlined, size: 56),
                    const SizedBox(height: 24),
                    Text(
                      l10n.privacyWelcomeBody,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      ),
                      child: Text(l10n.privacyPolicy),
                    ),
                    if (_refused)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(l10n.privacyRefused),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _accept,
                      child: Text(l10n.privacyAccept),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _refused = true),
                      child: Text(l10n.privacyDecline),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

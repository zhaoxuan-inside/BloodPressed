import 'package:flutter/material.dart';
import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/settings/presentation/privacy_policy_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/llm/presentation/controllers/llm_providers.dart';
import 'package:blood_pressed/features/llm/domain/inference_engine.dart';

import 'package:blood_pressed/features/settings/data/app_settings.dart';
import 'package:blood_pressed/features/settings/presentation/privacy_startup.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = AppSettings(await SharedPreferences.getInstance());
    await settings.setLocalePref('zh');
  });
  const remote = LlmProfile(
    id: 'r',
    kind: LlmKind.remote,
    name: 'Provider',
    config: {
      'baseUrl': 'https://example.com/v1',
      'model': 'a',
      'recipientName': 'Example',
      'recipientPolicyUrl': 'https://example.com/privacy',
      'recipientRegion': 'mainland',
    },
  );

  test(
    'unknown, overseas and insecure recipients cannot obtain health grants',
    () async {
      await settings.acceptPrivacy();
      for (final changes in [
        {'recipientRegion': 'unknown'},
        {'recipientRegion': 'overseas'},
        {'baseUrl': 'http://example.com/v1'},
        {'recipientName': ''},
        {'baseUrl': 'https://secret@example.com/v1'},
      ]) {
        final invalid = remote.copyWithConfig(changes);
        await expectLater(settings.allowRemote(invalid), throwsStateError);
        expect(settings.hasRemoteConsent(invalid), isFalse);
      }
    },
  );

  test(
    'engine rejects unconsented or changed recipient before network access',
    () async {
      await settings.acceptPrivacy();
      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(settings),
          llmEngineProvider.overrideWith((ref) => LlmEngineController(ref)),
        ],
      );
      addTearDown(container.dispose);
      final engine = container.read(llmEngineProvider.notifier);
      await engine.activate(remote);
      await expectLater(
        engine.chatStream([]).toList(),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.message,
            'consent guard',
            AppLocaleService.auto.remoteConsentRequired,
          ),
        ),
      );
      await settings.allowRemote(remote);
      final changed = remote.copyWithConfig({
        'baseUrl': 'https://other.example/v1',
      });
      await engine.activate(changed);
      await expectLater(
        engine.chatStream([]).toList(),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.message,
            'recipient guard',
            AppLocaleService.auto.remoteConsentRequired,
          ),
        ),
      );
      await settings.withdrawRemote();
      await engine.activate(remote);
      await expectLater(
        engine.chatStream([]).toList(),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.message,
            'revocation guard',
            AppLocaleService.auto.remoteConsentRequired,
          ),
        ),
      );
    },
  );

  test('separate remote grants bind to recipient and model; withdrawal clears them', () async {
    expect(settings.hasPrivacyConsent, isFalse);
    expect(settings.hasRemoteConsent(remote), isFalse);
    await settings.acceptPrivacy();
    await settings.allowRemote(remote);
    expect(settings.hasRemoteConsent(remote), isTrue);
    expect(
      settings.hasRemoteConsent(
        remote.copyWithConfig({'baseUrl': 'https://other.com/v1'}),
      ),
      isFalse,
    );
    expect(
      settings.hasRemoteConsent(remote.copyWithConfig({'model': 'b'})),
      isFalse,
    );
    await settings.withdrawPrivacy();
    expect(settings.hasPrivacyConsent, isFalse);
    await settings.acceptPrivacy();
    expect(settings.hasRemoteConsent(remote), isFalse);
  });

  testWidgets(
    'policy and refusal do not initialize business; accept does; withdraw unmounts it',
    (tester) async {
      var starts = 0;
      Future<void> Function()? withdraw;
      await tester.pumpWidget(
        PrivacyStartup(
          settings: settings,
          initialize: (callback) async {
            starts++;
            withdraw = callback;
            return const MaterialApp(home: Text('business'));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, 0);
      await tester.tap(find.text('隐私政策'));
      await tester.pumpAndSettle();
      expect(find.text('运营者：赵宣'), findsOneWidget);
      expect(starts, 0);
      Navigator.of(tester.element(find.byType(PrivacyPolicyPage))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('暂不同意'));
      await tester.pumpAndSettle();
      expect(starts, 0);
      expect(settings.hasPrivacyConsent, isFalse);
      await tester.tap(find.text('同意并进入'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.text('business'), findsOneWidget);
      final withdrawal = withdraw!();
      await tester.pumpAndSettle();
      await withdrawal;
      expect(find.text('business'), findsNothing);
      expect(settings.hasPrivacyConsent, isFalse);
    },
  );
}

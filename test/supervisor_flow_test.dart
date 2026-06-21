// User-usage E2E for the SUPERVISOR-in-context flow, driven through the real
// widgets against a live API: a cashier applies a discount above the cap, the
// supervisor approval dialog appears, the supervisor authorizes it (verified
// live), the discount is applied, and the discounted sale completes.
//
// Opt-in (needs the API up + cashier "kasiruji/kasir123" + supervisor
// "supuji/super123" + a product priced 12000):
//   flutter test test/supervisor_flow_test.dart --dart-define=RUN_LIVE_API_TESTS=true
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elkasir_pos/features/app_controller.dart';
import 'package:elkasir_pos/main.dart';
import 'package:elkasir_pos/models/pos_models.dart';
import 'package:elkasir_pos/services/api/api_client.dart';
import 'package:elkasir_pos/services/api/api_providers.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8081/api/v1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const runLive = bool.fromEnvironment('RUN_LIVE_API_TESTS');
  if (!runLive) {
    test(
      'supervisor approval UI flow (skipped)',
      () {},
      skip:
          'Run with --dart-define=RUN_LIVE_API_TESTS=true and the API up (cashier + supervisor + product seeded).',
    );
    return;
  }

  testWidgets(
    'cashier applies an over-cap discount → supervisor approves → discounted sale completes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final realHttp = IOClient(_RealHttpOverrides().createHttpClient(null));
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: _baseUrl,
              tokens: ref.read(tokenStoreProvider),
              client: realHttp,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      PosAppState st() => container.read(appControllerProvider);

      Finder buttonText(String t) => find.ancestor(
        of: find.text(t),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );

      // Tap a network-triggering widget inside runAsync (so its real timers fire),
      // wait for [done], then settle.
      Future<void> tapAndWait(
        Finder finder,
        bool Function() done, {
        int seconds = 30,
      }) async {
        await tester.runAsync(() async {
          await tester.tap(finder);
          final deadline = DateTime.now().add(Duration(seconds: seconds));
          while (!done() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        });
        await tester.pumpAndSettle();
      }

      // Tap a widget that triggers a network call whose RESULT is consumed by a
      // fake-zoned continuation (e.g. an awaited dialog): tap inside runAsync,
      // let the network drain, then settle so the continuation runs.
      Future<void> tapAndDrain(Finder finder, {int ms = 2500}) async {
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(Duration(milliseconds: ms));
        });
        await tester.pumpAndSettle();
      }

      await tester.runAsync(() => bootstrapApp());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ElkasirPosApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Login (cashier) → open shift → add a product (subtotal 12000).
      await tester.enterText(find.byType(TextField).at(0), 'kasiruji');
      await tester.enterText(find.byType(TextField).at(1), 'kasir123');
      await tester.pump();
      await tapAndWait(
        find.text('Masuk'),
        () => st().isAuthenticated && st().products.isNotEmpty,
      );
      await tester.enterText(find.byType(TextField).at(0), '100000');
      await tester.pump();
      await tapAndWait(find.text('Buka Shift & Masuk Kasir'), () => st().hasOpenShift);
      await tester.tap(find.text('Kopi Uji').first);
      await tester.pump();
      expect(st().subtotal, 12000);

      // Open the discount dialog and request 5000 (> 10% cap of 1200).
      await tester.tap(buttonText('Diskon'));
      await tester.pumpAndSettle();
      final discountDialog = find.widgetWithText(AlertDialog, 'Terapkan diskon');
      await tester.enterText(
        find.descendant(of: discountDialog, matching: find.byType(TextField)),
        '5000',
      );
      await tester.pump();
      await tester.tap(buttonText('Terapkan')); // > cap → supervisor approval
      await tester.pumpAndSettle();

      // Supervisor approval dialog appears → authorize with supervisor creds.
      final approval = find.widgetWithText(AlertDialog, 'Persetujuan Supervisor');
      expect(approval, findsOneWidget, reason: 'over-cap discount needs approval');
      final approvalFields = find.descendant(
        of: approval,
        matching: find.byType(TextField),
      );
      await tester.enterText(approvalFields.at(0), 'supuji');
      await tester.enterText(approvalFields.at(1), 'super123');
      await tester.pump();
      await tapAndDrain(
        find.descendant(of: approval, matching: find.text('Setujui')),
      );

      // Discount applied with the supervisor recorded as approver.
      expect(st().discount, 5000, reason: 'approved discount should apply in full');
      expect(st().discountApprovedBy, 'Supervisor Uji');
      expect(find.byType(AlertDialog), findsNothing, reason: 'dialogs closed');

      // Complete the discounted sale; the server accepts the over-cap discount
      // because an approver is attached.
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();
      expect(st().screen, AppScreen.checkout);
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.pump();
      await tapAndWait(
        find.text('Bayar Tunai'),
        () => st().screen == AppScreen.receipt,
      );
      expect(st().lastTransaction, isNotNull);
      expect(st().lastTransaction!.discount, 5000);
      expect(st().lastTransaction!.total, 12000 - 5000, reason: 'discount applied to total');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Default overrides → a real platform HttpClient (opts back into real
/// networking inside flutter_test, which otherwise stubs all HTTP).
class _RealHttpOverrides extends HttpOverrides {}

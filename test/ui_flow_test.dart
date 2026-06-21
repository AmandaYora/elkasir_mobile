// User-usage E2E: drives the REAL app widget tree (taps, text entry, navigation)
// against a running Elkasir API — a cashier's full journey through the screens.
//
// Opt-in (needs the API up + a cashier "kasiruji/kasir123" + a product + a table):
//   flutter test test/ui_flow_test.dart --dart-define=RUN_LIVE_API_TESTS=true
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
      'UI flow E2E (skipped)',
      () {},
      skip:
          'Run with --dart-define=RUN_LIVE_API_TESTS=true and the API up (cashier + product + table seeded).',
    );
    return;
  }

  testWidgets(
    'cashier journey: login → open shift → sale → receipt → cash movement → close → logout',
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

      // Match the button carrying [t] (screen titles can repeat the same label).
      Finder buttonText(String t) => find.ancestor(
        of: find.text(t),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );

      // Tap a widget that triggers a real network call, then wait for [done].
      // The tap runs INSIDE runAsync so the request's real timers actually fire
      // (flutter_test's fake clock would otherwise hang the socket).
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

      await tester.runAsync(() => bootstrapApp());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ElkasirPosApp(),
        ),
      );
      await tester.pumpAndSettle();

      // ── 1) LOGIN ──────────────────────────────────────────────────────────
      expect(find.text('Masuk Staf'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'kasiruji');
      await tester.enterText(find.byType(TextField).at(1), 'kasir123');
      await tester.pump();
      await tapAndWait(
        find.text('Masuk'),
        () => st().isAuthenticated && st().products.isNotEmpty,
      );
      expect(st().isAuthenticated, isTrue, reason: 'login should authenticate');
      expect(st().products, isNotEmpty, reason: 'catalog should load from API');

      // ── 2) OPEN SHIFT ─────────────────────────────────────────────────────
      expect(find.textContaining('Buka Shift'), findsWidgets);
      await tester.enterText(find.byType(TextField).at(0), '100000');
      await tester.pump();
      await tapAndWait(
        find.text('Buka Shift & Masuk Kasir'),
        () => st().hasOpenShift,
      );
      expect(st().hasOpenShift, isTrue, reason: 'shift should open on server');
      expect(st().currentShift!.initialCash, 100000);

      // ── 3) POS — add a product to the cart ────────────────────────────────
      expect(find.text('Kopi Uji'), findsWidgets);
      await tester.tap(find.text('Kopi Uji').first);
      await tester.pump();
      expect(st().cart, isNotEmpty, reason: 'product should be in the cart');
      expect(st().total, 12000);

      // ── 4) CHECKOUT — cash payment ────────────────────────────────────────
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();
      expect(st().screen, AppScreen.checkout);
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.pump();
      await tapAndWait(
        find.text('Bayar Tunai'),
        () => st().screen == AppScreen.receipt,
      );
      expect(st().lastTransaction, isNotNull, reason: 'sale should be created');
      expect(st().lastTransaction!.code, startsWith('TRX-'));
      expect(st().lastTransaction!.change, 50000 - 12000);

      // ── 5) CASH MOVEMENT — additional capital ─────────────────────────────
      await tester.tap(find.byKey(const ValueKey('nav-cash-movements')));
      await tester.pumpAndSettle();
      expect(st().screen, AppScreen.cashMovements);
      final cmBefore = st().cashMovements.length;
      await tester.tap(find.text('Mutasi Baru'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '50000');
      await tester.pump();
      await tapAndWait(
        find.text('Simpan Mutasi'),
        () => st().cashMovements.length > cmBefore,
      );
      expect(st().cashMovements.first.amount, 50000);

      // ── 6) CLOSE SHIFT — reach the screen, count the drawer, reconcile ────
      // (The server-side close itself is covered by the live cashier-flow test
      //  in api_integration_test.dart; here we verify the close UI + blind-count
      //  reconciliation dialog up to confirmation.)
      final expectedCash = st().currentShift!.expectedCash; // 100000+12000+50000
      await tester.tap(find.byKey(const ValueKey('nav-close-shift')));
      await tester.pumpAndSettle();
      expect(st().screen, AppScreen.closeShift);
      await tester.enterText(find.byType(TextField).at(0), '$expectedCash');
      await tester.pump();
      await tester.tap(buttonText('Tutup Shift')); // main button → confirm dialog
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Selisih'), findsWidgets,
          reason: 'reconciliation dialog should show the variance');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // ── 7) LOGOUT ─────────────────────────────────────────────────────────
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Keluar'));
        // Let the fire-and-forget token revoke finish so no real timer dangles.
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();
      expect(st().isAuthenticated, isFalse);
      expect(find.text('Masuk Staf'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Default overrides → a real platform HttpClient (opts back into real
/// networking inside flutter_test, which otherwise stubs all HTTP).
class _RealHttpOverrides extends HttpOverrides {}

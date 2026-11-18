import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/services/app_limits_service.dart';
import 'package:redemption/state/providers.dart';

import '../support/harness.dart';

/// Keeps limits like the phone does: once set, only ever lower.
class FakeAppLimits implements AppLimitsService {
  var quotas = <String, int>{};
  var used = <String, Duration>{};
  var guard = true;
  final saved = <Map<String, int>>[];

  @override
  bool get isSupported => true;

  @override
  Future<AppLimitsState> load() async => AppLimitsState(
    quotas: Map.of(quotas),
    used: Map.of(used),
    guard: guard,
    autoTime: true,
  );

  @override
  Future<String?> lock(Map<String, int> wanted) async {
    for (final MapEntry(:key, :value) in quotas.entries) {
      final n = wanted[key];
      if (n == null) return 'A locked limit can’t be removed.';
      if (n > value) return 'A locked limit can’t be raised.';
    }
    saved.add(Map.of(wanted));
    quotas = Map.of(wanted);
    return null;
  }

  @override
  Future<void> openSystemSetting(String which) async {}
}

void main() {
  /// Scrolls the limits list until [f] shows.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
  }

  Future<void> tapIn(WidgetTester tester, Finder f) async {
    await reveal(tester, f);
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> openLimits(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Daily app limits'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(find.text('Daily app limits'));
    await settle(tester);
  }

  testWidgets('limits are chosen, locked for good, and can only get stricter', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final limits = FakeAppLimits();

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [appLimitsServiceProvider.overrideWithValue(limits)],
      ),
    );
    await settle(tester);
    await openLimits(tester);

    // Instagram at 15 min, YouTube blocked all day.
    await tapIn(tester, find.text('Instagram'));
    expect(find.text('30 min a day'), findsOneWidget);
    await tapIn(tester, find.byTooltip('Fewer minutes for Instagram'));
    await tapIn(tester, find.byTooltip('Fewer minutes for Instagram'));
    expect(find.text('15 min a day'), findsOneWidget);
    await tapIn(tester, find.text('YouTube'));
    for (var i = 0; i < 6; i++) {
      await tapIn(tester, find.byTooltip('Fewer minutes for YouTube'));
    }
    expect(find.text('Blocked all day'), findsOneWidget);

    await tapIn(tester, find.text('Lock limits'));
    expect(find.textContaining('can never be raised or removed'), findsWidgets);
    await tester.tap(find.text('Lock for good'));
    await settle(tester);
    expect(limits.saved.single, {'instagram': 15, 'youtube': 0});

    // Locked: no way to add minutes, only to take them away.
    expect(find.byTooltip('More minutes for Instagram'), findsNothing);
    await reveal(tester, find.text('0 min of 15 min used today'));
    expect(find.byTooltip('Make YouTube stricter'), findsNothing);
    await tapIn(tester, find.byTooltip('Make Instagram stricter'));
    expect(find.text('20 min'), findsNothing, reason: 'nothing above 15');
    await tester.tap(find.text('10 min'));
    await settle(tester);
    await tester.tap(find.text('Make stricter'));
    await settle(tester);
    expect(limits.saved.last, {'instagram': 10, 'youtube': 0});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a used-up app says so, and nothing locks without the guard', (
    tester,
  ) async {
    usePhoneSurface(tester, textScale: 1.3);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final limits = FakeAppLimits()
      ..quotas = {'spotify': 30}
      ..used = {'spotify': const Duration(minutes: 31)}
      ..guard = false;

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [appLimitsServiceProvider.overrideWithValue(limits)],
      ),
    );
    await settle(tester);
    await openLimits(tester);

    await reveal(tester, find.text('Used up — opens again after midnight'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
    await settle(tester);
    await tapIn(tester, find.text('Chrome'));
    await reveal(tester, find.text('Lock limits'));
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Lock limits'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Turn on the alarm guard first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

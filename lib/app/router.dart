import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/dashboard/dashboard_editor_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/insights/tracker_detail_screen.dart';
import '../features/journey/journey_editor_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/diagnostics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../features/trackers/plan_screen.dart';
import '../features/trackers/tracker_editor_screen.dart';
import '../state/providers.dart';
import 'shell.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const dashboardEdit = '/dashboard/edit';
  static const today = '/today';
  static const insights = '/insights';
  static String trackerDetail(int id) => '/insights/tracker/$id';
  static const plan = '/plan';
  static const newTracker = '/plan/tracker/new';
  static String editTracker(int id) => '/plan/tracker/$id';
  static const editJourney = '/plan/journey';
  static const newJourney = '/plan/journey/new';
  static const settings = '/settings';
  static const diagnostics = '/settings/diagnostics';
  static const about = '/settings/about';

  /// Today tab, opening the entry sheet of [trackerId].
  static String logTracker(int trackerId) => '$today?log=$trackerId';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(activeJourneyProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final journeyAsync = ref.read(activeJourneyProvider);
      if (journeyAsync.isLoading && !journeyAsync.hasValue) return null;
      final hasJourney = journeyAsync.value != null;
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!hasJourney && !atOnboarding) return Routes.onboarding;
      if (hasJourney && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'dashboard/edit',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const DashboardEditorScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (_, state) => TodayScreen(
                  openTrackerId: int.tryParse(
                    state.uri.queryParameters['log'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.insights,
                builder: (_, _) => const InsightsScreen(),
                routes: [
                  GoRoute(
                    path: 'tracker/:id',
                    builder: (_, state) => TrackerDetailScreen(
                      trackerId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plan,
                builder: (_, _) => const PlanScreen(),
                routes: [
                  GoRoute(
                    path: 'tracker/new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const TrackerEditorScreen(),
                  ),
                  GoRoute(
                    path: 'tracker/:id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => TrackerEditorScreen(
                      trackerId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'journey',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const JourneyEditorScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootKey,
                        builder: (_, _) =>
                            const JourneyEditorScreen(startNew: true),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'diagnostics',
            builder: (_, _) => const DiagnosticsScreen(),
          ),
          GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

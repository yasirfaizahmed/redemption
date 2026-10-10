import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/widgets/common.dart';
import '../../domain/dashboard.dart';
import '../../state/providers.dart';
import 'widgets/dashboard_cards.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String greeting(int hour) {
    if (hour >= 3 && hour < 12) return 'Rise and conquer';
    if (hour >= 12 && hour < 17) return 'Stay consistent';
    if (hour >= 17 && hour < 22) return 'Finish strong';
    return 'Rest is part of the work';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(dashboardItemsProvider);
    final now = ref.watch(clockProvider);
    final journey = ref.watch(activeJourneyProvider).value;
    final items = itemsAsync.value ?? const <DashboardItem>[];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting(now.hour).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.6,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Redemption',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Customise dashboard',
            onPressed: () => context.push(Routes.dashboardEdit),
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: journey == null || !itemsAsync.hasValue
          ? const SizedBox.shrink()
          : items.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.dashboard_customize_rounded,
                title: 'Your dashboard is empty',
                message: 'Add the widgets you want to see every time you open the app.',
                action: FilledButton.icon(
                  onPressed: () => context.push(Routes.dashboardEdit),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add widgets'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                for (final row in layoutRows(items))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: row.length == 1
                        ? DashboardWidgetView(item: row.first)
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: DashboardWidgetView(
                                    item: row[0],
                                    half: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DashboardWidgetView(
                                    item: row[1],
                                    half: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
              ],
            ),
    );
  }

  /// Pairs consecutive half-width widgets into rows; a lone half widget
  /// expands to full width.
  static List<List<DashboardItem>> layoutRows(List<DashboardItem> items) {
    final rows = <List<DashboardItem>>[];
    DashboardItem? pending;
    for (final item in items) {
      if (item.isHalf) {
        if (pending == null) {
          pending = item;
        } else {
          rows.add([pending, item]);
          pending = null;
        }
      } else {
        if (pending != null) {
          rows.add([pending]);
          pending = null;
        }
        rows.add([item]);
      }
    }
    if (pending != null) rows.add([pending]);
    return rows;
  }
}

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../state/providers.dart';
import 'theme/palette.dart';

/// Bottom-navigation scaffold hosting the four main tabs.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == 1) ref.read(selectedDayProvider.notifier).select(null);
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(celebrationProvider, (_, _) {
      if (MediaQuery.of(context).disableAnimations) return;
      _confetti.play();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfect day! Alhamdulillah — the new pathway grows.'),
        ),
      );
    });
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Scaffold(
          body: widget.shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: widget.shell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today_rounded),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Plan',
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 24,
              gravity: 0.25,
              colors: [
                scheme.primary,
                scheme.tertiary,
                Palette.gold,
                Palette.success,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

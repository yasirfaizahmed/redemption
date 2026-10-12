import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router.dart';
import '../../app/theme/palette.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../domain/app_settings.dart';
import '../../domain/formatting.dart';
import '../../state/providers.dart';
import 'app_update_ui.dart';
import 'backup_import.dart';
import 'drive_backup.dart';

final _log = Logger('Settings');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings Function(AppSettings) f) =>
      ref
          .read(settingsRepositoryProvider)
          .save(f(ref.read(settingsValueProvider)));

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref.read(backupServiceProvider).exportZip();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Redemption backup'),
      );
    } catch (e, s) {
      _log.severe('Backup export failed', e, s);
      if (context.mounted) showSnack(context, 'Export failed: $e');
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final journey = ref.read(activeJourneyProvider).value;
    if (journey == null) return;
    try {
      final file = await ref
          .read(backupServiceProvider)
          .exportCsv(
            journey,
            dayStartMinutes: ref.read(settingsValueProvider).dayStartMinutes,
          );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: journey.name,
        ),
      );
    } catch (e, s) {
      _log.severe('CSV export failed', e, s);
      if (context.mounted) showSnack(context, 'Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(settingsValueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) =>
                  _update(ref, (x) => x.copyWith(themeMode: v.first)),
            ),
          ),
          SwitchListTile(
            title: const Text('Pure black dark mode'),
            subtitle: const Text('Saves battery on OLED screens'),
            value: s.pureBlack,
            onChanged: (v) => _update(ref, (x) => x.copyWith(pureBlack: v)),
          ),
          SwitchListTile(
            title: const Text('Use wallpaper colours'),
            subtitle: const Text('Material You dynamic colour (Android 12+)'),
            value: s.useDynamicColor,
            onChanged: (v) =>
                _update(ref, (x) => x.copyWith(useDynamicColor: v)),
          ),
          if (!s.useDynamicColor)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in Palette.seeds.entries)
                    Tooltip(
                      message: e.key,
                      child: Semantics(
                        button: true,
                        selected: s.seedColor == e.value,
                        label: '${e.key} accent',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _update(
                            ref,
                            (x) => x.copyWith(seedColor: e.value),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(e.value),
                            child: s.seedColor == e.value
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('24-hour clock'),
            value: s.use24h,
            onChanged: (v) => _update(ref, (x) => x.copyWith(use24h: v)),
          ),

          const SectionHeader('Day & scoring'),
          ListTile(
            leading: const Icon(Icons.nights_stay_outlined),
            title: const Text('Day starts at'),
            subtitle: Text(
              '${Clock.format(s.dayStartMinutes, use24h: s.use24h)} — late nights count for the previous day',
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: Clock.toTimeOfDay(s.dayStartMinutes),
              );
              if (picked != null) {
                await _update(
                  ref,
                  (x) =>
                      x.copyWith(dayStartMinutes: Clock.fromTimeOfDay(picked)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('A day is “won” at'),
            subtitle: Text(
              '${Fmt.percent(s.successThreshold)} of the daily score',
            ),
          ),
          Slider(
            value: s.successThreshold,
            min: 0.5,
            divisions: 10,
            label: Fmt.percent(s.successThreshold),
            onChanged: (v) =>
                _update(ref, (x) => x.copyWith(successThreshold: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Haptic feedback'),
            value: s.haptics,
            onChanged: (v) => _update(ref, (x) => x.copyWith(haptics: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.celebration_outlined),
            title: const Text('Celebrate perfect days'),
            value: s.celebrations,
            onChanged: (v) => _update(ref, (x) => x.copyWith(celebrations: v)),
          ),

          const SectionHeader('Motivation'),
          RadioGroup<QuotePack>(
            groupValue: s.quotePack,
            onChanged: (v) => _update(ref, (x) => x.copyWith(quotePack: v)),
            child: Column(
              children: [
                for (final p in QuotePack.values)
                  RadioListTile<QuotePack>(value: p, title: Text(p.label)),
              ],
            ),
          ),

          const SectionHeader('Reminders'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Evening check-in'),
            subtitle: Text(
              s.checkInEnabled
                  ? 'Every day at ${Clock.format(s.checkInMinutes, use24h: s.use24h)}'
                  : 'One nudge to complete the day',
            ),
            value: s.checkInEnabled,
            onChanged: (v) async {
              if (v) {
                await ref.read(notificationServiceProvider).requestPermission();
              }
              await _update(ref, (x) => x.copyWith(checkInEnabled: v));
            },
          ),
          if (s.checkInEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Check-in time'),
              trailing: Text(Clock.format(s.checkInMinutes, use24h: s.use24h)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: Clock.toTimeOfDay(s.checkInMinutes),
                );
                if (picked != null) {
                  await _update(
                    ref,
                    (x) =>
                        x.copyWith(checkInMinutes: Clock.fromTimeOfDay(picked)),
                  );
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.alarm_on_rounded),
            title: const Text('Precise reminders'),
            subtitle: const Text(
              'Allow exact alarms so prayer reminders are on time',
            ),
            onTap: () =>
                ref.read(notificationServiceProvider).requestExactAlarms(),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Send a test notification'),
            onTap: () async {
              final n = ref.read(notificationServiceProvider);
              await n.requestPermission();
              await n.showTest();
            },
          ),

          const SectionHeader('Journey'),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Edit current journey'),
            onTap: () => context.push(Routes.editJourney),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Start a new journey'),
            subtitle: const Text('Keep history, optionally copy your trackers'),
            onTap: () => context.push(Routes.newJourney),
          ),

          const DriveBackupSection(),

          const SectionHeader('Your data'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Export full backup'),
            subtitle: const Text(
              'ZIP with all data and photos — keep it safe, or import it on '
              'another phone',
            ),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Import data'),
            subtitle: const Text(
              'From a backup file (ZIP or JSON) made by any version',
            ),
            onTap: () => importBackupFile(context, ref, replacing: true),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export current journey as CSV'),
            subtitle: const Text('Analyse in Sheets, Excel or pandas'),
            onTap: () => _exportCsv(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Your data lives on this phone. Nothing leaves it unless you turn '
              'on Google Drive backup or export it yourself. No ads, no tracking.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const AppUpdateSection(),

          const SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Diagnostics'),
            subtitle: const Text('Logs, storage and reminder status'),
            onTap: () => context.push(Routes.diagnostics),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('The science & the motto'),
            onTap: () => context.push(Routes.about),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Redemption',
            ),
          ),
        ],
      ),
    );
  }
}

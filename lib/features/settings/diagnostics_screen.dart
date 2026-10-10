import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/logging/app_logger.dart';
import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../state/providers.dart';

class _Diagnostics {
  const _Diagnostics({
    required this.version,
    required this.journeys,
    required this.trackers,
    required this.entries,
    required this.dbBytes,
    required this.attachmentBytes,
    required this.pendingReminders,
    required this.notificationsEnabled,
  });

  final String version;
  final int journeys;
  final int trackers;
  final int entries;
  final int dbBytes;
  final int attachmentBytes;
  final int pendingReminders;
  final bool? notificationsEnabled;
}

final _diagnosticsProvider = FutureProvider.autoDispose<_Diagnostics>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final notifications = ref.watch(notificationServiceProvider);
  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');
  final pages = (await db.customSelect('PRAGMA page_count').getSingle())
      .data
      .values
      .first;
  final pageSize =
      (await db.customSelect('PRAGMA page_size').getSingle()).data.values.first;
  String version;
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version} (${info.buildNumber})';
  } catch (_) {
    version = 'unknown';
  }
  int attachments;
  try {
    attachments = await ref.watch(attachmentStoreProvider).totalSize();
  } catch (_) {
    attachments = 0;
  }
  return _Diagnostics(
    version: version,
    journeys: await count('journeys'),
    trackers: await count('trackers'),
    entries: await count('entries'),
    dbBytes: (pages is int ? pages : 0) * (pageSize is int ? pageSize : 0),
    attachmentBytes: attachments,
    pendingReminders: await notifications.pendingCount(),
    notificationsEnabled: await notifications.areEnabled(),
  );
});

/// On-device observability: health, storage and the structured log stream.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  Level _minLevel = Level.INFO;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diag = ref.watch(_diagnosticsProvider);
    final logger = AppLogger.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_diagnosticsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          diag.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to collect diagnostics: $e'),
            data: (d) => MetricGrid(
              columns: 2,
              children: [
                MetricTile(
                  value: d.version,
                  label: 'App version',
                  icon: Icons.info_outline,
                ),
                MetricTile(
                  value: '${d.entries}',
                  label: '${d.journeys} journeys · ${d.trackers} trackers',
                  icon: Icons.storage_rounded,
                ),
                MetricTile(
                  value: Fmt.bytes(d.dbBytes),
                  label: 'Database',
                  icon: Icons.dns_outlined,
                ),
                MetricTile(
                  value: Fmt.bytes(d.attachmentBytes),
                  label: 'Photos & files',
                  icon: Icons.perm_media_outlined,
                ),
                MetricTile(
                  value: '${d.pendingReminders}',
                  label: 'Scheduled reminders',
                  icon: Icons.alarm_rounded,
                ),
                MetricTile(
                  value: switch (d.notificationsEnabled) {
                    true => 'On',
                    false => 'Blocked',
                    null => 'n/a',
                  },
                  label: 'Notification permission',
                  icon: Icons.notifications_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
            'Timezone: ${_tzName()}  ·  Locale: ${Platform.localeName}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(notificationServiceProvider)
                      .sync(
                        trackers: ref.read(activeTrackersProvider),
                        settings: ref.read(settingsValueProvider),
                      );
                  ref.invalidate(_diagnosticsProvider);
                  if (context.mounted) {
                    showSnack(context, 'Reminders rescheduled');
                  }
                },
                icon: const Icon(Icons.alarm_add_rounded),
                label: const Text('Reschedule reminders'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await logger.flush();
                  final file = logger.logFile;
                  if (file != null && file.existsSync()) {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path)],
                        subject: 'Redemption logs',
                      ),
                    );
                  } else {
                    await Clipboard.setData(ClipboardData(text: logger.dump()));
                    if (context.mounted) {
                      showSnack(context, 'Logs copied to clipboard');
                    }
                  }
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share logs'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await logger.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear logs'),
              ),
            ],
          ),
          const SectionHeader(
            'Log stream',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          ),
          SegmentedButton<Level>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Level.ALL, label: Text('All')),
              ButtonSegment(value: Level.INFO, label: Text('Info')),
              ButtonSegment(value: Level.WARNING, label: Text('Warn')),
              ButtonSegment(value: Level.SEVERE, label: Text('Error')),
            ],
            selected: {_minLevel},
            onSelectionChanged: (s) => setState(() => _minLevel = s.first),
          ),
          const SizedBox(height: 8),
          StreamBuilder<void>(
            stream: logger.changes,
            builder: (context, _) {
              final records = logger.records.reversed
                  .where((r) => r.level >= _minLevel)
                  .take(200)
                  .toList();
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No log records at this level.'),
                );
              }
              return Column(
                children: [
                  for (final r in records)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _levelColor(
                          r.level,
                          theme,
                        ).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: _levelColor(r.level, theme),
                            width: 3,
                          ),
                        ),
                      ),
                      child: SelectableText(
                        '${r.time.toIso8601String().substring(11, 19)}  ${r.level.name}  '
                        '[${r.loggerName}]\n${r.message}'
                        '${r.error != null ? '\n${r.error}' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _tzName() {
    try {
      return tz.local.name;
    } catch (_) {
      return DateTime.now().timeZoneName;
    }
  }

  static Color _levelColor(Level level, ThemeData theme) {
    if (level >= Level.SEVERE) return theme.colorScheme.error;
    if (level >= Level.WARNING) return Colors.orange;
    if (level >= Level.INFO) return theme.colorScheme.primary;
    return theme.colorScheme.outline;
  }
}

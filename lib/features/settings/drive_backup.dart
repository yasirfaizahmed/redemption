import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../services/drive/drive_backup_service.dart';
import '../../services/drive/google_drive_auth.dart';
import '../../state/drive_sync.dart';
import '../../state/providers.dart';

String _when(DateTime t, {required bool use24h}) =>
    DateFormat(use24h ? 'EEE d MMM yyyy · HH:mm' : 'EEE d MMM yyyy · h:mm a')
        .format(t);

void _snack(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Connects Google Drive from a user action.
///
/// If the account already holds backups, offers to restore one — on a fresh
/// install ([freshInstall]) that is the whole point. Otherwise this phone's
/// data is uploaded as the first backup. Returns true if data was restored.
Future<bool> connectGoogleDrive(
  BuildContext context,
  WidgetRef ref, {
  bool freshInstall = false,
}) async {
  final sync = ref.read(driveSyncProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final List<DriveBackup> backups;
  try {
    backups = await sync.connect();
  } on DriveConnectException catch (e) {
    if (!e.canceled) _snack(messenger, e.message);
    return false;
  }
  if (!context.mounted) return false;

  if (backups.isEmpty) {
    if (freshInstall) {
      _snack(
        messenger,
        'No backups in this Google account yet. Build your journey — '
        'it will be backed up automatically.',
      );
    } else {
      final ok = await sync.backupNow();
      _snack(
        messenger,
        ok
            ? 'Connected — your data is backed up to Google Drive.'
            : 'Connected to Google Drive.',
      );
    }
    return false;
  }

  if (!freshInstall) {
    final use24h = ref.read(settingsValueProvider).use24h;
    final restore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_done_outlined),
        title: const Text('Backups found'),
        content: Text(
          'This Google account already has ${backups.length} '
          '${backups.length == 1 ? 'backup' : 'backups'} (latest: '
          '${_when(backups.first.createdAt, use24h: use24h)}).\n\n'
          'Restore one now, or keep what’s on this phone and back it up?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep this phone’s data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore…'),
          ),
        ],
      ),
    );
    if (!context.mounted) return false;
    if (restore != true) {
      final ok = await sync.backupNow();
      if (ok) _snack(messenger, 'Backed up to Google Drive.');
      return false;
    }
  }
  return restoreFromDrive(
    context,
    ref,
    backups: backups,
    confirmReplace: !freshInstall,
  );
}

/// Lets the user pick a Drive snapshot and replaces local data with it.
/// Returns true if data was restored.
Future<bool> restoreFromDrive(
  BuildContext context,
  WidgetRef ref, {
  List<DriveBackup>? backups,
  bool confirmReplace = true,
}) async {
  final sync = ref.read(driveSyncProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(settingsValueProvider);
  final load = backups != null ? Future.value(backups) : sync.listBackups();
  final picked = await showModalBottomSheet<DriveBackup>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DriveRestoreSheet(
      backups: load,
      currentInstallId: settings.installId,
      use24h: settings.use24h,
    ),
  );
  if (picked == null || !context.mounted) return false;
  if (confirmReplace) {
    final ok = await confirm(
      context,
      title: 'Restore this backup?',
      message:
          'Everything on this phone — journeys, trackers, entries and photos — '
          'will be replaced with the backup from '
          '${_when(picked.createdAt, use24h: settings.use24h)}.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!ok) return false;
  }
  final notifications = ref.read(notificationServiceProvider);
  try {
    await sync.restore(picked);
    _snack(messenger, 'Backup restored — welcome back.');
    // On a fresh install onboarding (which normally asks) is skipped.
    if (!confirmReplace) await notifications.requestPermission();
    return true;
  } catch (e) {
    _snack(messenger, 'Restore failed: $e');
    return false;
  }
}

/// Bottom sheet listing Drive snapshots, newest first. Pops the chosen one.
class DriveRestoreSheet extends StatelessWidget {
  const DriveRestoreSheet({
    super.key,
    required this.backups,
    required this.currentInstallId,
    required this.use24h,
  });

  final Future<List<DriveBackup>> backups;
  final String currentInstallId;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Text(
            'Restore from Google Drive',
            style: theme.textTheme.titleLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Pick a snapshot — newest first.', style: muted),
        ),
        Flexible(
          child: FutureBuilder<List<DriveBackup>>(
            future: backups,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Text(
                    'Couldn’t load your backups: ${snap.error}',
                    style: muted,
                  ),
                );
              }
              final list = snap.data ?? const <DriveBackup>[];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Text(
                    'No backups in this Google account yet.',
                    style: muted,
                  ),
                );
              }
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final b in list)
                    ListTile(
                      leading: Icon(
                        b.installId.isNotEmpty &&
                                b.installId == currentInstallId
                            ? Icons.smartphone_rounded
                            : Icons.history_rounded,
                      ),
                      title: Text(_when(b.createdAt, use24h: use24h)),
                      subtitle: Text(
                        [
                          if (b.entries case final n?)
                            '${Fmt.number(n.toDouble())} '
                                '${n == 1 ? 'entry' : 'entries'}',
                          Fmt.bytes(b.sizeBytes),
                          if (b.installId.isNotEmpty &&
                              b.installId == currentInstallId)
                            'this phone',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, b),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The "Google Drive backup" block of the settings screen.
class DriveBackupSection extends ConsumerWidget {
  const DriveBackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(settingsValueProvider);
    final sync = ref.watch(driveSyncProvider);
    final auth = ref.watch(driveAuthProvider);
    final notifier = ref.read(driveSyncProvider.notifier);

    const spinner = SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );

    final children = <Widget>[const SectionHeader('Google Drive backup')];

    if (!auth.isSupported) {
      children.add(
        const ListTile(
          enabled: false,
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Google Drive backup'),
          subtitle: Text('Not available on this device'),
        ),
      );
    } else if (!s.driveConnected) {
      final connecting = sync.phase == DrivePhase.connecting;
      children.add(
        ListTile(
          leading: const Icon(Icons.add_to_drive_rounded),
          title: const Text('Back up to Google Drive'),
          subtitle: const Text(
            'Keep your journey safe if you lose, reset or change your phone',
          ),
          trailing: connecting
              ? spinner
              : FilledButton.tonal(
                  onPressed: sync.busy
                      ? null
                      : () => connectGoogleDrive(context, ref),
                  child: const Text('Connect'),
                ),
          onTap: sync.busy ? null : () => connectGoogleDrive(context, ref),
        ),
      );
    } else {
      final last = s.driveLastBackupAt;
      final status = switch (sync.phase) {
        DrivePhase.connecting => 'Connecting…',
        DrivePhase.backingUp => 'Backing up…',
        DrivePhase.restoring => 'Restoring…',
        DrivePhase.idle =>
          last == null ? 'Not backed up yet' : 'Last backup ${Fmt.ago(last)}',
      };
      children.addAll([
        ListTile(
          leading: Icon(Icons.cloud_done_outlined, color: scheme.primary),
          title: Text(s.driveEmail.isEmpty ? 'Connected' : s.driveEmail),
          subtitle: Text(status),
          trailing: sync.busy ? spinner : null,
        ),
        if (sync.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sync.lastError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
                if (sync.needsReconnect)
                  TextButton(
                    onPressed: sync.busy
                        ? null
                        : () async {
                            try {
                              await notifier.connect();
                              await notifier.backupNow();
                            } on DriveConnectException catch (e) {
                              if (context.mounted && !e.canceled) {
                                showSnack(context, e.message);
                              }
                            }
                          },
                    child: const Text('Reconnect'),
                  ),
              ],
            ),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.sync_rounded),
          title: const Text('Back up automatically'),
          subtitle: const Text(
            'A couple of minutes after changes, and when you leave the app',
          ),
          value: s.driveAutoBackup,
          onChanged: notifier.setAutoBackup,
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Back up now'),
          enabled: !sync.busy,
          onTap: () async {
            final ok = await notifier.backupNow();
            if (!context.mounted) return;
            showSnack(
              context,
              ok
                  ? 'Backed up to Google Drive'
                  : ref.read(driveSyncProvider).lastError ?? 'Backup failed',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('Restore from Google Drive'),
          subtitle: const Text('Replace this phone’s data with a backup'),
          enabled: !sync.busy,
          onTap: () => restoreFromDrive(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.link_off_rounded),
          title: const Text('Disconnect'),
          subtitle: const Text(
            'Stops backing up. Backups already in Drive are kept',
          ),
          enabled: !sync.busy,
          onTap: () async {
            final ok = await confirm(
              context,
              title: 'Disconnect Google Drive?',
              message:
                  'This phone stops backing up. Backups already in your Drive '
                  'stay there — connect again any time to restore them.',
              confirmLabel: 'Disconnect',
            );
            if (ok) await notifier.disconnect();
          },
        ),
      ]);
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Backups go to a hidden app folder in your own Google Drive that only '
          'Redemption can read. The 10 most recent are kept.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

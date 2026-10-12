import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../data/backup/backup_service.dart';
import '../../state/providers.dart';

final _log = Logger('Import');

/// A file the user picked: its name and content.
typedef PickedBackup = ({String name, List<int> bytes});

/// Opens the system file picker. Any file type is allowed — Android pickers
/// often don't map `.zip`/`.json` to a filter — and the content decides
/// whether it is a backup. Overridden in tests.
final backupFilePickerProvider = Provider<Future<PickedBackup?> Function()>(
  (ref) => () async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a Redemption backup',
    );
    if (picked == null) return null;
    return (name: picked.name, bytes: await picked.readAsBytes());
  },
);

/// Lets the user pick a backup (ZIP or JSON exported by any version of
/// Redemption) and imports it, replacing what is on this phone.
///
/// [replacing] asks for confirmation first (there is data to lose).
/// [onImporting] is called once the file is picked and the import starts.
/// Returns what was imported, or null if canceled or failed (failures are
/// shown to the user).
Future<ImportSummary?> importBackupFile(
  BuildContext context,
  WidgetRef ref, {
  required bool replacing,
  VoidCallback? onImporting,
}) async {
  if (replacing) {
    final ok = await confirm(
      context,
      title: 'Import data from a backup?',
      message:
          'Everything on this phone — journeys, trackers, entries, photos and '
          'settings — will be replaced by the backup. Export a backup first '
          'if you want to keep the current data.',
      confirmLabel: 'Choose file',
      destructive: true,
    );
    if (!ok || !context.mounted) return null;
  }
  // Read everything needed up front: after a first-run import the router
  // leaves the onboarding screen, unmounting the caller.
  final messenger = ScaffoldMessenger.of(context);
  final pick = ref.read(backupFilePickerProvider);
  final backup = ref.read(backupServiceProvider);
  final settings = ref.read(settingsRepositoryProvider);
  final notifications = ref.read(notificationServiceProvider);
  void snack(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final PickedBackup? file;
  try {
    file = await pick();
  } catch (e, s) {
    _log.warning('Picking a backup failed', e, s);
    snack('Couldn’t open that file: $e');
    return null;
  }
  if (file == null) return null;
  onImporting?.call();
  try {
    final summary = await backup.importBytes(file.bytes);
    // Continue Drive backups under a new install id, so today's
    // pre-import snapshot stays in Drive as a restore point.
    final s = await settings.load();
    await settings.save(
      s.copyWith(installId: '', driveLastBackupAt: () => null),
    );
    snack('Imported ${summary.describe()}. Welcome back.');
    // First run: onboarding (which normally asks) is skipped, but the
    // imported reminders need the permission.
    if (!replacing) await notifications.requestPermission();
    return summary;
  } on BackupException catch (e) {
    _log.warning('Import of ${file.name} refused: ${e.message}');
    snack(e.message);
  } catch (e, s) {
    _log.severe('Import of ${file.name} failed', e, s);
    snack('Import failed: $e');
  }
  return null;
}

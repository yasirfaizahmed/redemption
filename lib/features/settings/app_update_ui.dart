import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../state/app_update.dart';
import '../../state/providers.dart';

/// Shows the update sheet (checking first if nothing is known yet).
Future<void> showUpdateSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const UpdateSheet(),
    );

String _progressText(UpdateState u, int? sizeBytes) {
  final percent = '${((u.progress ?? 0) * 100).round()}%';
  return sizeBytes == null || sizeBytes <= 0
      ? 'Downloading… $percent'
      : 'Downloading… $percent of ${Fmt.bytes(sizeBytes)}';
}

/// Release notes, download progress and the install button.
class UpdateSheet extends ConsumerStatefulWidget {
  const UpdateSheet({super.key});

  @override
  ConsumerState<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<UpdateSheet> {
  @override
  void initState() {
    super.initState();
    final u = ref.read(updateControllerProvider);
    if (u.latest == null && !u.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(updateControllerProvider.notifier).check();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = ref.watch(updateControllerProvider);
    final notifier = ref.read(updateControllerProvider.notifier);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final latest = u.latest;

    final Widget body;
    if (!u.available) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (u.phase == UpdatePhase.checking) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Checking for updates…', style: muted),
            ] else if (u.error != null) ...[
              Icon(Icons.cloud_off_rounded, size: 40, color: scheme.error),
              const SizedBox(height: 12),
              Text(u.error!, textAlign: TextAlign.center, style: muted),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: notifier.check,
                child: const Text('Try again'),
              ),
            ] else ...[
              Icon(Icons.verified_rounded, size: 40, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'You’re on the latest version',
                style: theme.textTheme.titleMedium,
              ),
              if (u.current != null) ...[
                const SizedBox(height: 4),
                Text('Redemption v${u.current}', style: muted),
              ],
            ],
          ],
        ),
      );
    } else {
      final apk = latest!.apkFor(ref.read(deviceAbiProvider));
      final notes = latest.whatsNew;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              'Redemption v${latest.version}',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              [
                'You have v${u.current}',
                if (apk != null && apk.sizeBytes > 0) Fmt.bytes(apk.sizeBytes),
                if (latest.publishedAt case final at?)
                  DateFormat('d MMM yyyy').format(at),
              ].join(' · '),
              style: muted,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What’s new', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    notes.isEmpty
                        ? 'Improvements and fixes. Full notes are on the '
                              'project’s GitHub releases page.'
                        : notes,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (u.phase == UpdatePhase.downloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: u.progress),
                  const SizedBox(height: 6),
                  Text(_progressText(u, apk?.sizeBytes), style: muted),
                ],
              ),
            ),
          if (u.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                u.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              'Android will ask you to confirm. Your journeys and logs stay — '
              'the update installs over this version.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: u.busy ? null : notifier.install,
                  icon: u.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.install_mobile_rounded),
                  label: Text(
                    u.readyToInstall ? 'Install' : 'Download & install',
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: u.busy
                      ? null
                      : () async {
                          await notifier.skip();
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Skip this version'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return body;
  }
}

/// Dashboard card announcing a new version (until skipped or dismissed).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(updateControllerProvider);
    final skipped = ref.watch(
      settingsValueProvider.select((s) => s.updateSkippedVersion),
    );
    if (!u.available || u.dismissed || '${u.latest!.version}' == skipped) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final subtitle = switch (u.phase) {
      UpdatePhase.downloading => _progressText(
        u,
        u.latest!.apkFor(ref.read(deviceAbiProvider))?.sizeBytes,
      ),
      UpdatePhase.installing => 'Opening the installer…',
      _ when u.readyToInstall => 'Downloaded — tap to install',
      _ => 'Tap to see what’s new',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.primaryContainer,
        child: ListTile(
          leading: Icon(
            Icons.system_update_rounded,
            color: scheme.onPrimaryContainer,
          ),
          title: Text(
            u.readyToInstall
                ? 'Update ready: v${u.latest!.version}'
                : 'New version: v${u.latest!.version}',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          onTap: () => showUpdateSheet(context),
          trailing: IconButton(
            tooltip: 'Later',
            onPressed: ref.read(updateControllerProvider.notifier).dismiss,
            icon: Icon(Icons.close_rounded, color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

/// The "App updates" block of the settings screen.
class AppUpdateSection extends ConsumerWidget {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supported = ref.watch(updatesSupportedProvider).value ?? false;
    final installed = ref.watch(installedAppProvider).value;
    final s = ref.watch(settingsValueProvider);
    final u = ref.watch(updateControllerProvider);
    final notifier = ref.read(updateControllerProvider.notifier);
    final version = installed == null ? '' : 'v${installed.version}';

    final children = <Widget>[const SectionHeader('App updates')];
    if (!supported) {
      children.add(
        ListTile(
          enabled: false,
          leading: const Icon(Icons.system_update_outlined),
          title: Text(version.isEmpty ? 'Redemption' : 'Redemption $version'),
          subtitle: Text(
            installed?.fromPlayStore ?? false
                ? 'Updates come from Google Play'
                : 'In-app updates are available on Android',
          ),
        ),
      );
    } else {
      final last = s.updateLastCheckAt;
      final status = switch (u.phase) {
        UpdatePhase.checking => 'Checking GitHub…',
        UpdatePhase.downloading => _progressText(
          u,
          u.latest?.apkFor(ref.read(deviceAbiProvider))?.sizeBytes,
        ),
        UpdatePhase.installing => 'Opening the installer…',
        UpdatePhase.idle when u.readyToInstall => 'Downloaded — tap to install',
        UpdatePhase.idle when u.available =>
          'You have $version — tap to see what’s new',
        UpdatePhase.idle => [
          'You have $version',
          if (last != null) 'checked ${Fmt.ago(last)}',
        ].join(' · '),
      };
      children.addAll([
        ListTile(
          leading: Icon(
            u.available
                ? Icons.system_update_rounded
                : Icons.system_update_outlined,
            color: u.available ? scheme.primary : null,
          ),
          title: Text(
            u.available
                ? 'Update to v${u.latest!.version}'
                : 'Check for updates',
          ),
          subtitle: Text(status),
          trailing: u.busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : null,
          onTap: u.busy
              ? null
              : () async {
                  if (!u.available && !await notifier.check()) {
                    if (!context.mounted) return;
                    final after = ref.read(updateControllerProvider);
                    showSnack(
                      context,
                      after.error ?? 'You’re on the latest version ($version).',
                    );
                    return;
                  }
                  if (context.mounted) await showUpdateSheet(context);
                },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.update_rounded),
          title: const Text('Check automatically'),
          subtitle: const Text('When you open the app, every few hours'),
          value: s.updateAutoCheck,
          onChanged: notifier.setAutoCheck,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.download_for_offline_outlined),
          title: const Text('Download in the background'),
          subtitle: const Text('Have it ready — then just tap Install'),
          value: s.updateAutoDownload,
          onChanged: s.updateAutoCheck ? notifier.setAutoDownload : null,
        ),
      ]);
    }
    if (supported) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Updates come from the project’s GitHub releases and are checked '
            'against their published SHA-256 before installing. Android asks '
            'you to confirm every install — the first time, allow Redemption '
            'to install apps.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

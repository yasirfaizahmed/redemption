import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/time/day.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../../domain/templates.dart';
import '../../state/providers.dart';
import 'journey_form.dart';

/// Edit the active journey, or start a new one.
class JourneyEditorScreen extends ConsumerStatefulWidget {
  const JourneyEditorScreen({super.key, this.startNew = false});

  final bool startNew;

  @override
  ConsumerState<JourneyEditorScreen> createState() =>
      _JourneyEditorScreenState();
}

class _JourneyEditorScreenState extends ConsumerState<JourneyEditorScreen> {
  final _name = TextEditingController();
  final _intention = TextEditingController();
  late Day _start;
  int _days = 90;
  bool _copyCurrent = true;
  String _templateId = Templates.redemption.id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final journey = ref.read(activeJourneyProvider).value;
    final today = ref.read(todayProvider);
    if (widget.startNew || journey == null) {
      _start = today;
      _name.text = journey == null
          ? '90 Days of Redemption'
          : 'Round 2: ${journey.name}';
      _intention.text = journey?.intention ?? '';
      _days = journey?.durationDays ?? 90;
    } else {
      _start = journey.startDay;
      _name.text = journey.name;
      _intention.text = journey.intention;
      _days = journey.durationDays;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _intention.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(journeyRepositoryProvider);
    final current = ref.read(activeJourneyProvider).value;
    if (widget.startNew || current == null) {
      if (_copyCurrent && current != null) {
        await repo.createFromExisting(
          copyFrom: current.id,
          name: _name.text,
          intention: _intention.text,
          startDay: _start,
          durationDays: _days,
        );
      } else {
        await repo.createFromTemplate(
          template: Templates.byId(_templateId),
          name: _name.text,
          intention: _intention.text,
          startDay: _start,
          durationDays: _days,
        );
      }
      ref.read(selectedDayProvider.notifier).select(null);
      if (mounted) {
        showSnack(context, 'New journey started. Bismillah.');
        context.go(Routes.home);
      }
    } else {
      await repo.update(
        current.copyWith(
          name: _name.text.trim().isEmpty ? current.name : _name.text.trim(),
          intention: _intention.text.trim(),
          startDay: _start,
          durationDays: _days,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final current = ref.watch(activeJourneyProvider).value;
    final journeys = ref.watch(journeysProvider).value ?? const <Journey>[];
    final isNew = widget.startNew || current == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Start a new journey' : 'Edit journey'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
              onPressed: _saving ? null : _save,
              child: Text(isNew ? 'Start' : 'Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Journey name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _intention,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Intention (niyyah) — why are you doing this?',
            ),
          ),
          const SectionHeader(
            'Length',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          ),
          DurationPicker(
            days: _days,
            onChanged: (d) => setState(() => _days = d),
          ),
          const SectionHeader(
            'Start',
            padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          ),
          StartDayPicker(
            day: _start,
            today: today,
            onChanged: (d) => setState(() => _start = d),
          ),
          const SizedBox(height: 8),
          Text(
            'Ends ${DateFormat('EEEE, d MMMM yyyy').format(_start.addDays(_days - 1).toDateTime())}',
            style: theme.textTheme.bodySmall,
          ),
          if (isNew) ...[
            const SectionHeader(
              'Trackers',
              padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
            ),
            if (current != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Copy trackers & dashboard from the current journey',
                ),
                subtitle: const Text(
                  'Your old journey and its history are kept.',
                ),
                value: _copyCurrent,
                onChanged: (v) => setState(() => _copyCurrent = v),
              ),
            if (current == null || !_copyCurrent)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in Templates.all)
                    ChoiceChip(
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.name),
                      selected: _templateId == t.id,
                      onSelected: (_) => setState(() => _templateId = t.id),
                    ),
                ],
              ),
          ],
          if (!isNew && journeys.length > 1) ...[
            const SectionHeader(
              'All journeys',
              padding: EdgeInsets.fromLTRB(0, 32, 0, 8),
            ),
            for (final j in journeys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  j.isActive
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: j.isActive ? theme.colorScheme.primary : null,
                ),
                title: Text(j.name),
                subtitle: Text(
                  '${DateFormat('d MMM yyyy').format(j.startDay.toDateTime())} · ${j.durationDays} days',
                ),
                trailing: j.isActive
                    ? const Text('Active')
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'activate') {
                            await ref
                                .read(journeyRepositoryProvider)
                                .setActive(j.id);
                          } else if (v == 'delete') {
                            final ok = await confirm(
                              context,
                              title: 'Delete “${j.name}”?',
                              message: 'All its trackers and entries will be permanently deleted.',
                              confirmLabel: 'Delete',
                              destructive: true,
                            );
                            if (ok) {
                              await ref
                                  .read(journeyRepositoryProvider)
                                  .delete(j.id);
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'activate',
                            child: Text('Make active'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
              ),
          ],
          if (!isNew) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.newJourney),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Start a new journey'),
            ),
          ],
        ],
      ),
    );
  }
}

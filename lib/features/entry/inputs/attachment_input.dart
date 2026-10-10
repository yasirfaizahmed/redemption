import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/widgets/common.dart';
import '../../../data/storage/attachment_store.dart';
import '../../../domain/formatting.dart';
import '../../../domain/models.dart';
import '../../../domain/tracker_type.dart';
import '../../../domain/tracker_value.dart';
import '../../../state/providers.dart';

final _log = Logger('AttachmentInput');

/// Photos (camera / gallery) or any files, copied into private storage.
class AttachmentInput extends ConsumerStatefulWidget {
  const AttachmentInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  @override
  ConsumerState<AttachmentInput> createState() => _AttachmentInputState();
}

class _AttachmentInputState extends ConsumerState<AttachmentInput> {
  bool _busy = false;

  List<Attachment> get _files => widget.value is AttachmentsValue
      ? (widget.value! as AttachmentsValue).files
      : const [];

  bool get _isImage => widget.tracker.type == TrackerType.image;

  int get _remaining => widget.tracker.config.maxAttachments - _files.length;

  Future<void> _run(
    Future<List<Attachment>> Function(AttachmentStore) task,
  ) async {
    setState(() => _busy = true);
    try {
      final added = await task(ref.read(attachmentStoreProvider));
      if (added.isNotEmpty) {
        widget.onChanged(AttachmentsValue([..._files, ...added]));
      }
    } catch (e, s) {
      _log.warning('Attaching failed', e, s);
      if (mounted) showSnack(context, 'Could not attach: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _camera() => _run((store) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 85,
    );
    return shot == null ? [] : [await store.import(shot)];
  });

  Future<void> _gallery() => _run((store) async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      imageQuality: 85,
      limit: _remaining > 1 ? _remaining : null,
    );
    return [for (final x in picked.take(_remaining)) await store.import(x)];
  });

  Future<void> _browse() => _run((store) async {
    final picked = await FilePicker.pickFiles();
    return [
      for (final f in picked.take(_remaining))
        await store.import(f.xFile, displayName: f.name),
    ];
  });

  void _remove(Attachment a) {
    final next = [..._files]..remove(a);
    widget.onChanged(next.isEmpty ? null : AttachmentsValue(next));
  }

  Future<void> _open(Attachment a) async {
    final file = ref.read(attachmentStoreProvider).resolve(a);
    if (_isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewer(file: file, title: a.name),
        ),
      );
    } else {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        showSnack(context, result.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(attachmentStoreProvider);
    final files = _files;
    final canAdd = _remaining > 0 && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files.isNotEmpty)
          GridView.count(
            crossAxisCount: _isImage ? 3 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: _isImage ? 1 : 5,
            children: [
              for (final a in files)
                _isImage
                    ? _Thumb(
                        file: store.resolve(a),
                        onTap: () => _open(a),
                        onRemove: () => _remove(a),
                      )
                    : _FileTile(
                        attachment: a,
                        onTap: () => _open(a),
                        onRemove: () => _remove(a),
                      ),
            ],
          ),
        if (files.isNotEmpty) const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        Row(
          children: _isImage
              ? [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: canAdd ? _camera : null,
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: canAdd ? _gallery : null,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                    ),
                  ),
                ]
              : [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: canAdd ? _browse : null,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Attach file'),
                    ),
                  ),
                ],
        ),
        if (_remaining <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Maximum of ${widget.tracker.config.maxAttachments} reached',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.file,
    required this.onTap,
    required this.onRemove,
  });

  final File file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: scheme.surfaceContainerHighest,
            child: InkWell(
              onTap: onTap,
              child: Hero(
                tag: file.path,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  semanticLabel: 'Attached photo',
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 4, right: 4, child: _RemoveBadge(onPressed: onRemove)),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.attachment,
    required this.onTap,
    required this.onRemove,
  });

  final Attachment attachment;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  IconData get _icon => switch (attachment.extension) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'jpg' || 'jpeg' || 'png' || 'webp' || 'heic' => Icons.image_rounded,
    'mp3' || 'm4a' || 'wav' || 'aac' => Icons.audiotrack_rounded,
    'mp4' || 'mov' || 'mkv' => Icons.movie_rounded,
    'doc' || 'docx' || 'txt' || 'md' => Icons.article_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    _ => Icons.insert_drive_file_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(_icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      Fmt.bytes(attachment.sizeBytes),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.white,
          semanticLabel: 'Remove photo',
        ),
      ),
    ),
  );
}

class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.file, required this.title});

  final File file;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Hero(tag: file.path, child: Image.file(file)),
      ),
    ),
  );
}

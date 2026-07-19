import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../services/plan_store.dart';
import '../services/reader_settings.dart';
import '../services/reminder_service.dart';
import '../utils.dart';

/// Settings section for saving all app data to a file and restoring it —
/// so plans and progress survive a reinstall or a move to a new phone.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final json = await BackupService.buildBackupJson();
      final now = DateTime.now();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final name = 'bible-reading-backup-$stamp.json';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json', name: name)],
          subject: 'Bible backup',
          title: 'Bible backup',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export the backup: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // No type filter: Android file providers report backup JSON under a
      // variety of MIME types, so the content is validated instead.
      final picked = await openFile();
      if (picked == null) return;

      final json = await picked.readAsString();
      final summary = BackupService.inspectBackup(json);

      if (!mounted) return;
      final saved = summary.exportedAt;
      final ok = await confirm(
        context,
        title: 'Restore this backup?',
        message:
            '${summary.planCount} '
            '${summary.planCount == 1 ? 'plan' : 'plans'} · '
            '${formatInt(summary.chaptersRead)} chapters read'
            '${saved == null ? '' : ' · saved ${formatDate(saved)}'}\n'
            '${summary.planNames.take(3).join(', ')}'
            '${summary.planNames.length > 3 ? '…' : ''}\n\n'
            'This replaces everything currently in the app.',
        action: 'Restore',
      );
      if (!ok) return;

      await BackupService.restoreBackup(json);
      if (!mounted) return;
      // Re-read every service so the whole UI reflects the restored data.
      await context.read<PlanStore>().load();
      if (!mounted) return;
      await context.read<ReaderSettings>().load();
      if (!mounted) return;
      await context.read<ReminderService>().load();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${summary.planCount} '
            '${summary.planCount == 1 ? 'plan' : 'plans'}.',
          ),
        ),
      );
    } on BackupFormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not restore the backup: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Save your plans, progress, and settings to a file so you can '
          'restore them after reinstalling or on a new phone.',
          style: theme.textTheme.bodySmall,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.upload_file),
          title: const Text('Export backup'),
          subtitle: const Text('Share the file to Drive, email, or Files'),
          enabled: !_busy,
          onTap: _busy ? null : _export,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore),
          title: const Text('Import backup'),
          subtitle: const Text('Replace current data with a backup file'),
          enabled: !_busy,
          onTap: _busy ? null : _import,
        ),
      ],
    );
  }
}

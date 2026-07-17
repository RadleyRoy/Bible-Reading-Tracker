import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/reader_settings.dart';
import '../services/reminder_service.dart';
import '../widgets/verse_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettings>();
    final reminder = context.watch<ReminderService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bible text', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'These settings apply only to Bible reading text.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: VerseText(
                number: 1,
                text: 'The LORD is my shepherd; I shall not want.',
                fontFamily: settings.fontFamily,
                fontSize: settings.fontSize,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Font', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final font in ReaderSettings.fonts)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                title: Text(
                  font.label,
                  style: TextStyle(fontFamily: font.family, fontSize: 18),
                ),
                trailing: settings.fontFamily == font.family
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () =>
                    context.read<ReaderSettings>().setFontFamily(font.family),
              ),
            ),
          const SizedBox(height: 16),
          Text('Size', style: theme.textTheme.titleSmall),
          Row(
            children: [
              Text('A', style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: ReaderSettings.minSize,
                  max: ReaderSettings.maxSize,
                  divisions: (ReaderSettings.maxSize - ReaderSettings.minSize)
                      .round(),
                  label: settings.fontSize.round().toString(),
                  onChanged: (v) =>
                      context.read<ReaderSettings>().setFontSize(v),
                ),
              ),
              Text('A', style: theme.textTheme.titleLarge),
            ],
          ),
          Center(
            child: Text(
              '${settings.fontSize.round()} pt',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.read<ReaderSettings>().reset(),
              child: const Text('Reset to defaults'),
            ),
          ),
          const Divider(height: 32),
          Text('Reading', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark chapters read at the end'),
            subtitle: const Text(
              'When reading from a plan, reaching the end of a chapter '
              'checks it off automatically',
            ),
            value: settings.autoMark,
            onChanged: (v) => context.read<ReaderSettings>().setAutoMark(v),
          ),
          const Divider(height: 32),
          Text('Daily reminder', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me to read'),
            subtitle: const Text('A daily notification at the time you pick'),
            value: reminder.enabled,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await context.read<ReminderService>().setEnabled(v);
              if (!ok) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notification permission was denied — allow '
                      'notifications for Bible Reading in system settings.',
                    ),
                  ),
                );
              }
            },
          ),
          if (reminder.enabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time'),
              trailing: Text(
                reminder.time.format(context),
                style: theme.textTheme.titleMedium,
              ),
              onTap: () async {
                final service = context.read<ReminderService>();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: reminder.time,
                  helpText: 'Remind me to read at',
                );
                if (picked != null) await service.setTime(picked);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

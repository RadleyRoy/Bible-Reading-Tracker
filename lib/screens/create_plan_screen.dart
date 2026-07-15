import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';
import '../services/plan_store.dart';
import '../services/scheduler.dart';
import '../utils.dart';

enum Portion {
  whole('Whole Bible', 0, 65),
  oldTestament('Old Testament', 0, 38),
  newTestament('New Testament', 39, 65),
  custom('Custom range', 0, 65);

  final String label;
  final int startBook;
  final int endBook;

  const Portion(this.label, this.startBook, this.endBook);
}

/// Creates a new plan, or edits [existing] when provided.
class CreatePlanScreen extends StatefulWidget {
  final Plan? existing;

  const CreatePlanScreen({super.key, this.existing});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Portion _portion;
  late int _startBook;
  late int _endBook;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _startBook = existing?.startBook ?? 0;
    _endBook = existing?.endBook ?? kjvBooks.length - 1;
    _portion = Portion.values.firstWhere(
      (p) =>
          p != Portion.custom &&
          p.startBook == _startBook &&
          p.endBook == _endBook,
      orElse: () => Portion.custom,
    );
    _endDate = existing != null
        ? dateOnly(existing.endDate)
        : dateOnly(DateTime.now()).add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<ChapterRef> get _selectedChapters {
    final start = bookStartIndex[_startBook];
    final end = bookStartIndex[_endBook] + kjvBooks[_endBook].chapterCount;
    return allChapters.sublist(start, end);
  }

  int get _days {
    final diff = _endDate.difference(dateOnly(DateTime.now())).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  Future<void> _pickEndDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(today) ? _endDate : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 20)),
      helpText: 'Finish reading by',
    );
    if (picked != null) setState(() => _endDate = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final store = context.read<PlanStore>();
    final navigator = Navigator.of(context);
    final existing = widget.existing;

    if (existing == null) {
      await store.addPlan(
        Plan(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          startBook: _startBook,
          endBook: _endBook,
          startDate: dateOnly(DateTime.now()),
          endDate: _endDate,
        ),
      );
    } else {
      existing.name = _nameController.text.trim();
      existing.startBook = _startBook;
      existing.endBook = _endBook;
      existing.endDate = _endDate;
      await store.updatePlan(existing);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapters = _selectedChapters;
    final words = chapters.fold(0, (sum, c) => sum + c.words);
    final days = _days;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New plan' : 'Edit plan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Plan name',
                hintText: 'e.g. Whole Bible by Easter',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Give the plan a name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Portion>(
              initialValue: _portion,
              decoration: const InputDecoration(
                labelText: 'What to read',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in Portion.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (p) {
                if (p == null) return;
                setState(() {
                  _portion = p;
                  if (p != Portion.custom) {
                    _startBook = p.startBook;
                    _endBook = p.endBook;
                  }
                });
              },
            ),
            if (_portion == Portion.custom) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _bookDropdown(isStart: true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(child: _bookDropdown(isStart: false)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickEndDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Finish by',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(formatDate(_endDate)),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your plan', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${kjvBooks[_startBook].name} – ${kjvBooks[_endBook].name}\n'
                      '${formatInt(chapters.length)} chapters · '
                      '${formatInt(words)} words over $days '
                      '${days == 1 ? 'day' : 'days'}\n'
                      'About ${(chapters.length / days).toStringAsFixed(1)} '
                      'chapters (~${formatInt((words / days).round())} words) per day',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(
                widget.existing == null ? 'Create plan' : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookDropdown({required bool isStart}) {
    return DropdownButtonFormField<int>(
      initialValue: isStart ? _startBook : _endBook,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: isStart ? 'From' : 'To',
        border: const OutlineInputBorder(),
      ),
      items: [
        for (var i = 0; i < kjvBooks.length; i++)
          DropdownMenuItem(value: i, child: Text(kjvBooks[i].name)),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          if (isStart) {
            _startBook = v;
            if (_endBook < _startBook) _endBook = _startBook;
          } else {
            _endBook = v;
            if (_startBook > _endBook) _startBook = _endBook;
          }
        });
      },
    );
  }
}

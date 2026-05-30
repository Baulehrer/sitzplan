import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seating_plan_provider.dart';
import '../models/seating_plan.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SeatingPlanListProvider>().loadPlans();
    });
  }

  void _showNewPlanDialog() {
    final nameController = TextEditingController();
    final extraLabelController = TextEditingController();
    String groupName = '';
    int rows = 4;
    int columns = 8;
    bool hasExtraField = false;

    // Get existing group names for suggestions
    final provider = context.read<SeatingPlanListProvider>();
    final existingGroups = provider.plans
        .where((p) => p.groupName != null && p.groupName!.isNotEmpty)
        .map((p) => p.groupName!)
        .toSet()
        .toList();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Neuer Sitzplan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'z.B. Raum 204 — Mathe',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return existingGroups;
                      return existingGroups.where(
                        (g) => g.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    fieldViewBuilder:
                        (ctx, controller, focusNode, onSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Gruppe/Klasse (optional)',
                              hintText: 'z.B. Klasse 7a',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => groupName = value,
                          );
                        },
                    onSelected: (value) {
                      groupName = value;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reihen: $rows',
                              style: Theme.of(ctx).textTheme.bodyMedium,
                            ),
                            Slider(
                              value: rows.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '$rows',
                              onChanged: (v) =>
                                  setDialogState(() => rows = v.round()),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spalten: $columns',
                              style: Theme.of(ctx).textTheme.bodyMedium,
                            ),
                            Slider(
                              value: columns.toDouble(),
                              min: 1,
                              max: 14,
                              divisions: 13,
                              label: '$columns',
                              onChanged: (v) =>
                                  setDialogState(() => columns = v.round()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rows × $columns = ${rows * columns} Plätze',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Zusatzinfo pro Schüler'),
                    subtitle: const Text('z.B. Betrieb, Instrument, ...'),
                    value: hasExtraField,
                    onChanged: (v) => setDialogState(() => hasExtraField = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasExtraField) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: extraLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Bezeichnung des Zusatzfelds',
                        hintText: 'z.B. Betrieb',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final extraLabel = hasExtraField
                      ? extraLabelController.text.trim()
                      : null;
                  if (hasExtraField &&
                      (extraLabel == null || extraLabel.isEmpty)) {
                    return;
                  }
                  final group = groupName.trim();
                  final plan = await provider.createPlan(
                    name,
                    rows,
                    columns,
                    extraLabel: extraLabel,
                    groupName: group.isEmpty ? null : group,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _openEditor(plan);
                },
                child: const Text('Erstellen'),
              ),
            ],
          ),
        ),
      ).whenComplete(() {
        nameController.dispose();
        extraLabelController.dispose();
      }),
    );
  }

  void _openEditor(SeatingPlan plan) {
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(plan: plan)),
      ).then((_) async {
        if (!mounted) return;
        await context.read<SeatingPlanListProvider>().loadPlans();
      }),
    );
  }

  void _showPlanMenu(SeatingPlan plan) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Umbenennen'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(plan);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplizieren'),
              onTap: () {
                Navigator.pop(ctx);
                _showDuplicateDialog(plan);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Gruppe ändern'),
              onTap: () {
                Navigator.pop(ctx);
                _showChangeGroupDialog(plan);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Löschen',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(plan);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(SeatingPlan plan) {
    final controller = TextEditingController(text: plan.name);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Umbenennen'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Neuer Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<SeatingPlanListProvider>().renamePlan(
                plan,
                name,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await context.read<SeatingPlanListProvider>().renamePlan(
                  plan,
                  name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ).whenComplete(controller.dispose),
    );
  }

  void _showDuplicateDialog(SeatingPlan plan) {
    final controller = TextEditingController(text: '${plan.name} (Kopie)');
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sitzplan duplizieren'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name der Kopie',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await context.read<SeatingPlanListProvider>().duplicatePlan(
                  plan,
                  name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Duplizieren'),
            ),
          ],
        ),
      ).whenComplete(controller.dispose),
    );
  }

  void _showChangeGroupDialog(SeatingPlan plan) {
    final provider = context.read<SeatingPlanListProvider>();
    final existingGroups = provider.plans
        .where((p) => p.groupName != null && p.groupName!.isNotEmpty)
        .map((p) => p.groupName!)
        .toSet()
        .toList();

    String groupName = plan.groupName ?? '';

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gruppe ändern'),
          content: Autocomplete<String>(
            initialValue: TextEditingValue(text: plan.groupName ?? ''),
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return existingGroups;
              return existingGroups.where(
                (g) => g.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            fieldViewBuilder: (ctx, autoController, focusNode, onSubmitted) {
              return TextField(
                controller: autoController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Gruppe/Klasse',
                  hintText: 'Leer lassen zum Entfernen',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onChanged: (value) => groupName = value,
              );
            },
            onSelected: (value) => groupName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final group = groupName.trim();
                final updated = plan.copyWith(
                  groupName: group.isEmpty ? null : group,
                  clearGroupName: group.isEmpty,
                );
                await provider.updatePlan(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SeatingPlan plan) {
    final provider = context.read<SeatingPlanListProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sitzplan löschen?'),
        content: Text('"${plan.name}" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              await provider.deletePlan(plan.id!);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kaufi's Sitzplan-App")),
      body: Consumer<SeatingPlanListProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_seat_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Sitzpläne',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erstelle deinen ersten Sitzplan!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group plans by groupName
          final grouped = <String?, List<SeatingPlan>>{};
          for (final plan in provider.plans) {
            grouped.putIfAbsent(plan.groupName, () => []).add(plan);
          }

          // Sort: named groups first (alphabetically), then ungrouped
          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) {
              if (a == null && b == null) return 0;
              if (a == null) return 1;
              if (b == null) return -1;
              return a.compareTo(b);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final groupName in sortedKeys) ...[
                if (groupName != null && groupName.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          groupName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final plan in grouped[groupName]!) _buildPlanCard(plan),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPlanDialog,
        icon: const Icon(Icons.add),
        label: const Text('Neu'),
      ),
    );
  }

  Widget _buildPlanCard(SeatingPlan plan) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.grid_view_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(plan.name),
        subtitle: Text(
          '${plan.rows} × ${plan.columns} Plätze · '
          '${_formatDate(plan.updatedAt)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showPlanMenu(plan),
        ),
        onTap: () => _openEditor(plan),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

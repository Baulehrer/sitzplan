import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seating_plan_provider.dart';
import '../models/seating_plan.dart';
import '../services/import_export_service.dart';
import '../theme/app_theme.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SeatingPlanListProvider>().loadPlans();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Als Vorlage speichern'),
              onTap: () {
                Navigator.pop(ctx);
                _saveAsTemplate(plan);
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
    var includePhotos = true;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Sitzplan duplizieren'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Name der Kopie',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: includePhotos,
                  onChanged: (value) =>
                      setDialogState(() => includePhotos = value ?? true),
                  title: const Text('Fotos mitkopieren'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
                    includePhotos: includePhotos,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Duplizieren'),
              ),
            ],
          ),
        ),
      ).whenComplete(controller.dispose),
    );
  }

  Future<void> _saveAsTemplate(SeatingPlan plan) async {
    await context.read<SeatingPlanListProvider>().duplicatePlan(
      plan,
      '${plan.name} Vorlage',
      copySeats: false,
      includePhotos: false,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vorlage gespeichert')));
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

  Future<void> _exportBackup() async {
    try {
      final path = await ImportExportService().exportBackup();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup gespeichert: $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup fehlgeschlagen: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = UiBreakpoints.isCompact(context);
    return Scaffold(
      appBar: AppBar(
        title: compact ? const Text('Sitzplan') : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Backup exportieren',
            onPressed: _exportBackup,
          ),
        ],
      ),
      body: Consumer<SeatingPlanListProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.plans.isEmpty) {
            return _buildErrorState(provider);
          }
          if (provider.plans.isEmpty) {
            return _buildEmptyState();
          }

          final query = _searchController.text.trim().toLowerCase();
          final visiblePlans = query.isEmpty
              ? provider.plans
              : provider.plans.where((plan) {
                  final group = plan.groupName ?? '';
                  return plan.name.toLowerCase().contains(query) ||
                      group.toLowerCase().contains(query);
                }).toList();

          final recentPlans = query.isEmpty
              ? visiblePlans.take(compact ? 1 : 3).toList()
              : <SeatingPlan>[];
          final recentIds = recentPlans.map((plan) => plan.id).toSet();

          // Group plans by groupName
          final grouped = <String?, List<SeatingPlan>>{};
          for (final plan in visiblePlans.where(
            (plan) => !recentIds.contains(plan.id),
          )) {
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

          final content = CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(provider.plans.length)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Plan oder Klasse suchen',
                      labelText: 'Sitzpläne durchsuchen',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              if (recentPlans.isNotEmpty)
                SliverToBoxAdapter(
                  child: _sectionHeader('Zuletzt bearbeitet', Icons.history),
                ),
              if (recentPlans.isNotEmpty)
                _planGrid(recentPlans, compact: compact),
              if (grouped.isEmpty && visiblePlans.isEmpty)
                SliverToBoxAdapter(child: _buildNoResults()),
              for (final groupName in sortedKeys) ...[
                SliverToBoxAdapter(
                  child: _groupHeader(groupName, grouped[groupName]!.length),
                ),
                if (groupName == null ||
                    groupName.isEmpty ||
                    !_collapsedGroups.contains(groupName))
                  _planGrid(grouped[groupName]!, compact: compact),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 32,
                  compact ? 8 : 24,
                  compact ? 16 : 32,
                  0,
                ),
                child: content,
              ),
            ),
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

  Widget _buildHeader(int count) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEINE PLANUNGSFLÄCHE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('Sitzpläne', style: theme.textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                '$count ${count == 1 ? 'Plan' : 'Pläne'} – lokal auf diesem Gerät',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!UiBreakpoints.isCompact(context))
          FilledButton.icon(
            onPressed: _showNewPlanDialog,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Neuen Plan anlegen'),
          ),
      ],
    );
  }

  Widget _sectionHeader(String label, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  Widget _groupHeader(String? groupName, int count) {
    final label = groupName?.isNotEmpty == true ? groupName! : 'Ohne Gruppe';
    final collapsible = groupName?.isNotEmpty == true;
    final collapsed = collapsible && _collapsedGroups.contains(groupName);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: collapsible
          ? () => setState(() {
              if (!_collapsedGroups.add(groupName!)) {
                _collapsedGroups.remove(groupName);
              }
            })
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.folder_outlined : Icons.folder_open_outlined,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$count', style: Theme.of(context).textTheme.labelLarge),
            if (collapsible)
              Icon(collapsed ? Icons.expand_more : Icons.expand_less),
          ],
        ),
      ),
    );
  }

  SliverGrid _planGrid(List<SeatingPlan> plans, {required bool compact}) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact
            ? 1
            : (UiBreakpoints.isExpanded(context) ? 3 : 2),
        mainAxisExtent: 154,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildPlanCard(plans[index]),
        childCount: plans.length,
      ),
    );
  }

  Widget _buildPlanCard(SeatingPlan plan) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(plan),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _PlanThumbnail(rows: plan.rows, columns: plan.columns),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${plan.rows} × ${plan.columns} · ${plan.rows * plan.columns} Plätze',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bearbeitet am ${_formatDate(plan.updatedAt)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Planaktionen',
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showPlanMenu(plan),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PlanThumbnail(rows: 3, columns: 5, size: 112),
            const SizedBox(height: 24),
            Text(
              'Die Klasse kann kommen',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Lege deinen ersten Sitzplan an. Alles bleibt lokal auf diesem Gerät.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showNewPlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Plan anlegen'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildNoResults() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Center(
      child: Text(
        'Kein Sitzplan passt zu dieser Suche.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );

  Widget _buildErrorState(SeatingPlanListProvider provider) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Sitzpläne konnten nicht geladen werden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Prüfe den Speicherzugriff und versuche es erneut.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: provider.loadPlans,
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut laden'),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

class _PlanThumbnail extends StatelessWidget {
  final int rows;
  final int columns;
  final double size;

  const _PlanThumbnail({
    required this.rows,
    required this.columns,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.clamp(1, 4);
    final visibleColumns = columns.clamp(1, 5);
    return Semantics(
      label: '$rows Reihen und $columns Spalten',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: visibleColumns,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                children: List.generate(
                  visibleRows * visibleColumns,
                  (_) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/seating_plan.dart';
import '../providers/seating_plan_provider.dart';
import '../widgets/seat_card.dart';
import '../services/image_service.dart';
import '../services/import_export_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import 'seat_detail_screen.dart';

class EditorScreen extends StatefulWidget {
  final SeatingPlan plan;

  const EditorScreen({super.key, required this.plan});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Track which cell is currently being hovered by a drag
  int? _dragOverRow;
  int? _dragOverCol;
  bool _showSeatNumbers = false;
  bool _muteEmptySeats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SeatingPlanEditorProvider>().loadPlan(widget.plan);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openSeatDetail(int row, int col) {
    final editor = context.read<SeatingPlanEditorProvider>();
    final existingSeat = editor.getSeat(row, col);

    final detail = SeatDetailScreen(
      seat: existingSeat,
      planId: widget.plan.id!,
      row: row,
      col: col,
      extraLabel: widget.plan.extraLabel,
      onSave: (seat) async {
        await editor.saveSeat(seat);
        if (mounted) _showMessage('Gespeichert');
      },
      onDelete: existingSeat != null && !existingSeat.isEmpty
          ? () async {
              await editor.removeSeat(row, col);
              if (mounted) _showMessage('Platz geleert');
            }
          : null,
    );

    if (UiBreakpoints.isCompact(context)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => detail,
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: detail,
          ),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final editor = context.read<SeatingPlanEditorProvider>();
    if (editor.plan == null) return;

    var includePhotos = true;
    var includeNames = true;
    var includeExtraInfo = editor.plan!.hasExtraField;
    final options = await showDialog<PdfExportOptions>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('PDF exportieren'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: includePhotos,
                onChanged: (value) =>
                    setDialogState(() => includePhotos = value ?? true),
                title: const Text('Fotos'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: includeNames,
                onChanged: (value) =>
                    setDialogState(() => includeNames = value ?? true),
                title: const Text('Namen'),
                contentPadding: EdgeInsets.zero,
              ),
              if (editor.plan!.hasExtraField)
                CheckboxListTile(
                  value: includeExtraInfo,
                  onChanged: (value) =>
                      setDialogState(() => includeExtraInfo = value ?? true),
                  title: const Text('Zusatzinfo'),
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
              onPressed: () => Navigator.pop(
                ctx,
                PdfExportOptions(
                  includePhotos: includePhotos,
                  includeNames: includeNames,
                  includeExtraInfo: includeExtraInfo,
                ),
              ),
              child: const Text('Exportieren'),
            ),
          ],
        ),
      ),
    );
    if (options == null || !mounted) return;

    try {
      await PdfService().exportAndShare(
        editor.plan!,
        editor.seats,
        context,
        options: options,
      );
    } catch (error) {
      if (mounted) _showMessage('PDF konnte nicht erstellt werden: $error');
    }
  }

  Future<void> _clearSeats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Plätze leeren?'),
        content: const Text(
          'Namen, Zusatzinfos und Fotos werden aus diesem Sitzplan entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leeren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<SeatingPlanEditorProvider>().clearSeats();
      if (mounted) _showMessage('Alle Plätze wurden geleert');
    } catch (error) {
      if (mounted) _showMessage('Plätze konnten nicht geleert werden: $error');
    }
  }

  Future<void> _importCsv() async {
    try {
      final students = await ImportExportService().pickCsvStudents();
      if (!mounted || students.isEmpty) return;
      final added = await context
          .read<SeatingPlanEditorProvider>()
          .fillFreeSeatsFromCsv(students);
      if (!mounted) return;
      final skipped = students.length - added;
      _showMessage(
        skipped == 0
            ? '$added Einträge importiert'
            : '$added importiert, $skipped ohne freien Platz',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Namensliste konnte nicht importiert werden: $error');
      }
    }
  }

  Future<void> _importPhotos() async {
    final imageService = ImageService();
    List<String> paths = [];
    var added = 0;
    try {
      paths = await imageService.pickMultipleFromGallery();
      if (!mounted || paths.isEmpty) return;
      added = await context
          .read<SeatingPlanEditorProvider>()
          .fillFreeSeatsWithPhotos(paths);
      for (final unusedPath in paths.skip(added)) {
        await imageService.deletePhoto(unusedPath);
      }
      if (!mounted) return;
      final skipped = paths.length - added;
      _showMessage(
        skipped == 0
            ? '$added Fotos eingefügt'
            : '$added eingefügt, $skipped ohne freien Platz',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Fotos konnten nicht importiert werden: $error');
      }
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = UiBreakpoints.isCompact(context);
    final expanded = UiBreakpoints.isExpanded(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.name),
        actions: [
          if (compact) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'PDF exportieren',
              onPressed: _exportPdf,
            ),
            _buildOverflowMenu(),
          ],
        ],
      ),
      body: Consumer<SeatingPlanEditorProvider>(
        builder: (context, editor, _) {
          if (editor.loading && editor.seats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (editor.error != null) {
            return _buildLoadError(editor);
          }

          return Column(
            children: [
              if (!compact) _buildDesktopToolbar(editor, expanded: expanded),
              Expanded(child: _buildPlanCanvas(editor)),
            ],
          );
        },
      ),
    );
  }

  PopupMenuButton<String> _buildOverflowMenu() => PopupMenuButton<String>(
    tooltip: 'Weitere Aktionen',
    onSelected: _handleMenuAction,
    itemBuilder: (context) => [
      CheckedPopupMenuItem(
        value: 'numbers',
        checked: _showSeatNumbers,
        child: const Text('Platznummern anzeigen'),
      ),
      CheckedPopupMenuItem(
        value: 'muted',
        checked: _muteEmptySeats,
        child: const Text('Freie Plätze dezenter'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'csv', child: Text('Namensliste importieren')),
      const PopupMenuItem(value: 'photos', child: Text('Fotos importieren')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'clear', child: Text('Alle Plätze leeren')),
    ],
  );

  void _handleMenuAction(String value) {
    switch (value) {
      case 'numbers':
        setState(() => _showSeatNumbers = !_showSeatNumbers);
        break;
      case 'muted':
        setState(() => _muteEmptySeats = !_muteEmptySeats);
        break;
      case 'csv':
        _importCsv();
        break;
      case 'photos':
        _importPhotos();
        break;
      case 'clear':
        _clearSeats();
        break;
    }
  }

  Widget _buildDesktopToolbar(
    SeatingPlanEditorProvider editor, {
    required bool expanded,
  }) {
    final occupied = editor.seats.where((seat) => !seat.isEmpty).length;
    final total = widget.plan.rows * widget.plan.columns;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chair_alt_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$occupied von $total Plätzen belegt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (expanded) ...[
            FilterChip(
              selected: _showSeatNumbers,
              onSelected: (_) =>
                  setState(() => _showSeatNumbers = !_showSeatNumbers),
              avatar: const Icon(Icons.numbers, size: 18),
              label: const Text('Platznummern'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Namensliste'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _importPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Fotos'),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF exportieren'),
          ),
          _buildOverflowMenu(),
        ],
      ),
    );
  }

  Widget _buildPlanCanvas(SeatingPlanEditorProvider editor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        const minimumCellWidth = 112.0;
        const maximumCellWidth = 176.0;
        final available = constraints.maxWidth - 48;
        final fitWidth =
            (available - (widget.plan.columns - 1) * gap) / widget.plan.columns;
        final cellWidth = fitWidth.clamp(minimumCellWidth, maximumCellWidth);
        final cellHeight = cellWidth * 1.18;
        final canvasWidth =
            widget.plan.columns * cellWidth + (widget.plan.columns - 1) * gap;

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: SizedBox(
              width: canvasWidth,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRoomFront(),
                    const SizedBox(height: 14),
                    for (int row = 0; row < widget.plan.rows; row++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: row < widget.plan.rows - 1 ? gap : 0,
                        ),
                        child: Row(
                          children: [
                            for (int col = 0; col < widget.plan.columns; col++)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: col < widget.plan.columns - 1
                                      ? gap
                                      : 0,
                                ),
                                child: SizedBox(
                                  width: cellWidth,
                                  height: cellHeight,
                                  child: _buildDragTarget(
                                    row,
                                    col,
                                    editor,
                                    cellWidth,
                                    cellHeight,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomFront() => Semantics(
    label: 'Vorderseite des Raums',
    child: Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.secondary,
            thickness: 3,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'TAFEL · VORNE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.secondary,
            thickness: 3,
          ),
        ),
      ],
    ),
  );

  Widget _buildLoadError(SeatingPlanEditorProvider editor) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          'Dieser Sitzplan konnte nicht geladen werden',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => editor.loadPlan(widget.plan),
          icon: const Icon(Icons.refresh),
          label: const Text('Erneut laden'),
        ),
      ],
    ),
  );

  Widget _buildDragTarget(
    int row,
    int col,
    SeatingPlanEditorProvider editor,
    double cellWidth,
    double cellHeight,
  ) {
    final seat = editor.getSeat(row, col);
    final isHovered = _dragOverRow == row && _dragOverCol == col;
    final hasSeat = seat != null && !seat.isEmpty;

    // Wrap in DragTarget to receive drops
    return DragTarget<_SeatPosition>(
      onWillAcceptWithDetails: (details) {
        // Accept if not dropping on itself
        final data = details.data;
        return !(data.row == row && data.col == col);
      },
      onAcceptWithDetails: (details) async {
        final from = details.data;
        final snapshots = [
          SeatSnapshot(
            row: from.row,
            col: from.col,
            seat: editor.getSeat(from.row, from.col),
          ),
          SeatSnapshot(row: row, col: col, seat: editor.getSeat(row, col)),
        ];
        setState(() {
          _dragOverRow = null;
          _dragOverCol = null;
        });
        await editor.moveSeat(from.row, from.col, row, col);
        if (!mounted) return;
        _showMessage(
          'Gespeichert',
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () {
              editor.restorePositions(snapshots);
            },
          ),
        );
      },
      onMove: (_) {
        if (_dragOverRow != row || _dragOverCol != col) {
          setState(() {
            _dragOverRow = row;
            _dragOverCol = col;
          });
        }
      },
      onLeave: (_) {
        if (_dragOverRow == row && _dragOverCol == col) {
          setState(() {
            _dragOverRow = null;
            _dragOverCol = null;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final card = SeatCard(
          seat: seat,
          onTap: () => _openSeatDetail(row, col),
          positionLabel: _showSeatNumbers ? '${row + 1}/${col + 1}' : null,
          mutedEmpty: _muteEmptySeats,
        );

        // If seat is filled, make it draggable
        if (hasSeat) {
          final data = _SeatPosition(row, col);
          final feedback = Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: cellWidth * 0.9,
              height: cellHeight * 0.9,
              child: Opacity(opacity: 0.85, child: card),
            ),
          );
          final placeholder = Card(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          final child = AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            decoration: isHovered
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.5,
                    ),
                  )
                : null,
            child: card,
          );
          if (UiBreakpoints.isCompact(context)) {
            return LongPressDraggable<_SeatPosition>(
              data: data,
              feedback: feedback,
              childWhenDragging: placeholder,
              child: child,
            );
          }
          return Draggable<_SeatPosition>(
            data: data,
            feedback: feedback,
            childWhenDragging: placeholder,
            child: child,
          );
        }

        // Empty seat — just a drop target with highlight
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          decoration: isHovered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.5,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                )
              : null,
          child: card,
        );
      },
    );
  }
}

/// Simple data class to pass seat position during drag
class _SeatPosition {
  final int row;
  final int col;
  const _SeatPosition(this.row, this.col);
}

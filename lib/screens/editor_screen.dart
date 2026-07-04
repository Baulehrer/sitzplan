import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/seating_plan.dart';
import '../providers/seating_plan_provider.dart';
import '../widgets/seat_card.dart';
import '../services/image_service.dart';
import '../services/import_export_service.dart';
import '../services/pdf_service.dart';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SeatDetailScreen(
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
      ),
    );
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

    await PdfService().exportAndShare(
      editor.plan!,
      editor.seats,
      context,
      options: options,
    );
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

    await context.read<SeatingPlanEditorProvider>().clearSeats();
    if (mounted) _showMessage('Sitzplan geleert');
  }

  Future<void> _importCsv() async {
    final students = await ImportExportService().pickCsvStudents();
    if (!mounted || students.isEmpty) return;
    final added = await context
        .read<SeatingPlanEditorProvider>()
        .fillFreeSeatsFromCsv(students);
    if (mounted) _showMessage('$added Einträge importiert');
  }

  Future<void> _importPhotos() async {
    final paths = await ImageService().pickMultipleFromGallery();
    if (!mounted || paths.isEmpty) return;
    final added = await context
        .read<SeatingPlanEditorProvider>()
        .fillFreeSeatsWithPhotos(paths);
    for (final unusedPath in paths.skip(added)) {
      await ImageService().deletePhoto(unusedPath);
    }
    if (mounted) _showMessage('$added Fotos eingefügt');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Als PDF exportieren',
            onPressed: _exportPdf,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
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
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'numbers',
                checked: _showSeatNumbers,
                child: const Text('Platznummern'),
              ),
              CheckedPopupMenuItem(
                value: 'muted',
                checked: _muteEmptySeats,
                child: const Text('Leere Plätze dezenter'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'csv', child: Text('CSV importieren')),
              const PopupMenuItem(
                value: 'photos',
                child: Text('Fotos importieren'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Alle Plätze leeren'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<SeatingPlanEditorProvider>(
        builder: (context, editor, _) {
          if (editor.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plan = widget.plan;
                final cellWidth =
                    (constraints.maxWidth - (plan.columns - 1) * 8) /
                    plan.columns;
                final cellHeight = cellWidth * 1.2;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int r = 0; r < plan.rows; r++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              for (int c = 0; c < plan.columns; c++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: c < plan.columns - 1 ? 8 : 0,
                                    ),
                                    child: SizedBox(
                                      height: cellHeight,
                                      child: _buildDragTarget(
                                        r,
                                        c,
                                        editor,
                                        cellWidth,
                                        cellHeight,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

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
          return Draggable<_SeatPosition>(
            data: _SeatPosition(row, col),
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: cellWidth * 0.9,
                height: cellHeight * 0.9,
                child: Opacity(opacity: 0.85, child: card),
              ),
            ),
            childWhenDragging: Card(
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
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
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
            ),
          );
        }

        // Empty seat — just a drop target with highlight
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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

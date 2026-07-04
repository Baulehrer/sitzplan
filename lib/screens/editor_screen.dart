import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/seating_plan.dart';
import '../providers/seating_plan_provider.dart';
import '../widgets/seat_card.dart';
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
        },
        onDelete: existingSeat != null && !existingSeat.isEmpty
            ? () async {
                await editor.removeSeat(row, col);
              }
            : null,
      ),
    );
  }

  Future<void> _exportPdf() async {
    final editor = context.read<SeatingPlanEditorProvider>();
    if (editor.plan == null) return;
    await PdfService().exportAndShare(editor.plan!, editor.seats, context);
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
        setState(() {
          _dragOverRow = null;
          _dragOverCol = null;
        });
        await editor.moveSeat(from.row, from.col, row, col);
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

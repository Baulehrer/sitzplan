import 'dart:io';
import 'package:flutter/material.dart';
import '../models/seating_plan.dart';

class SeatCard extends StatelessWidget {
  final Seat? seat;
  final VoidCallback onTap;
  final String? positionLabel;
  final bool mutedEmpty;

  const SeatCard({
    super.key,
    this.seat,
    required this.onTap,
    this.positionLabel,
    this.mutedEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = seat == null || seat!.isEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: isEmpty ? _buildEmptySeat(theme) : _buildFilledSeat(theme),
      ),
    );
  }

  Widget _buildEmptySeat(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: mutedEmpty ? 0.45 : 1,
          ),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          if (positionLabel != null) _buildPositionLabel(theme),
          Center(
            child: Icon(
              Icons.add,
              color: theme.colorScheme.outline.withValues(
                alpha: mutedEmpty ? 0.35 : 1,
              ),
              size: mutedEmpty ? 22 : 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledSeat(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Stack(
        children: [
          Column(
            children: [
              // Photo — large
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                  child: _buildPhoto(theme),
                ),
              ),
              // First name — smaller
              if (seat!.firstName != null && seat!.firstName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Text(
                    seat!.firstName!,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Last name — larger and bold
              if (seat!.lastName != null && seat!.lastName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Text(
                    seat!.lastName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Extra info — small, muted
              if (seat!.extraInfo != null && seat!.extraInfo!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  child: Text(
                    seat!.extraInfo!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 2),
            ],
          ),
          if (positionLabel != null) _buildPositionLabel(theme),
        ],
      ),
    );
  }

  Widget _buildPositionLabel(ThemeData theme) {
    return Positioned(
      top: 4,
      left: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            positionLabel!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(ThemeData theme) {
    if (seat?.photoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(seat!.photoPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, e, s) => _buildPlaceholder(theme),
        ),
      );
    }
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String get _initials {
    if (seat == null) return '';
    final f = seat!.firstName?.isNotEmpty == true ? seat!.firstName![0] : '';
    final l = seat!.lastName?.isNotEmpty == true ? seat!.lastName![0] : '';
    return '$f$l'.toUpperCase();
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/seating_plan.dart';

class SeatCard extends StatelessWidget {
  final Seat? seat;
  final VoidCallback onTap;
  final String? positionLabel;
  final bool mutedEmpty;
  final List<String> extraLabels;

  const SeatCard({
    super.key,
    this.seat,
    required this.onTap,
    this.positionLabel,
    this.mutedEmpty = false,
    this.extraLabels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = seat == null || seat!.isEmpty;

    return Semantics(
      button: true,
      label: isEmpty ? 'Freier Platz' : 'Platz von ${seat!.displayName}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: isEmpty ? _buildEmptySeat(theme) : _buildFilledSeat(theme),
        ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  color: theme.colorScheme.outline.withValues(
                    alpha: mutedEmpty ? 0.35 : 1,
                  ),
                  size: mutedEmpty ? 22 : 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'Frei',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline.withValues(
                      alpha: mutedEmpty ? .35 : .8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledSeat(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: theme.colorScheme.secondary),
          ),
          Column(
            children: [
              // Photo — large
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
                  child: _buildPhoto(theme),
                ),
              ),
              if (seat!.displayName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 1, 5, 0),
                  child: Text(
                    seat!.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              for (final extra in _visibleExtras)
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: Text(
                    extra.label.isEmpty
                        ? extra.value
                        : '${extra.label}: ${extra.value}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 8.5,
                      height: 1.05,
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

  List<({String label, String value})> get _visibleExtras {
    if (seat == null) return const [];
    final values = seat!.extraInfos;
    return [
      for (var index = 0; index < values.length; index++)
        if (values[index]?.isNotEmpty == true)
          (
            label: index < extraLabels.length ? extraLabels[index] : '',
            value: values[index]!,
          ),
    ];
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
        borderRadius: BorderRadius.circular(10),
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
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
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

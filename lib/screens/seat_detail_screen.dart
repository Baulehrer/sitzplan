import 'dart:io';
import 'package:flutter/material.dart';
import '../models/seating_plan.dart';
import '../services/image_service.dart';

class SeatDetailScreen extends StatefulWidget {
  final Seat? seat;
  final int planId;
  final int row;
  final int col;
  final String? extraLabel;
  final Future<void> Function(Seat seat) onSave;
  final Future<void> Function()? onDelete;

  const SeatDetailScreen({
    super.key,
    this.seat,
    required this.planId,
    required this.row,
    required this.col,
    this.extraLabel,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<SeatDetailScreen> createState() => _SeatDetailScreenState();
}

class _SeatDetailScreenState extends State<SeatDetailScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extraInfoController;
  String? _photoPath;
  final _imageService = ImageService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.seat?.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.seat?.lastName ?? '');
    _extraInfoController =
        TextEditingController(text: widget.seat?.extraInfo ?? '');
    _photoPath = widget.seat?.photoPath;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _extraInfoController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final path = await _imageService.pickFromGallery();
    if (path != null) {
      if (_photoPath != null && _photoPath != widget.seat?.photoPath) {
        await _imageService.deletePhoto(_photoPath);
      }
      setState(() => _photoPath = path);
    }
  }

  Future<void> _takePhoto() async {
    final path = await _imageService.pickFromCamera();
    if (path == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera nicht verfügbar. Ist ffmpeg installiert?'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (path != null) {
      if (_photoPath != null && _photoPath != widget.seat?.photoPath) {
        await _imageService.deletePhoto(_photoPath);
      }
      setState(() => _photoPath = path);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoPath != null) {
      if (_photoPath != widget.seat?.photoPath) {
        await _imageService.deletePhoto(_photoPath);
      }
      setState(() => _photoPath = null);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    if (widget.seat?.photoPath != null &&
        widget.seat?.photoPath != _photoPath) {
      await _imageService.deletePhoto(widget.seat?.photoPath);
    }

    final seat = Seat(
      id: widget.seat?.id,
      planId: widget.planId,
      row: widget.row,
      col: widget.col,
      firstName: _firstNameController.text.trim().isEmpty
          ? null
          : _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isEmpty
          ? null
          : _lastNameController.text.trim(),
      photoPath: _photoPath,
      extraInfo: _extraInfoController.text.trim().isEmpty
          ? null
          : _extraInfoController.text.trim(),
    );

    await widget.onSave(seat);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.onDelete == null) return;
    if (widget.seat?.photoPath != null) {
      await _imageService.deletePhoto(widget.seat?.photoPath);
    }
    await widget.onDelete!();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Platz ${widget.row + 1}/${widget.col + 1}',
                  style: theme.textTheme.titleLarge,
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    onPressed: _delete,
                    tooltip: 'Platz leeren',
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Photo area
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photoPath != null
                      ? Image.file(
                          File(_photoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => _photoPlaceholder(theme),
                        )
                      : _photoPlaceholder(theme),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Photo buttons — Kamera immer anzeigen wenn verfügbar
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Aufnehmen'),
                ),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Foto wählen'),
                ),
                if (_photoPath != null)
                  TextButton.icon(
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.close),
                    label: const Text('Entfernen'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Vorname',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nachname',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: widget.extraLabel != null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: widget.extraLabel == null ? (_) => _save() : null,
            ),

            // Extra info field (if plan has one)
            if (widget.extraLabel != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _extraInfoController,
                decoration: InputDecoration(
                  labelText: widget.extraLabel,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
            ],
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.person_add_alt_1_outlined,
        size: 40,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_appearance_provider.dart';
import '../theme/app_theme.dart';

class ThemePickerButton extends StatelessWidget {
  const ThemePickerButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.palette_outlined),
    tooltip: 'Darstellung wählen',
    onPressed: () => _showPicker(context),
  );

  Future<void> _showPicker(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final appearance = context.watch<AppAppearanceProvider>();
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Darstellung',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Wähle die Farben und wie hell die Arbeitsfläche sein soll.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Hell'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dunkel'),
                  ),
                ],
                selected: {appearance.themeMode},
                onSelectionChanged: (values) =>
                    appearance.setThemeMode(values.first),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Farbstimmung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            RadioGroup<AppPalette>(
              groupValue: appearance.palette,
              onChanged: (value) {
                if (value != null) appearance.setPalette(value);
              },
              child: Column(
                children: [
                  for (final palette in AppPalette.values)
                    RadioListTile<AppPalette>(
                      value: palette,
                      title: Text(palette.label),
                      secondary: _PaletteSwatch(palette: palette),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PaletteSwatch extends StatelessWidget {
  final AppPalette palette;

  const _PaletteSwatch({required this.palette});

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: palette.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    alignment: Alignment.bottomRight,
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: palette.accent,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    ),
  );
}

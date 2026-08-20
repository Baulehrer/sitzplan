import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_service.dart';

class AutomaticUpdateGate extends StatefulWidget {
  const AutomaticUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AutomaticUpdateGate> createState() => _AutomaticUpdateGateState();
}

class _AutomaticUpdateGateState extends State<AutomaticUpdateGate> {
  final _updateService = UpdateService();
  UpdateRelease? _release;
  double? _progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAndInstall());
    });
  }

  Future<void> _checkAndInstall() async {
    var updateWasFound = false;
    try {
      final release = await _updateService.checkForUpdate();
      if (!mounted || release == null) return;
      updateWasFound = true;
      setState(() {
        _release = release;
        _progress = 0;
      });
      final package = await _updateService.download(
        release,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : null;
          });
        },
      );
      if (!mounted) return;
      setState(() => _progress = 1);
      final result = await _updateService.install(release, package);
      if (!mounted) return;
      setState(() {
        _release = null;
        _progress = null;
      });
      if (result == UpdateInstallResult.requiresUserAction) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update bereit'),
            content: const Text(
              'Das Installations- oder Berechtigungsfenster wurde geöffnet. Folge dort den kurzen Hinweisen, um das Update abzuschließen.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Verstanden'),
              ),
            ],
          ),
        );
      } else if (result == UpdateInstallResult.unsupported) {
        await _showError(
          'Das Update wurde geladen, kann an diesem Installationsort aber nicht automatisch ersetzt werden.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _release = null;
        _progress = null;
      });
      // Offline starts should stay quiet. A found but failed update is useful
      // feedback, so only show errors once the download UI was visible.
      if (updateWasFound) await _showError('$error');
    }
  }

  Future<void> _showError(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update nicht abgeschlossen'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Später erneut versuchen'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final release = _release;
    return Stack(
      children: [
        widget.child,
        if (release != null) ...[
          const ModalBarrier(dismissible: false, color: Colors.black45),
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update_alt_rounded, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        'Sitzplan ${release.version} wird installiert',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Das Update wird automatisch geladen und anschließend vom Betriebssystem installiert.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(value: _progress),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Résultat d'un enregistrement vocal : chemin du fichier + durée en secondes.
class RecordedAudio {
  const RecordedAudio({required this.path, required this.duration});
  final String path;
  final int duration;
}

/// Feuille d'enregistrement : appuyer pour démarrer, ré-appuyer pour envoyer.
/// Renvoie un [RecordedAudio] via `Navigator.pop`, ou null si annulé.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      // Déclenche la demande de permission micro (prompt navigateur sur web).
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission micro refusée')),
          );
        }
        return;
      }

      if (kIsWeb) {
        // Sur web : pas de système de fichiers (path_provider plante).
        // L'encodeur opus produit un blob webm ; stop() renvoie une URL blob:.
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
      }

      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $e')),
        );
      }
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    if (path == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(RecordedAudio(path: path, duration: _seconds));
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _recording ? 'Enregistrement… ${_fmt(_seconds)}' : 'Message vocal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            IconButton.filled(
              iconSize: 48,
              icon: Icon(_recording ? Icons.send : Icons.mic),
              onPressed: () {
                if (_recording) {
                  _stopAndSend();
                } else {
                  _start();
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                _timer?.cancel();
                if (_recording) await _recorder.stop();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

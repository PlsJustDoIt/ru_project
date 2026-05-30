import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ru_project/models/color.dart';

/// Lecteur de message vocal façon « Instagram » : bouton play/pause, waveform
/// (barres) qui se remplit avec la progression, durée totale.
/// Lecture unifiée web + mobile via just_audio.
class AudioPlayerWidget extends StatefulWidget {
  final dynamic message; // types.AudioMessage : .source, .duration, .id
  const AudioPlayerWidget({super.key, required this.message});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    // Durée initiale fournie par le serveur (avant chargement réel).
    final d = widget.message.duration;
    if (d is Duration) _total = d;
    _bars = _generateBars('${widget.message.id}', 32);

    _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero && mounted) {
        setState(() => _total = dur);
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        setState(() => _playing = false);
      } else {
        setState(() => _playing = s.playing);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Barres déterministes (mêmes hauteurs pour un même message).
  List<double> _generateBars(String seed, int count) {
    final rnd = Random(seed.hashCode);
    return List.generate(count, (_) => 0.25 + rnd.nextDouble() * 0.75);
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final String source = widget.message.source;
    if (source.startsWith('http') || source.startsWith('blob')) {
      await _player.setUrl(source);
    } else {
      await _player.setFilePath(source);
    }
    _loaded = true;
  }

  Future<void> _toggle() async {
    await _ensureLoaded();
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  void _seekTo(double fraction) {
    if (_total <= Duration.zero) return;
    final target = _total * fraction.clamp(0.0, 1.0);
    _player.seek(target);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > Duration.zero
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final shown = _playing || _position > Duration.zero ? _position : _total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
          color: AppColors.accent,
          iconSize: 36,
          onPressed: _toggle,
        ),
        Expanded(
          child: SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _seekTo(details.localPosition.dx / constraints.maxWidth),
                  child: _Waveform(bars: _bars, progress: progress),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_fmt(shown),
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Rangée de barres de volume ; remplies (accent) jusqu'à [progress], grises ensuite.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.bars, required this.progress});

  final List<double> bars;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final filledCount = (bars.length * progress).round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < bars.length; i++)
          Container(
            width: 3,
            height: 28 * bars[i],
            decoration: BoxDecoration(
              color: i < filledCount
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

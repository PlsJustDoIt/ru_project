import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ru_project/widgets/audio/web_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final dynamic message; // Accepts types.AudioMessage or similar
  const AudioPlayerWidget({super.key, required this.message});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  WebAudio? _webAudio;
  Duration? _duration;
  double _iconRotation = 0.0;

  @override
  void dispose() {
    _player?.dispose();
    _webAudio?.pause();
    super.dispose();
  }

  Future<void> _play() async {
    if (kIsWeb) {
      // Web: play using HTML audio element
      _webAudio ??= WebAudio()
        ..load(
          widget.message.source,
          onDuration: (duration) {
            if (mounted) setState(() => _duration = duration);
          },
          onEnded: () {
            if (mounted) setState(() => _isPlaying = false);
          },
        );
      _webAudio!.play();
      setState(() {
        _isPlaying = true;
        _iconRotation += 1.0;
      });
    } else {
      // Mobile/Desktop: play using just_audio
      _player ??= AudioPlayer();
      await _player!.setFilePath(widget.message.source);
      _duration = _player!.duration;
      await _player!.play();
      setState(() {
        _isPlaying = true;
        _iconRotation += 1.0;
      });
      _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  void _stop() {
    if (kIsWeb) {
      _webAudio?.pause();
      setState(() {
        _isPlaying = false;
        _iconRotation += 1.0;
      });
    } else {
      _player?.stop();
      setState(() {
        _isPlaying = false;
        _iconRotation += 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedRotation(
          turns: _iconRotation,
          duration: const Duration(milliseconds: 400),
          child: IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            onPressed: _isPlaying ? _stop : _play,
          ),
        ),
        const Text('Message vocal'),
        if (_duration != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(_formatDuration(_duration!)),
          ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'web_audio.dart';

/// Implémentation web basée sur `HTMLAudioElement`.
WebAudio createWebAudio() => _WebAudio();

class _WebAudio implements WebAudio {
  web.HTMLAudioElement? _element;

  @override
  void load(
    String src, {
    void Function(Duration duration)? onDuration,
    void Function()? onEnded,
  }) {
    final element = web.HTMLAudioElement()..src = src;
    if (onDuration != null) {
      element.addEventListener(
        'loadedmetadata',
        (web.Event _) {
          if (!element.duration.isNaN) {
            onDuration(
              Duration(milliseconds: (element.duration * 1000).toInt()),
            );
          }
        }.toJS,
      );
    }
    if (onEnded != null) {
      element.addEventListener(
        'ended',
        (web.Event _) {
          onEnded();
        }.toJS,
      );
    }
    _element = element;
  }

  @override
  void play() {
    _element?.play();
  }

  @override
  void pause() {
    _element?.pause();
  }
}

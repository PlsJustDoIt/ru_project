import 'web_audio_stub.dart'
    if (dart.library.js_interop) 'web_audio_web.dart';

/// Lecteur audio pour le web (HTMLAudioElement), abstrait derrière une
/// interface afin que les imports web-only (`dart:js_interop`, `package:web`)
/// ne soient tirés que sur la plateforme web. Sur mobile/desktop/VM, c'est le
/// stub no-op qui est compilé — la lecture passe par `just_audio`.
abstract class WebAudio {
  factory WebAudio() => createWebAudio();

  /// Prépare la source et branche les callbacks (durée connue, lecture finie).
  void load(
    String src, {
    void Function(Duration duration)? onDuration,
    void Function()? onEnded,
  });

  void play();
  void pause();
}

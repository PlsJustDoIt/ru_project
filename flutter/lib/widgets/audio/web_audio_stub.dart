import 'web_audio.dart';

/// Implémentation no-op hors web : la lecture web n'est jamais sollicitée
/// (gardée par `kIsWeb`), donc aucune dépendance à `package:web`.
WebAudio createWebAudio() => _StubWebAudio();

class _StubWebAudio implements WebAudio {
  @override
  void load(
    String src, {
    void Function(Duration duration)? onDuration,
    void Function()? onEnded,
  }) {}

  @override
  void play() {}

  @override
  void pause() {}
}

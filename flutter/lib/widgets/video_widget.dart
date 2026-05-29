import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoWidget extends StatefulWidget {
  final String videoUrl;
  final int width;

  const VideoWidget({
    super.key,
    this.videoUrl = 'assets/images/video.mp4',
    this.width = 200,
  });

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    // Use the videoUrl passed to the widget
    _videoController = VideoPlayerController.asset(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _videoController.value.isInitialized
            ? SizedBox(
                width: widget.width.toDouble(), // Set the desired width
                child: AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: VideoPlayer(_videoController),
                ),
              )
            : const CircularProgressIndicator(),
        IconButton(
          icon: _videoController.value.isPlaying
              ? const Icon(Icons.pause)
              : const Icon(Icons.play_arrow),
          onPressed: () {
            setState(() {
              if (_videoController.value.isPlaying) {
                _videoController.pause();
              } else {
                _videoController.play();
              }
            });
          },
        ),
      ],
    );
  }
}

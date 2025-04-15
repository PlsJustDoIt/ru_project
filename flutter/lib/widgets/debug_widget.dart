import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:duration/duration.dart';
import 'package:video_player/video_player.dart';

class DebugWidget extends StatefulWidget {
  @override
  _DebugWidgetState createState() => _DebugWidgetState();
}

class _DebugWidgetState extends State<DebugWidget> {
  final SecureStorage _secureStorage = SecureStorage();
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/images/video.mp4')
      ..initialize().then((_) {
        setState(() {});
      });
    logger.d('DebugWidget initState');
  }

  @override
  Widget build(BuildContext context) {
    logger.d('DebugWidget build');

    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Widget'),
      ),
      body: FutureBuilder<Map<String, String?>>(
        future: _fetchTokens(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final accessToken = snapshot.data?['accessToken'];
          final refreshToken = snapshot.data?['refreshToken'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Access Token:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(accessToken ?? 'No Access Token'),
                Text('isExpired: ${JwtDecoder.isExpired(accessToken ?? '')}'),
                Text(
                    'expires in ${prettyDuration(JwtDecoder.getRemainingTime(accessToken ?? ''))}'),
                SizedBox(height: 16),
                Text('Refresh Token:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(refreshToken ?? 'No Refresh Token'),
                Text('isExpired: ${JwtDecoder.isExpired(refreshToken ?? '')}'),
                Text(
                    'expires in ${prettyDuration(JwtDecoder.getRemainingTime(refreshToken ?? ''))}'),
                ElevatedButton(
                    onPressed: refreshTokent,
                    child: Text('rafraichir le token')),
                SizedBox(height: 16),
                Image.asset(
                  "assets/images/jm.jpg",
                ),
                SizedBox(height: 16),
                Column(
                  children: [
                    Text(
                      'Video Player',
                      style: TextStyle(fontSize: 24),
                    ),
                    _videoController.value.isInitialized
                    ? SizedBox(
                        width: 200, // Set the desired width
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
                          if (_videoController.value.isPlaying) {
                            _videoController.pause();
                          } else {
                            _videoController.play();
                          }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void refreshTokent() async {
    final ApiService apiService =
        Provider.of<ApiService>(context, listen: false);
    final accessToken = await apiService.refreshToken();
    if (accessToken == null) {
      logger.e('Failed to refresh token');
      return;
    }

    await _secureStorage.storeAccessToken(accessToken);

    setState(() {});
  }

  Future<Map<String, String?>> _fetchTokens() async {
    final accessToken = await _secureStorage.getAccessToken();
    final refreshToken = await _secureStorage.getRefreshToken();
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}

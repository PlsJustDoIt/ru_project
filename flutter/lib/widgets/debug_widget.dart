import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:duration/duration.dart';
import 'package:ru_project/widgets/test_statefull.dart';
import 'package:ru_project/widgets/video_widget.dart';

class DebugWidget extends StatefulWidget {
  const DebugWidget({super.key});

  @override
  State<DebugWidget> createState() => _DebugWidgetState();
}

class _DebugWidgetState extends State<DebugWidget> {
  final SecureStorage _secureStorage = SecureStorage();
  late final UserProvider userProvider;
  late final ApiClient apiClient;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    apiClient = Provider.of<ApiClient>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
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
            child: SingleChildScrollView(
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
                    VideoWidget(
                      videoUrl: 'assets/images/video.mp4',
                    ),
                    const StateWidget(),
                  ],
                ),
              ],
            )),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void refreshTokent() async {
    final accessToken = await apiClient.refreshToken();
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

import 'package:flutter/material.dart';
import 'package:ru_project/services/secure_storage.dart';

class DebugWidget extends StatefulWidget {
  @override
  _DebugWidgetState createState() => _DebugWidgetState();
}

class _DebugWidgetState extends State<DebugWidget> {
  final SecureStorage _secureStorage = SecureStorage();

  @override
  Widget build(BuildContext context) {

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
                Text('Access Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(accessToken ?? 'No Access Token'),
                SizedBox(height: 16),
                Text('Refresh Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(refreshToken ?? 'No Refresh Token'),
                Image.asset(
                  "assets/images/jm.jpg",
                ),
              ],
            ),
          );
        },
      ),
    );
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
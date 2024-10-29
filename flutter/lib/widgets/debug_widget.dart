import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';

class DebugWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final accessToken = userProvider.accessToken;
    final refreshToken = userProvider.refreshToken;

    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Widget'),
      ),
      body: Padding(
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
              "images/jm.jpg"
            ),
          ],
        ),
      ),
    );
  }
}
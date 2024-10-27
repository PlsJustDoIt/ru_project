import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/test_statefull.dart';
import 'package:video_player/video_player.dart';

class WelcomeWidget extends StatefulWidget {
  const WelcomeWidget({super.key});

  @override
  State<WelcomeWidget> createState() => _WelcomeWidget2State();
}

class _WelcomeWidget2State extends State<WelcomeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> welcomeFadeanimation;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _videoController = VideoPlayerController.asset('assets/video.mp4')
      ..initialize().then((_) {
        setState(() {
          
        });
      });

    welcomeFadeanimation = Tween<double>(begin: 0, end: 1).animate(controller);

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                    icon: _videoController.value.isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
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
              const Text(
                'test',
                style: TextStyle(fontSize: 32, fontFamily: 'Marianne'),
              ),
              const StateWidget(),
              const Text(
                'Bienvenue !',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, begin: 0)
                  .tint(color: Colors.green)
                  .slide(duration: 500.ms, curve: Curves.easeIn)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(delay: 1.seconds),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _usernameController,
                  decoration:
                      const InputDecoration(labelText: 'Nom d\'utilisateur'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                  ),
                  obscureText: true,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        await userProvider.login(
                            _usernameController.text, _passwordController.text);
                        if (context.mounted == false) {
                          return;
                        }
                        if (userProvider.user != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const TabBarWidget()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Erreur de connexion')));
                        }
                      },
                      child: const Text('Se connecter'),
                    )
                        .animate()
                        .fade(duration: 500.ms)
                        .scale(delay: 0.6.seconds),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        final response = await userProvider.register(
                            _usernameController.text, _passwordController.text);
                        if (context.mounted == false) {
                          return;
                        }
                        if (userProvider.user != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const TabBarWidget()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(response['message'] ?? 'Erreur d\'inscription')));
                        }
                      },
                      child: const Text('S\'inscrire'),
                    )
                        .animate()
                        .fade(duration: 500.ms)
                        .scale(delay: 0.6.seconds),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller.dispose();
    _videoController.dispose();
    super.dispose();
  }
}

// class AuthForm extends StatelessWidget {
//   @override
//   Widget build(Object context) {
//     // TODO: implement build
//   }
// }

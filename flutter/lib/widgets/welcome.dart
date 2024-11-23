import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/test_statefull.dart';
import 'package:video_player/video_player.dart';
import 'package:ru_project/services/logger.dart';

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
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _videoController = VideoPlayerController.asset('assets/images/video.mp4')
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
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
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
                ),
                    // .animate()
                    // .fadeIn(duration: 500.ms, begin: 0)
                    // .tint(color: Colors.green)
                    // .slide(duration: 500.ms, curve: Curves.easeIn)
                    // .animate(onPlay: (controller) => controller.repeat())
                    // .shake(delay: 1.seconds),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _usernameController,
                    decoration:
                        const InputDecoration(labelText: 'Nom d\'utilisateur (3-32 caractères)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom d\'utilisateur (3-32 caractères)';
                      }
                      if (value.trim().isEmpty) {
                        return 'Veuillez entrer un nom d\'utilisateur valide';
                      }
                      if (value.length > 32) {
                        return 'Le nom d\'utilisateur doit comporter moins de 32 caractères';
                      }
                      if (value.length < 3) {
                        return 'Le nom d\'utilisateur doit comporter au moins 3 caractères';
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe (3-32 caractères)',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veillez entrer un mot de passe (3-32 caractères)';
                      }
                      if (value.trim().isEmpty) {
                        return 'Veillez entrer un mot de passe valide';
                      }
                      if (value.length < 3) {
                        return 'Le mot de passe doit comporter au moins 3 caractères';
                      }
                      if (value.length > 32) {
                        return 'Le mot de passe doit comporter moins de 32 caractères';
                      }
                      return null;
                      },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          final User user =await apiService.login(
                              _usernameController.text, _passwordController.text);
                              userProvider.setUser(user);
                          if (context.mounted == false) {
                            return;
                          }
                          if (userProvider.user != null) {
                            if (userProvider.user?.id == '-1'){ //error
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(user.username)));
                              userProvider.logout();
                              return;
                            }
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
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          final User user = await apiService.register(
                              _usernameController.text, _passwordController.text);
                              userProvider.setUser(user);
                          if (context.mounted == false) {
                            return;
                          }
                          if (userProvider.user != null) {
                            if (userProvider.user?.id == '-1'){ //error
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(user.username)));
                              userProvider.logout();
                              return;
                            }
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const TabBarWidget()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('Erreur d\'inscription')));
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
      )
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

//username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces 

// class AuthForm extends StatelessWidget {
//   @override
//   Widget build(Object context) {
//     // TODO: implement build
//   }
// }

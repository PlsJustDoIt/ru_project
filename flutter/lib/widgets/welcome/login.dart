import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/custom_snack_bar.dart';
import 'package:ru_project/validators/auth_validator.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _apiErrors = {};
  bool _hasSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Se connecter',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      autovalidateMode: _hasSubmitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      controller: _usernameController,
                      decoration: const InputDecoration(
                          labelText: 'Nom d\'utilisateur (3-32 caractères)'),
                      // validator: (value) {
                      //   if (_apiErrors.containsKey('username')) {
                      //     return _apiErrors['username'];
                      //   }
                      //   if (value == null || value.isEmpty) {
                      //     return 'Veuillez entrer un nom d\'utilisateur (3-32 caractères)';
                      //   }
                      //   if (value.trim().isEmpty) {
                      //     return 'Veuillez entrer un nom d\'utilisateur valide';
                      //   }
                      //   if (value.length > 32) {
                      //     return 'Le nom d\'utilisateur doit comporter moins de 32 caractères';
                      //   }
                      //   if (value.length < 3) {
                      //     return 'Le nom d\'utilisateur doit comporter au moins 3 caractères';
                      //   }
                      //   return null;
                      // },
                      validator: (value) => validateUsername(value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      autovalidateMode: _hasSubmitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe (3-32 caractères)',
                      ),
                      obscureText: true,
                      validator: (value) => validatePassword(
                        value,
                        apiError: _apiErrors['password'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _hasSubmitted = true;
                      });
                      _apiErrors.clear();

                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      try {
                        final Map<String, dynamic> response =
                            await apiService.login(_usernameController.text,
                                _passwordController.text);

                        if (context.mounted == false) {
                          return;
                        }

                        //TODO : diffencier utilisateur inexistant et erreur de connexion
                        if (response.containsKey('error')) {
                          setState(() {
                            _apiErrors.clear();
                            _apiErrors[response['errorField']] =
                                response['error'];
                            _formKey.currentState!.validate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              CustomSnackBar(message: 'Erreur de connexion.'));
                          return;
                        }
                        final User user = response['user'];
                        userProvider.setUser(user);
                        List<User> fetchedFriends = await apiService.getFriends();
                        userProvider.setFriends(fetchedFriends);

                        if (context.mounted == false) {
                          return;
                        }

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TabBarWidget()),
                        );
                      } catch (e) {
                        if (context.mounted == false) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                            CustomSnackBar(message: 'Erreur de connexion.'));
                        return;
                      }
                    },
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

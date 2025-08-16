import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/validators/auth_validator.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';

class RegisterWidget extends StatefulWidget {
  const RegisterWidget({super.key});

  @override
  State<RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
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
      appBar: AppBar(title: const Text('Inscription')),
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
                    'S\'inscrire',
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
                            await apiService.register(
                                _usernameController.text,
                                _passwordController.text);

                        if (context.mounted == false) {
                          return;
                        }

                        if (response.containsKey('error')) {
                          setState(() {
                            _apiErrors.clear();
                            _apiErrors[response['errorField']] =
                                response['error'];
                            _formKey.currentState!.validate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Erreur d\'inscription.')));
                          return;
                        }
                        final User user = response['user'];
                        userProvider.setUser(user);

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TabBarWidget()),
                        );
                      } catch (e) {
                        if (context.mounted == false) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Erreur d\'inscription.')));
                        return;
                      }
                    },
                    child: const Text('S\'inscrire'),
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

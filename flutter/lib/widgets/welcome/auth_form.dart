
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/validators/auth_validator.dart';

typedef AuthApiCall = Future<Map<String, dynamic>> Function(String, String);

class AuthFormWidget extends StatefulWidget {
  final String title;
  final String buttonText;
  final AuthApiCall apiCall;
  final void Function(Map<String, dynamic> response, BuildContext context) onSuccess;

  const AuthFormWidget({
    super.key,
    required this.title,
    required this.buttonText,
    required this.apiCall,
    required this.onSuccess,
  });

  @override
  State<AuthFormWidget> createState() => _AuthFormWidgetState();
}


class _AuthFormWidgetState extends State<AuthFormWidget> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _apiErrors = {};
  bool _hasSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return GestureDetector(
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
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
                          await widget.apiCall(
                              _usernameController.text, _passwordController.text);

                      if (!mounted) return;

                      if (response.containsKey('error')) {
                        setState(() {
                          _apiErrors.clear();
                          _apiErrors[response['errorField']] = response['error'];
                          _formKey.currentState!.validate();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['error'] ?? 'Erreur.')),
                        );
                        return;
                      }

                      widget.onSuccess(response, context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erreur de connexion.')),
                      );
                    }
                  },
                  child: Text(widget.buttonText),
                ),
              ],
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
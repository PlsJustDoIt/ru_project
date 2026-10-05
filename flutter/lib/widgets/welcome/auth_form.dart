import 'package:flutter/material.dart';
import 'package:ru_project/validators/auth_validator.dart';

typedef AuthApiCall = Future<Map<String, dynamic>> Function(String, String);

class AuthFormWidget extends StatefulWidget {
  final String title;
  final String buttonText;
  final AuthApiCall apiCall;
  final Future<void> Function(Map<String, dynamic> response, BuildContext context)
      onSuccess;

  /// Texte d'aide affiché sous le titre (optionnel).
  final String? subtitle;

  const AuthFormWidget({
    super.key,
    required this.title,
    required this.buttonText,
    required this.apiCall,
    required this.onSuccess,
    this.subtitle,
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
  bool _submitting = false;
  bool _obscurePassword = true;

  /// Une erreur serveur ne vaut que pour la valeur soumise : dès que
  /// l'utilisateur corrige le champ, on l'efface.
  void _clearApiError(String field) {
    if (_apiErrors.remove(field) != null) setState(() {});
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSubmitted = true;
      _apiErrors.clear();
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final Map<String, dynamic> response = await widget.apiCall(
          _usernameController.text.trim(), _passwordController.text);

      if (!mounted) return;

      if (response.containsKey('error')) {
        setState(() {
          _apiErrors[response['errorField'] ?? 'username'] =
              response['error'] ?? 'Erreur.';
        });
        _formKey.currentState!.validate();
        return;
      }

      await widget.onSuccess(response, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Impossible de joindre le serveur. Vérifie ta connexion.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autovalidate = _hasSubmitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      autovalidateMode: autovalidate,
                      controller: _usernameController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                          labelText: 'Nom d\'utilisateur (3-32 caractères)'),
                      onChanged: (_) => _clearApiError('username'),
                      validator: (value) => validateUsername(value,
                          apiError: _apiErrors['username']),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      autovalidateMode: autovalidate,
                      controller: _passwordController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe (3-32 caractères)',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      onChanged: (_) => _clearApiError('password'),
                      validator: (value) => validatePassword(
                        value,
                        apiError: _apiErrors['password'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.buttonText),
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

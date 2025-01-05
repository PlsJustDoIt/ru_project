import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/welcome.dart';
import 'package:ru_project/widgets/custom_snack_bar.dart';

class ProfileWidget extends StatefulWidget {
  final statusList = ['en ligne', 'au ru', 'absent'];

  ProfileWidget({
    super.key,
  });

  @override
  State createState() => _ProfileWidgetState();
}

bool _isAvatarChanged = false;
final Map<String, String> _apiErrors = {};
final Duration _snackBarDuration = const Duration(seconds: 3);

class _ProfileWidgetState extends State<ProfileWidget> {
  late final ApiService _apiService;
  late final UserProvider _userProvider;
  late User? user;
  final ImagePicker _picker = ImagePicker();
  late String _selectedStatus;
  final _formKeyStatus = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  // Fonction pour choisir une image et l'envoyer au serveur via l'API
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedFile == null || mounted != true) {
        return;
      }
      String? avatarUrl = await _apiService.updateProfilePicture(pickedFile);
      if (mounted != true) {
        return;
      }
      if (avatarUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(message: 'Echec de la mise à jour de l\'image'),
        );
        return;
      } else {
        setState(() {
          user?.avatarUrl = avatarUrl;
          _isAvatarChanged = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(message: 'L\'image de profil a été mise à jour'),
        );
        return;
      }
    } catch (e) {
      logger.e('Error picking image: $e');
      if (mounted != true) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to pick image'),
          duration: _snackBarDuration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.i('Building profile widget');
    user = _userProvider.user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _selectedStatus = user!.status;

    //TODO : voir amélioration?
    Image imageAvatar = user!.avatarUrl.isEmpty
        ? Image.network(
            _apiService.getImageNetworkUrl("uploads/avatar/default-avatar.png"))
        : _isAvatarChanged
            ? Image.network(
                _apiService.getImageNetworkUrl(user!.avatarUrl),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  logger.e('Error loading avatar image: $error');
                  return Image.network(
                    _apiService.getImageNetworkUrl(
                        "uploads/avatar/default-avatar.png"),
                  );
                },
                // headers: {
                //   'Cache-Control': 'no-cache',
                // },
              )
            : Image.network(
                _apiService.getImageNetworkUrl(user!.avatarUrl),
              );

    if (_isAvatarChanged) {
      imageAvatar.image.evict();
      _isAvatarChanged = false;
    }

    return Center(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: imageAvatar.image,
                      ),
                      FloatingActionButton.small(
                        onPressed: _pickImage,
                        child: const Icon(Icons.camera_alt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user!.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
              statusFormNoButton(context),
              const SizedBox(height: 24),
              changeUsernameButton(context),
              const SizedBox(height: 24),
              changePassword(context),
              const SizedBox(height: 24),
              deleteAccountButton(context),
            ],
          )),
    );
  }

  // Bouton pour supprimer le compte
  ElevatedButton deleteAccountButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Supprimer le compte'),
              content: const Text(
                  'Êtes-vous sûr de vouloir supprimer votre compte?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => {
                    deleteAccount(context),
                  },
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        ),
      },
      child: const Text('Supprimer le compte'),
    );
  }

  void deleteAccount(BuildContext context) async {
    try {
      bool isSuccess = await _apiService.deleteAccount();
      if (isSuccess) {
        _userProvider.logout();
        if (context.mounted == false) {
          return;
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Compte supprimé avec succès'),
            duration: _snackBarDuration,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeWidget()),
        );
        return;
      }
      throw Exception('Failed to delete account');
    } catch (e) {
      logger.e('Error deleting account: $e');
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur de suppression du compte'),
          duration: _snackBarDuration,
        ),
      );
      return;
    }
  }

  // Bouton pour changer le nom d'utilisateur
  ElevatedButton changeUsernameButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return ProfileDialog(
                onUsernameChanged: (newUsername) {
                  setState(() {
                    user!.username =
                        newUsername; // Met à jour le nom d'utilisateur
                  });
                },
                updateData: _apiService.updateUsername,
                optionDialog: 'username',
                username: user!.username,
                title: 'Changer le nom d\'utilisateur',
                userProvider: _userProvider);
          },
        );
      },
      child: const Text('Changer le nom d\'utilisateur'),
    );
  }

  // void updateUsername(String newUsername) async {
  //   Map<String, dynamic> response =
  //       await _apiService.updateUsername(newUsername);
  //   if (response['success']) {
  //     setState(() {
  //       user!.username = response['username'];
  //     });
  //     if (context.mounted == false) {
  //       return;
  //     }

  //     widget.onUsernameChanged(newUsername);
  //     return;
  //   }
  // }

  // Bouton pour changer le mot de passe
  ElevatedButton changePassword(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => {
        showDialog(
          context: context,
          builder: (context) {
            return ProfileDialog(
                updateData: _apiService.updatePassword,
                optionDialog: 'password',
                title: 'Changer le mot de passe');
          },
        ),
      },
      child: const Text('Changer le mot de passe'),
    );
  }

  Form statusFormNoButton(BuildContext context) {
    return Form(
      key: _formKeyStatus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emoji_emotions),
              focusColor: Colors.blue,
            ),
            items: widget.statusList.map((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                });
              }
              confirmStatus(context);
            },
          ),
        ],
      ),
    );
  }

  void confirmStatus(BuildContext context) async {
    if (_userProvider.user!.status == _selectedStatus) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Le status est déjà à jour'),
        duration: _snackBarDuration,
      ));
      return;
    }

    try {
      var response = await _apiService.updateStatus(_selectedStatus);
      bool success = response['success'];

      if (!success) {
        throw Exception(response['error']);
      }

      _userProvider.user!.status = response['status'];

      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status mis à jour avec succès.'),
          duration: _snackBarDuration));
    } catch (e) {
      logger.e('Error updating status: $e');
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de mise à jour du status'),
          duration: _snackBarDuration));
      return;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

//class pour les dialog de changement de username
class ProfileDialog extends StatelessWidget {
  final dynamic updateData;
  final String title;
  final String optionDialog;
  final String? username;
  final UserProvider? userProvider;
  final Function(String)? onUsernameChanged;

  const ProfileDialog({
    super.key,
    required this.updateData,
    required this.optionDialog,
    required this.title,
    this.userProvider,
    this.username,
    this.onUsernameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            automaticallyImplyLeading: true,
          ),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      optionDialog == 'password'
                          ? PasswordForm(updatePassword: updateData)
                          : optionDialog == 'username'
                              ? UsernameForm(
                                  userProvider: userProvider!,
                                  updateUsername: updateData,
                                  onUsernameChanged: onUsernameChanged!,
                                  username: username!)
                              : CircularProgressIndicator.adaptive(),
                    ],
                  ))),
        ));
  }
}

class UsernameForm extends StatefulWidget {
  const UsernameForm({
    super.key,
    required this.updateUsername,
    required this.username,
    required this.userProvider,
    required this.onUsernameChanged,
  });

  final Future<Map<String, dynamic>> Function(String) updateUsername;
  final String username;
  final UserProvider userProvider;
  final Function(String) onUsernameChanged;

  @override
  State<UsernameForm> createState() => _UsernameFormState();
}

class _UsernameFormState extends State<UsernameForm> {
  late TextEditingController _usernameController;
  final _formKeyUsername = GlobalKey<FormState>();
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    //_usernameController.text = ;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKeyUsername,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (_apiErrors.containsKey('username')) {
                return _apiErrors['username'];
              }
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un nom d\'utilisateur';
              }
              if (value.trim().length < 3) {
                return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le nom d\'utilisateur doit contenir moins de 32 caractères';
              }
              if (value.trim() == widget.username) {
                return 'Le nom d\'utilisateur doit être différent de l\'ancien';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => confirmUsername(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void confirmUsername(BuildContext context) async {
    _apiErrors.clear();
    if (_formKeyUsername.currentState?.validate() == false) {
      return;
    }

    try {
      Map<String, dynamic> response =
          await widget.updateUsername(_usernameController.text);
      if (response["success"]) {
        widget.userProvider.user!.username = response["username"];
        widget.onUsernameChanged(response["username"]);
        if (context.mounted == false) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Nom d\'utilisateur mis à jour avec succès.'),
            duration: _snackBarDuration));
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _apiErrors.clear();
        _apiErrors['username'] = response["error"];
        _formKeyUsername.currentState?.validate();
        _hasSubmitted = true;
      });

      throw Exception('Failed to update username');
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de mise à jour du nom d\'utilisateur'),
          duration: _snackBarDuration));
      return;
    }
  }
}

class PasswordForm extends StatefulWidget {
  PasswordForm({
    super.key,
    required this.updatePassword,
  });
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final _formKeyPassword = GlobalKey<FormState>();
  final Future<Map<String, dynamic>> Function(String, String) updatePassword;

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  late TextEditingController _oldPasswordController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _passwordConfirmController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget._formKeyPassword,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget._oldPasswordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Mot de passe actuel',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (_apiErrors.containsKey('oldPassword')) {
                return _apiErrors['oldPassword'];
              }
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim().length < 3) {
                return 'Le mot de passe doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le mot de passe doit contenir moins de 32 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget._passwordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (_apiErrors.containsKey('password')) {
                return _apiErrors['password'];
              }
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim().length < 3) {
                return 'Le mot de passe doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le mot de passe doit contenir moins de 32 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget._passwordConfirmController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim() != widget._passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => confirmPassword(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void confirmPassword(BuildContext context) async {
    _apiErrors.clear();
    if (widget._formKeyPassword.currentState?.validate() == false) {
      return;
    }

    try {
      Map<String, dynamic> response = await widget.updatePassword(
          widget._passwordController.text, widget._oldPasswordController.text);
      if (response["success"]) {
        if (context.mounted == false) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Mot de passe mis à jour avec succès.'),
          duration: _snackBarDuration,
        ));
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _apiErrors.clear();
        _apiErrors[response["errorField"]] = response["error"];
        widget._formKeyPassword.currentState?.validate();
        _hasSubmitted = true;
      });
      throw Exception('Failed to update password');
    } catch (e) {
      logger.e('Error updating password: $e');
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de mise à jour du mot de passe'),
          duration: _snackBarDuration));
      return;
    }
  }
}

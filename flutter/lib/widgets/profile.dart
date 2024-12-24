import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/search_widget.dart';
import 'package:ru_project/services/cache_service.dart';
import 'package:ru_project/widgets/welcome.dart';

// enum UserStatus {
//   enLigne,
//   auRu,
//   absent;

//   String toDisplayString() {
//     switch (this) {
//       case UserStatus.enLigne:
//         return 'en ligne';
//       case UserStatus.auRu:
//         return 'au ru';
//       case UserStatus.absent:
//         return 'absent';
//     }
//   }

//   static UserStatus fromString(String status) {
//     switch (status.toLowerCase()) {
//       case 'en ligne':
//         return UserStatus.enLigne;
//       case 'au ru':
//         return UserStatus.auRu;
//       case 'absent':
//         return UserStatus.absent;
//       default:
//         return UserStatus.absent; // Default value
//     }
//   }
// }

bool _isAvatarChanged = false;

class ProfileWidget extends StatefulWidget {
  late User? user;
  final statusList = ['en ligne', 'au ru', 'absent'];

  ProfileWidget({
    super.key,
  });

  @override
  State createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  final _formKeyUsername = GlobalKey<FormState>();
  final _formKeyStatus = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _passwordController;
  late TextEditingController
      _passwordConfirmController; //TODO add confirm password part
  //File? _imageFile;
  //Image imageDefault = Image.asset('assets/images/default-avatar.png');
  final ImagePicker _picker = ImagePicker();
  late String _selectedStatus;
  bool hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    widget.user = context.read<UserProvider>().user;
    if (widget.user != null) {
      _usernameController = TextEditingController(text: widget.user?.username);
      _oldPasswordController = TextEditingController();
      _passwordController = TextEditingController();
      _passwordConfirmController = TextEditingController();
      _selectedStatus = widget.user!.status;
    }
  }

  // Fonction pour choisir une image et l'envoyer au serveur via l'API TODO : recupérer l'image du serveur (qui devrait être renvoyée par l'API) et la mettre dans le cache
  Future<void> _pickImage() async {
    logger.i('Picking image');
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedFile == null) {
        logger.w('No image selected');
        return;
      }
      logger.i('Image picked: ${pickedFile.path}');

      if (mounted != true) {
        logger.w('Component is not mounted before updating profile picture');
        return;
      }

      String? avatarUrl =
          await context.read<ApiService>().updateProfilePicture(pickedFile);

      if (mounted != true) {
        logger.w('Component is not mounted after updating profile picture');
        return;
      }

      if (avatarUrl == null) {
        logger.w('Failed to update profile picture');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Echec de la mise à jour de l\'image')),
        );
        return;
      } else {
        setState(() {
          widget.user!.avatarUrl = avatarUrl;
          _isAvatarChanged = true;
        });
        logger.i('Profile picture updated');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'image de profil a été mise à jour')),
        );
        return;
      }

      // if (rawImageFile != null) {
      //   final resImage = await AvatarCache.cacheAvatar(rawImageFile, 'avatar.jpg');
      //   if (mounted != true) {
      //     logger.w('Component is not mounted after caching image');
      //     return;
      //   }
      //   if (resImage != null) {
      //     setState(() {
      //       _imageFile = resImage;
      //     });
      //     logger.i('Profile picture updated');
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Profile picture updated')),
      //     );
      //     return;
      //   }
      //   logger.w('Failed to cache image');
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Failed to cache image')),
      //   );
      //   return;
      // }

      logger.w('Failed to update profile picture');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile picture')),
      );
    } catch (e) {
      logger.e('Error picking image: $e');
      if (mounted != true) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  // //set imageFile from server TODO
  // Future<void> setImage() async {
  //   //logger.i('Setting image from server not implemented');
  //   //default image
  //   final Uint8List rawImageFile;
  //   try {
  //     rawImageFile = await context.read<ApiService>().getUserRawAvatar(context.read<UserProvider>().user!.avatarUrl);
  //   } catch (e) {
  //     logger.e('Failed to get image from server: $e');
  //     if (context.mounted == false) {
  //       return;
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Failed to get image from server')),
  //     );
  //     return;
  //   }
  //   final resImage = await AvatarCache.cacheAvatar(rawImageFile, 'avatar.jpg');

  //   if (resImage != null) {
  //     logger.i('Image set from server');
  //     setState(() {
  //       _imageFile = resImage;
  //     });
  //   } else {
  //     logger.w('Failed to set image from server in cache (web client?)');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Failed to set image from server')),
  //     );
  //   }

  // }

  @override
  Widget build(BuildContext context) {
    logger.i('Building profile widget');

    final ApiService apiService =
        Provider.of<ApiService>(context, listen: false);
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);

    if (userProvider.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    String fullUrl;
    if (widget.user!.avatarUrl.isEmpty) {
      fullUrl =
          apiService.getImageNetworkUrl("uploads/avatar/default-avatar.png");
    } else {
      fullUrl = apiService.getImageNetworkUrl(widget.user!.avatarUrl);
    }

    Image imageAvatar = Image.network(fullUrl);

    if (_isAvatarChanged) {
      imageAvatar.image.evict();
      _isAvatarChanged = false;
    }

    logger.i(widget.user!.avatarUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(height: 32),
          Text(
            "Bonjour, ${widget.user!.username}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          statusFormNoButton(apiService, userProvider, context),
          const SizedBox(height: 16),
          changeUsernameButton(apiService, userProvider, context),
          const SizedBox(height: 16),
          changePassword(apiService, userProvider, context),
          const SizedBox(height: 16),
          deleteAccountButton(apiService, userProvider, context),
        ],
      ),
    );
  }

  // Bouton pour supprimer le compte
  ElevatedButton deleteAccountButton(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
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
                    deleteAccount(apiService, userProvider, context),
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

  void deleteAccount(ApiService apiService, UserProvider userProvider,
      BuildContext context) async {
    logger.i('Deleting account');
    try {
      bool isSuccess = await apiService.deleteAccount();
      if (isSuccess) {
        userProvider.logout();
        if (context.mounted == false) {
          return;
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte supprimé avec succès')),
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
        const SnackBar(content: Text('Erreur de suppression du compte')),
      );
      return;
    }
  }

  // Bouton pour changer le nom d'utilisateur
  ElevatedButton changeUsernameButton(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return changeThingsDialogs(
                true, false, false, apiService, userProvider, context);
          },
        );
      },
      child: const Text('Changer le nom d\'utilisateur'),
    );
  }

  // Bouton pour changer le mot de passe
  ElevatedButton changePassword(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => {
        logger.i('Change password button pressed'),
        showDialog(
          context: context,
          builder: (context) {
            return changeThingsDialogs(
                false, true, false, apiService, userProvider, context);
          },
        ),
      },
      child: const Text('Changer le mot de passe'),
    );
  }

  //fonction avec des paramètres pour afficher le dialog selon les requis, stateless widget TODO dans une autre classe dans se fichier
  StatelessWidget changeThingsDialogs(
      bool isModifyingUsername,
      bool isModifyingPassword,
      bool isModifyingStatus,
      ApiService apiService,
      UserProvider userProvider,
      BuildContext context) {
    //temporaire
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          title: Text(isModifyingUsername
              ? 'Changer le nom d\'utilisateur'
              : isModifyingPassword
                  ? 'Changer le mot de passe'
                  : 'Changer le status'),
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isModifyingUsername
              ? usernameForm(apiService, userProvider, context)
              : isModifyingPassword
                  ? passwordForm(apiService, userProvider, context)
                  : statusFormNoButton(apiService, userProvider, context),
        ),
      ),
    );
  }

  Form usernameForm(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
    return Form(
      key: _formKeyUsername,
      autovalidateMode: hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour le nom d'utilisateur
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Nouveau nom d\'utilisateur',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              // Validation du nom d'utilisateur
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un nom d\'utilisateur';
              }
              if (value.trim().length < 3) {
                return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le nom d\'utilisateur doit contenir moins de 32 caractères';
              }
              //test si le meme
              if (value.trim() == userProvider.user!.username) {
                return 'Le nom d\'utilisateur doit être différent de l\'ancien';
              }
              // Validation réussie
              return null;
            },
          ),

          SizedBox(height: 20),

          // Bouton de mise à jour
          ElevatedButton(
            onPressed: () => comfirmUsername(apiService, userProvider, context),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Form passwordForm(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
    return Form(
      key: _formKeyPassword,
      autovalidateMode: hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour l'ancien mot de passe
          TextFormField(
            controller: _oldPasswordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Mot de passe actuel',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              // Validation du mot de passe
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim().length < 3) {
                return 'Le mot de passe doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le mot de passe doit contenir moins de 32 caractères';
              }
              // Validation réussie
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Champ de texte pour le mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              // Validation du mot de passe
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim().length < 3) {
                return 'Le mot de passe doit contenir au moins 3 caractères';
              }
              if (value.trim().length > 32) {
                return 'Le mot de passe doit contenir moins de 32 caractères';
              }
              // Validation réussie
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Champ de texte pour la confirmation du mot de passe
          TextFormField(
            controller: _passwordConfirmController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              // Validation du mot de passe
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value.trim() != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              // Validation réussie
              return null;
            },
          ),

          SizedBox(height: 20),

          // Bouton de mise à jour
          ElevatedButton(
            onPressed: () => comfirmPassword(apiService, userProvider, context),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Form statusFormNoButton(
      ApiService apiService, UserProvider userProvider, BuildContext context) {
    return Form(
      key: _formKeyStatus,
      autovalidateMode: hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour le status
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emoji_emotions),
              //focusedBorder: OutlineInputBorder(),
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
              comfirmStatus(apiService, userProvider, context, false);
            },
          ),
        ],
      ),
    );
  }

  void comfirmUsername(ApiService apiService, UserProvider userProvider,
      BuildContext context) async {
    setState(() {
      hasSubmitted = true;
    });
    if (!_formKeyUsername.currentState!.validate()) {
      logger.e('username unvalide: ${_usernameController.text}');
      return;
    }

    try {
      bool success = await apiService.updateUsername(_usernameController.text);
      if (success) {
        userProvider.user!.username = _usernameController.text;

        logger.i('New username: ${_usernameController.text}');

        setState(() {
          hasSubmitted = false;
        });

        if (context.mounted == false) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Nom d\'utilisateur mis à jour avec succès.')));
        Navigator.of(context).pop();
      }
      throw Exception('Failed to update username');
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de mise à jour du nom d\'utilisateur')));
      return;
    }
  }

  void comfirmPassword(ApiService apiService, UserProvider userProvider,
      BuildContext context) async {
    setState(() {
      hasSubmitted = true;
    });
    if (!_formKeyPassword.currentState!.validate()) {
      logger.e('error password form');
      return;
    }

    try {
      bool success = await apiService.updatePassword(
          _passwordController.text, _oldPasswordController.text);
      if (success) {
        logger.i('New password: ${_passwordController.text}');
        setState(() {
          hasSubmitted = false;
        });
        if (context.mounted == false) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mot de passe mis à jour avec succès.')));
        Navigator.of(context).pop();
      }
      throw Exception('Failed to update password');
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du mot de passe')));
      return;
    }
  }

  void comfirmStatus(ApiService apiService, UserProvider userProvider,
      BuildContext context, bool isDialog) async {
    if (userProvider.user!.status == _selectedStatus) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Le status est déjà à jour')));
      return;
    }

    try {
      var response = await apiService.updateStatus(_selectedStatus);
      bool success = response['success'];

      if (!success) {
        throw Exception(response['error']);
      }

      userProvider.user!.status = response['status'];

      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status mis à jour avec succès.')));
    } catch (e) {
      logger.e('Error updating status: $e');
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du status')));
      return;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}

// Exemple d'utilisation
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  Future<List<SearchResult>> performSearch(String query) async {
    // Dans la pratique, appelez votre API ici
    // final response = await apiClient.search(
    //   query: query,
    //   limit: 20,
    //   // Paramètres de contexte pour améliorer la pertinence
    //   userLocation: currentLocation,
    //   userLanguage: deviceLanguage,
    //   recentInteractions: userRecentActivity,
    // );
    // return response.results;
    return List.generate(10, (index) {
      return SearchResult(
        id: index.toString(),
        name: 'Result $index',
        relevanceScore: 10.0 - index,
        photoUrl: "",
        type: 'friend',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RealtimeSearchWidget(
        onRemoteSearch: performSearch,
        debounceDuration: const Duration(milliseconds: 150),
      ),
    );
  }
}

/*
username, password : min 3 caractères, max 32 char and not empty and not null and not only spaces 

status : en ligne, au ru, absent //TODO backend

avatar :
 .jpg .jpeg 
 /uploads/avatars/id/avatar.jpg
 */

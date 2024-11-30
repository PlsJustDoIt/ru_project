import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/search_widget.dart';

enum UserStatus {
  enLigne,
  auRu,
  absent;

  String toDisplayString() {
    switch (this) {
      case UserStatus.enLigne:
        return 'en ligne';
      case UserStatus.auRu:
        return 'au ru';
      case UserStatus.absent:
        return 'absent';
    }
  }

  static UserStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'en ligne':
        return UserStatus.enLigne;
      case 'au ru':
        return UserStatus.auRu;
      case 'absent':
        return UserStatus.absent;
      default:
        return UserStatus.absent; // Default value
    }
  }
}


class ProfileWidget extends StatefulWidget {
  late User? user;

  ProfileWidget({
    super.key,
  });

  @override
  _ProfileWidgetState createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late UserStatus _selectedStatus;
  bool hasSubmitted = false;
  

  @override
  void initState() {
    super.initState();
    widget.user = context.read<UserProvider>().user;
    if (widget.user != null) {
      _usernameController = TextEditingController(text: widget.user?.username);
      _passwordController = TextEditingController();
      _passwordConfirmController = TextEditingController();
      _selectedStatus = UserStatus.fromString(widget.user!.status);
    }
    
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted != true) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final ApiService apiService = Provider.of<ApiService>(context, listen: false);
    final UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
    
    return  SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : const AssetImage('assets/images/default-avatar.png')
                          as ImageProvider,
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
          ],
        ),
      );
  }
  //fonction avec des paramètres pour afficher le dialog selon les requis, stateless widget

  // Bouton pour changer le nom d'utilisateur
  ElevatedButton changeUsernameButton(ApiService apiService, UserProvider userProvider,BuildContext context){

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () { 
        showDialog(
          context: context,
          builder: (context) {
            return changeThingsDialogs(true,false,false,apiService,userProvider,context);
          },
        );
      },
      child: const Text('Changer le nom d\'utilisateur'),
    );
  }

  // Bouton pour changer le mot de passe
  ElevatedButton changePassword(ApiService apiService, UserProvider userProvider,BuildContext context){
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => {
        logger.i('Change password button pressed'),
        showDialog(
          context: context,
          builder: (context) {
            return changeThingsDialogs(false,true,false,apiService,userProvider,context);
          },
        ),
      },
      child: const Text('Changer le mot de passe'),
    );
  }

  //TODO garder le truc dans form ?... //TODO to rm?
  ElevatedButton changeStatus(ApiService apiService, UserProvider userProvider,BuildContext context){
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => {
        logger.i('Change status button pressed'),
        showDialog(
          context: context,
          builder: (context) {
            return changeThingsDialogs(false,false,true,apiService,userProvider,context);
          },
        ),
      },
      child: const Text('Changer le status'),
    );
  }

  //fonction avec des paramètres pour afficher le dialog selon les requis, stateless widget TODO dans une autre classe dans se fichier
  StatelessWidget changeThingsDialogs(bool isModifyingUsername,bool isModifyingPassword,bool isModifyingStatus, ApiService apiService, UserProvider userProvider,BuildContext context){
    //temporaire
    return Dialog(child: Scaffold(
        appBar: AppBar(
          title: Text(isModifyingUsername ? 'Changer le nom d\'utilisateur' : isModifyingPassword ? 'Changer le mot de passe' : 'Changer le status'),
          automaticallyImplyLeading: true,
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isModifyingUsername ? usernameForm(apiService, userProvider, context) : isModifyingPassword ? passwordForm(apiService, userProvider, context) : statusForm(apiService, userProvider, context),
        ),
      ),
    );
  }

  Form usernameForm(ApiService apiService, UserProvider userProvider,BuildContext context){
    return Form(
      key: _formKey,
      autovalidateMode: hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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

  Form passwordForm (ApiService apiService, UserProvider userProvider,BuildContext context){
    return Form(
      key: _formKey,
      autovalidateMode: hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour le mot de passe
          TextFormField(
            controller: _passwordController,
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

  Form statusForm(ApiService apiService, UserProvider userProvider,BuildContext context){
    return Form(
      key: _formKey,
      autovalidateMode: hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour le status
          DropdownButtonFormField<UserStatus>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emoji_emotions),
            ),
            items: UserStatus.values.map((UserStatus status) {
              return DropdownMenuItem<UserStatus>(
                value: status,
                child: Text(status.toDisplayString()),
              );
            }).toList(),
            onChanged: (UserStatus? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                });
              }
            },
          ),
          
          SizedBox(height: 20),
          
          // Bouton de mise à jour
          ElevatedButton(
            onPressed: () => comfirmStatus(apiService, userProvider, context,true),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Form statusFormNoButton(ApiService apiService, UserProvider userProvider,BuildContext context){
    return Form(
      key: _formKey,
      autovalidateMode: hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de texte pour le status
          DropdownButtonFormField<UserStatus>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emoji_emotions),
            ),
            items: UserStatus.values.map((UserStatus status) {
              return DropdownMenuItem<UserStatus>(
                value: status,
                child: Text(status.toDisplayString()),
              );
            }).toList(),
            onChanged: (UserStatus? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                });
              }
              comfirmStatus(apiService, userProvider, context,false);
            },
          ),
        ],
      ),
    );
  }

  void comfirmUsername(ApiService apiService, UserProvider userProvider,BuildContext context) async {
    setState(() {
      hasSubmitted = true;
    });
    if (_formKey.currentState!.validate()) {
      logger.i('username unvalide: ${_usernameController.text}');                      
    }
    
    bool res;
    try {
      res = await apiService.updateUsername(_usernameController.text);
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du nom d\'utilisateur')));
      return;
    }
    if (context.mounted == false) {
      return;
    }
    if (!res) {
      
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du nom d\'utilisateur')));
        
      return;
    }
    
    //setUser TODO se renseigner si il faut faire un get user 
    userProvider.user!.username = _usernameController.text;

    logger.i('New username: ${_usernameController.text}');

    setState(() {
      hasSubmitted = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nom d\'utilisateur mis à jour avec succès.')));
    Navigator.of(context).pop();
  }

  void comfirmPassword(ApiService apiService, UserProvider userProvider,BuildContext context) async {
    setState(() {
      hasSubmitted = true;
    });
    if (_formKey.currentState!.validate()) {
      logger.i('password unvalide: ${_passwordController.text}');                      
    }
    
    bool res;
    try {
      res = await apiService.updatePassword(_passwordController.text);
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du mot de passe')));
      return;
    }
    if (context.mounted == false) {
      return;
    }
    if (!res) {
      
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du mot de passe')));
        
      return;
    }

    logger.i('New password: ${_passwordController.text}');

    setState(() {
      hasSubmitted = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mot de passe mis à jour avec succès.')));
    Navigator.of(context).pop();
  }

  void comfirmStatus(ApiService apiService, UserProvider userProvider,BuildContext context,bool isDialog) async {
    if (_formKey.currentState!.validate()) {
      logger.i('status unvalide: ${_selectedStatus.toDisplayString()}');                      
    }
    
    bool res;
    try {
      res = await apiService.updateStatus(_selectedStatus.toDisplayString());
    } catch (e) {
      if (context.mounted == false) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du status')));
      return;
    }
    if (context.mounted == false) {
      return;
    }
    if (!res) {
      
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du status')));
        
      return;
    }

    logger.i('New status: ${_selectedStatus.toDisplayString()}');

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status mis à jour avec succès.')));

    if(isDialog){
      Navigator.of(context).pop();
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
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
  State createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late UserStatus _selectedStatus;
  

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

  Future<void> _saveChanges() async {
    final ApiService apiService = Provider.of<ApiService>(context, listen: false);

    // Validate form

    /*
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    */

    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> updatedUser = {
        'username' : _usernameController.text,
        'status' : _selectedStatus.toDisplayString(),
        'friendIds' : widget.user!.friendIds,
        'password' : _passwordController.text,
      };
      
      bool res = await apiService.updateUser(updatedUser);

      if (mounted != true) {
        return;
      }

      if (!res) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile failed to update')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return  SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (3-32 caractères)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) { //TODO ?? Secure username/imput
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom d\'utilisateur';
                  }
                  if (value.trim().isEmpty) {
                    return 'Veuillez entrer un nom d\'utilisateur valide';
                  }
                  if (value.length > 32) {
                    return 'Le nom d\'utilisateur doit être inférieur à 32 caractères';
                  }
                  if (value.length < 3) {
                    return 'Le nom d\'utilisateur doit être supérieur à 3 caractères';
                  }
                  return null;
                },
                onSaved: (value) {
                  // TODO mettre à jour le nom d'utilisateur à implémenter
                  logger.i('Username saved: $value');
                },
              ),
              //password :
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(             
                  labelText: 'Mot de passe (3-32 caractères)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) { //TODO ?? Secure password/imput
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe (3-32 caractères)';
                  }
                  if (value.trim().isEmpty) {
                    return 'Veuillez entrer un mot de passe valide';
                  }
                  if (value.length < 3) { 
                    return 'Le mot de passe doit être supérieur à 3 caractères';
                  }
                  if (value.length > 32) {
                    return 'Le mot de passe doit être inférieur à 32 caractères';
                  }
                  return null;
                },
                onSaved: (value) {
                  logger.i('Password saved: $value');
                },
              ),
              //comfirm password : //TODO compare password TODO add validator
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordConfirmController,
                decoration: InputDecoration(             
                  labelText: 'Confirmer le mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
                onSaved: (value) {
                  //  TODO mettre à jour le mot de passe implémenter
                  logger.i('Password saved: $value');
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Sauvegarder les modifications'),
              ),
              
            ],
          ),
        ),
    );
  }

  //change username widget

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
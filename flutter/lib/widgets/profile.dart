import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:ru_project/models/user.dart';

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
  final User? user;
  final Function(User) onUserUpdated;

  const ProfileWidget({
    super.key, 
    required this.user,
    required this.onUserUpdated,
  });

  @override
  _ProfileWidgetState createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late UserStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user!.username);
    _selectedStatus = UserStatus.fromString(widget.user!.status);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final updatedUser = User(
        id: widget.user!.id,
        username: _usernameController.text,
        status: _selectedStatus.toDisplayString(),
        friends: widget.user!.friends,
      );
      
      widget.onUserUpdated(updatedUser);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
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
                        : const AssetImage('images/default-avatar.png') 
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
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
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
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}
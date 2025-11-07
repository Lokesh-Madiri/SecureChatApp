import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:lottie/lottie.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _profileImageUrl = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _chatService.getUserData(_currentUser.uid);
      if (userData != null) {
        _nameController.text = userData['name'] ?? '';
        _profileImageUrl = userData['profileImage'] ?? '';
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null || _nameController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.updateUserProfile(_currentUser.uid, {
        'name': _nameController.text,
        'profileImage': _profileImageUrl,
      });

      // Update display name in Firebase Auth
      await _currentUser.updateDisplayName(_nameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null && _currentUser != null) {
        setState(() {
          _isLoading = true;
        });

        // Read image bytes
        final bytes = await image.readAsBytes();

        // Encode as Base64
        final base64Image = base64Encode(bytes);

        // Store in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .update({'profileImage': base64Image});

        setState(() {
          _profileImageUrl = "null"; // You may want to update this logic
          _isLoading = false;
        });

        // Update local model/service if needed
        await _chatService.updateUserProfile(_currentUser.uid, {
          'profileImage': base64Image,
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF128C7E),
      ),
      body: _isLoading
          ? Center(
              child: Lottie.asset(
                'assets/loading_animation.json', // your Lottie JSON file
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl) as ImageProvider
                            : const AssetImage(
                                'assets/images/default_avatar.png',
                              ),
                        backgroundColor: const Color.fromARGB(
                          255,
                          255,
                          253,
                          253,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF128C7E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(60, 255, 255, 255),
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Color.fromARGB(97, 255, 255, 255),
                              size: 20,
                            ),
                            onPressed: _uploadProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _currentUser?.email ?? '',
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabled: false,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text('Update Profile'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

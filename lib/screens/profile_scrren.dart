import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Design Colors
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _onSurfaceColor = Colors.white;
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _successColor = const Color(0xFF10B981);

  String _profileImageUrl = '';
  String _profileImageBase64 = '';
  bool _isLoading = false;
  bool _isEditing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _chatService.getUserData(_currentUser!.uid);
      if (userData != null) {
        _nameController.text = userData['name'] ?? '';
        _bioController.text =
            userData['bio'] ?? 'Hey there! I am using Secure Chat';
        _profileImageUrl = userData['profileImage'] ?? '';
        _profileImageBase64 = userData['profileImageBase64'] ?? '';
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
      await _chatService.updateUserProfile(_currentUser!.uid, {
        'name': _nameController.text,
        'bio': _bioController.text,
        'profileImage': _profileImageUrl,
        'profileImageBase64': _profileImageBase64,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update display name in Firebase Auth
      await _currentUser!.updateDisplayName(_nameController.text);

      _showSuccessSnackBar('Profile updated successfully');
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: ${e.toString()}');
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
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null && _currentUser != null) {
        setState(() {
          _isLoading = true;
        });

        // Read image bytes
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _profileImageBase64 = base64Image;
          _isEditing = true;
        });

        _showSuccessSnackBar('Profile image updated');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null && _currentUser != null) {
        setState(() {
          _isLoading = true;
        });

        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _profileImageBase64 = base64Image;
          _isEditing = true;
        });

        _showSuccessSnackBar('Profile photo taken successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _onSurfaceColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Update Profile Picture',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: _uploadProfileImage,
                      ),
                      _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: _takeProfilePhoto,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primaryColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: _primaryColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Sign Out', style: TextStyle(color: _onSurfaceColor)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _onSurfaceColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _onSurfaceColor)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        _showErrorSnackBar('Error signing out: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: _successColor),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _surfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: _errorColor),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _surfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reload original data when canceling
        _loadUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    // Profile Header
                    SliverAppBar(
                      expandedHeight: 200,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primaryColor, _secondaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(
                            _isEditing ? Icons.close : Icons.edit,
                            color: Colors.white,
                          ),
                          onPressed: _toggleEditing,
                        ),
                      ],
                    ),

                    // Profile Content
                    SliverList(
                      delegate: SliverChildListDelegate([
                        // Profile Picture Section
                        Container(
                          transform: Matrix4.translationValues(0, -60, 0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _surfaceColor,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 56,
                                      backgroundColor: _surfaceColor,
                                      child: _profileImageBase64.isNotEmpty
                                          ? ClipOval(
                                              child: Image.memory(
                                                base64Decode(
                                                  _profileImageBase64,
                                                ),
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return _buildDefaultAvatar();
                                                    },
                                              ),
                                            )
                                          : _buildDefaultAvatar(),
                                    ),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _surfaceColor,
                                            width: 3,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: _showImageSourceDialog,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text
                                    : 'Your Name',
                                style: TextStyle(
                                  color: _onSurfaceColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentUser?.email ?? '',
                                style: TextStyle(
                                  color: _onSurfaceColor.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Profile Form
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Bio Section
                              _buildSectionHeader('About Me'),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                maxLength: 150,
                                enabled: _isEditing,
                                style: TextStyle(color: _onSurfaceColor),
                                decoration: InputDecoration(
                                  hintText: 'Tell us about yourself...',
                                  hintStyle: TextStyle(
                                    color: _onSurfaceColor.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: _surfaceColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _surfaceColor.withOpacity(0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Personal Information Section
                              _buildSectionHeader('Personal Information'),
                              const SizedBox(height: 16),
                              _buildInfoField(
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                controller: _nameController,
                                isEditing: _isEditing,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoField(
                                label: 'Email',
                                icon: Icons.email_outlined,
                                value: _currentUser?.email ?? 'Not available',
                                isEditing: false,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoField(
                                label: 'Member Since',
                                icon: Icons.calendar_today,
                                value:
                                    _currentUser?.metadata.creationTime != null
                                    ? DateFormat('MMM dd, yyyy').format(
                                        _currentUser!.metadata.creationTime!,
                                      )
                                    : 'Unknown',
                                isEditing: false,
                              ),

                              const SizedBox(height: 40),

                              // Action Buttons
                              if (_isEditing) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _updateProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: _toggleEditing,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _onSurfaceColor,
                                      side: BorderSide(
                                        color: _onSurfaceColor.withOpacity(0.3),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _toggleEditing,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Sign Out Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: _signOut,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _errorColor,
                                    side: BorderSide(color: _errorColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Sign Out'),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: _onSurfaceColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField({
    required String label,
    required IconData icon,
    TextEditingController? controller,
    String? value,
    required bool isEditing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: isEditing && controller != null
                ? TextFormField(
                    controller: controller,
                    style: TextStyle(color: _onSurfaceColor),
                    decoration: InputDecoration.collapsed(
                      hintText: label,
                      hintStyle: TextStyle(
                        color: _onSurfaceColor.withOpacity(0.5),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: _onSurfaceColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value ?? controller?.text ?? '',
                        style: TextStyle(
                          color: _onSurfaceColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 48),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/loading_animation.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Profile...',
            style: TextStyle(
              color: _onSurfaceColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  User? _currentUser;
  bool _isEditing = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view your profile';
        });
        return;
      }

      final userData = jsonDecode(userJson);
      _currentUser = User.fromJson(userData);
      _nameController.text = _currentUser!.fullName;
      _emailController.text = _currentUser!.email;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load profile data';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _profileService.updateProfile(
        userId: _currentUser!.id,
        fullName: _nameController.text,
        email: _emailController.text,
      );

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to update profile';
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _profileService.updatePassword(
        userId: _currentUser!.id,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      setState(() {
        _isChangingPassword = false;
        _isLoading = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      print('Error changing password: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final imageBytes = await pickedFile.readAsBytes();
      await _profileService.uploadAvatar(_currentUser!.id, imageBytes);

      await _loadUserProfile();
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to upload image';
      });
    }
  }

  Future<void> _deleteAvatar() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _profileService.deleteAvatar(_currentUser!.id);
      await _loadUserProfile();
    } catch (e) {
      print('Error deleting avatar: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to delete avatar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const Center(
        child: Text('Profile Section'),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/analytics_service.dart';
import '../../services/profile_service.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin {
  User? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  String? _error;

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _userBio;

  // Services
  final ProfileService _profileService = ProfileService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Analytics data
  Map<String, dynamic>? _analyticsData;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // UUID
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        throw Exception('User not authenticated');
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = User.fromJson(userData);

      // Load additional profile data from database
      final profileData = await supabase.Supabase.instance.client
          .from('users')
          .select('*')
          .eq('id', _currentUser!.id)
          .single();

      // Store additional profile data
      _userBio = profileData['bio'] ?? '';

      // Load analytics data
      await _loadAnalyticsData();

      // Initialize form controllers
      _nameController.text = _currentUser!.fullName;
      _emailController.text = _currentUser!.email;
      _bioController.text = _userBio ?? '';

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final analytics =
          await _analyticsService.getStudentAnalytics(_currentUser!.id);
      setState(() {
        _analyticsData = analytics;
      });
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildProfileForm(),
              const SizedBox(height: 24),
              _buildChangePasswordSection(),
              const SizedBox(height: 24),
              // _buildAccountActions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Loading Profile...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUserProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: _currentUser!.avatarUrl != null
                    ? NetworkImage(_currentUser!.avatarUrl!) as ImageProvider
                    : null,
                child: _currentUser!.avatarUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    onPressed: _pickImage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser!.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser!.email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (_userBio != null && _userBio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _userBio!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentUser!.role.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Member since ${_formatDate(_currentUser!.createdAt)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.save, color: AppTheme.successGreen),
                  onPressed: _saveProfile,
                  tooltip: 'Save Changes',
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primaryBlue),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  tooltip: 'Edit Profile',
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Name Field
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email Field (Read-only)
          TextFormField(
            controller: _emailController,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 16),

          // Bio Field
          TextFormField(
            controller: _bioController,
            enabled: _isEditing,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio',
              prefixIcon: const Icon(Icons.info),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              hintText: 'Tell us about yourself...',
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        // Reset form values
                        _nameController.text = _currentUser!.fullName;
                        _bioController.text = _userBio ?? '';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Widget _buildAchievementsSection() {
  //   if (_analyticsData == null) {
  //     return const SizedBox.shrink();
  //   }
  //
  //   final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
  //   final totalCourses = userReport['total_courses_enrolled'] ?? 0;
  //   final totalLessons = userReport['total_lessons_accessed'] ?? 0;
  //   final averageScore = userReport['average_quiz_score'] ?? 0.0;
  //
  //   final achievements = <Map<String, dynamic>>[];
  //
  //   // Course enrollment achievements
  //   if (totalCourses >= 1) {
  //     achievements.add({
  //       'title': 'First Course',
  //       'description': 'Enrolled in your first course',
  //       'icon': Icons.school,
  //       'color': AppTheme.primaryBlue,
  //       'unlocked': true,
  //     });
  //   }
  //   if (totalCourses >= 5) {
  //     achievements.add({
  //       'title': 'Course Explorer',
  //       'description': 'Enrolled in 5 courses',
  //       'icon': Icons.explore,
  //       'color': AppTheme.successGreen,
  //       'unlocked': true,
  //     });
  //   }
  //
  //   // Lesson completion achievements
  //   if (totalLessons >= 10) {
  //     achievements.add({
  //       'title': 'Dedicated Learner',
  //       'description': 'Completed 10 lessons',
  //       'icon': Icons.book,
  //       'color': AppTheme.warningOrange,
  //       'unlocked': true,
  //     });
  //   }
  //
  //   // Quiz performance achievements
  //   if (averageScore >= 80) {
  //     achievements.add({
  //       'title': 'Quiz Master',
  //       'description': 'Maintained 80%+ average score',
  //       'icon': Icons.quiz,
  //       'color': AppTheme.errorRed,
  //       'unlocked': true,
  //     });
  //   }
  //
  //   if (achievements.isEmpty) {
  //     return const SizedBox.shrink();
  //   }
  //
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.1),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Achievements',
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: AppTheme.primaryBlue,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         // GridView.builder(
  //         //   shrinkWrap: true,
  //         //   physics: const NeverScrollableScrollPhysics(),
  //         //   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //         //     crossAxisCount: 2,
  //         //     crossAxisSpacing: 12,
  //         //     mainAxisSpacing: 12,
  //         //     childAspectRatio: 1.1,
  //         //   ),
  //         //   itemCount: achievements.length,
  //         //   itemBuilder: (context, index) {
  //         //     final achievement = achievements[index];
  //         //     return _buildAchievementCard(achievement);
  //         //   },
  //         // ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildAchievementCard(Map<String, dynamic> achievement) {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: achievement['unlocked']
  //           ? achievement['color'].withOpacity(0.1)
  //           : Colors.grey[100],
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: achievement['unlocked']
  //             ? achievement['color'].withOpacity(0.3)
  //             : Colors.grey[300]!,
  //       ),
  //     ),
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(
  //           achievement['icon'],
  //           color: achievement['unlocked']
  //               ? achievement['color']
  //               : Colors.grey[400],
  //           size: 32,
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           achievement['title'],
  //           style: TextStyle(
  //             fontSize: 14,
  //             fontWeight: FontWeight.bold,
  //             color: achievement['unlocked']
  //                 ? achievement['color']
  //                 : Colors.grey[400],
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //         const SizedBox(height: 4),
  //         Text(
  //           achievement['description'],
  //           style: TextStyle(
  //             fontSize: 10,
  //             color: achievement['unlocked']
  //                 ? achievement['color'].withOpacity(0.8)
  //                 : Colors.grey[400],
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildChangePasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isChangingPassword ? Icons.close : Icons.lock,
                  color: _isChangingPassword
                      ? AppTheme.errorRed
                      : AppTheme.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _isChangingPassword = !_isChangingPassword;
                    if (!_isChangingPassword) {
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                    }
                  });
                },
                tooltip: _isChangingPassword ? 'Cancel' : 'Change Password',
              ),
            ],
          ),
          if (_isChangingPassword) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Change Password'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Widget _buildAccountActions() {
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.1),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Account Actions',
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: AppTheme.primaryBlue,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         ListTile(
  //           leading: const Icon(Icons.logout, color: AppTheme.errorRed),
  //           title: const Text('Logout'),
  //           subtitle: const Text('Sign out of your account'),
  //           onTap: _logout,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  // Helper methods
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _selectedImage = File(image.path);
        });
        await _uploadImageWithBytes(imageBytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _uploadImageWithBytes(Uint8List imageBytes) async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final fileName = '${_uuid.v4()}.jpg';
      final storage = supabase.Supabase.instance.client.storage;

      await storage.from('avatars').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const supabase.FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final imageUrl = storage.from('avatars').getPublicUrl(fileName);

      await supabase.Supabase.instance.client
          .from('users')
          .update({'avatar_url': imageUrl}).eq('id', _currentUser!.id);

      _currentUser = _currentUser!.copyWith(avatarUrl: imageUrl);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));

      setState(() {
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await supabase.Supabase.instance.client.from('users').update({
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', _currentUser!.id);

      _currentUser = _currentUser!.copyWith(
        fullName: _nameController.text.trim(),
      );

      _userBio = _bioController.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

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
          content: Text('Password changed successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing password: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.year}';
  }
}

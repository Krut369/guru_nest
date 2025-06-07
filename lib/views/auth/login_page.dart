import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../views/auth/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      // Navigate based on user role
      switch (user.role) {
        case UserRole.teacher:
          context.go('/teacher/dashboard');
          break;
        case UserRole.student:
          context.go('/student/dashboard');
          break;
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        // Remove the "Exception: " prefix if it exists
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: AppTheme.headerDecoration,
                child: const Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school,
                            size: 50,
                            color: AppTheme.backgroundWhite,
                          ),
                          SizedBox(height: AppTheme.smallSpacing),
                          Text(
                            'Welcome Back!',
                            style: AppTheme.headerStyle,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.defaultPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: AppTheme.inputDecoration,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: AppTheme.textGrey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: AppTheme.defaultSpacing),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppTheme.defaultSpacing),
                          Container(
                            decoration: AppTheme.inputDecoration,
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: AppTheme.textGrey),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppTheme.textGrey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.defaultSpacing),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppTheme.defaultPadding),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppTheme.backgroundWhite),
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: AppTheme.buttonTextStyle,
                                  ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: AppTheme.defaultSpacing),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Divider(color: AppTheme.borderGrey)),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppTheme.smallSpacing),
                                  child: Text(
                                    'Or continue with',
                                    style: AppTheme.subheaderStyle,
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: AppTheme.borderGrey)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.defaultSpacing),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Sign Up',
                                style: AppTheme.subheaderStyle,
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_add,
                                    color: AppTheme.primaryBlue),
                                tooltip: 'Sign Up',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialLoginButton(String label, IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 32,
          color: AppTheme.textGrey,
        ),
        onPressed: () {
          // Implement social login
        },
      ),
    );
  }
}

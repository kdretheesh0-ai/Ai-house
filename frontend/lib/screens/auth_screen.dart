import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/legal_texts.dart';
import 'user_details_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreedToLegal = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final endpoint = _isLogin ? '/auth/login' : '/auth/signup';
      final body = {
        'email': _emailController.text,
        'password': _passwordController.text,
        if (!_isLogin) 'name': _nameController.text,
      };

      final response = await ApiService.post(endpoint, body);

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => UserDetailsScreen(userData: response['user'])),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response?['error'] ?? 'Authentication failed'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Trigger the native Google Sign In popup
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize(
        serverClientId:
            '665187508900-rrg56qkkn3jqa6cjj0s8401qkk5b6vfo.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        // User canceled the sign in
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      // 3. Send the ID token to our backend
      final response = await ApiService.post('/auth/google/token', {
        'idToken': idToken,
        'email': googleUser.email,
        'name': googleUser.displayName,
      });

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => UserDetailsScreen(userData: response['user'])),
          );
        }
      } else {
        throw Exception(
            response?['error'] ?? 'Google Authentication failed on server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLegalBottomSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: _buildSimpleMarkdownText(content),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleMarkdownText(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              line.replaceFirst('# ', ''),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          );
        } else if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 20),
            child: Text(
              line.replaceFirst('## ', ''),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          );
        } else if (line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                Expanded(
                    child: Text(line.replaceFirst('* ', ''),
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87, height: 1.5))),
              ],
            ),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black87, height: 1.5),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(
            color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: const Color(0xFF2979FF), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF2979FF),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSocialBtn(String text, IconData icon, Color color,
      [Widget? image]) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            if (text == 'Google') {
              if (!_agreedToLegal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please agree to the Terms & Conditions and Privacy Policy to continue.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              _signInWithGoogle();
            }
          },
          child: Center(
            child: image ?? Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/viewer/Screenshot 2026-06-02 101208.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Gradient Overlays (reduced opacity for clearer background)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds),

          // Header / Logo Area
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logo
                  Image.asset(
                    'assets/images/logo.png',
                    height: 180,
                    fit: BoxFit.contain,
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                  const SizedBox(height: 8),

                  // Subtitle 2
                  Text(
                    '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                ],
              ),
            ).animate().shimmer(
                delay: 400.ms, duration: 1500.ms, color: Colors.white30),
          ),

          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 0,
                    bottom: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

                      const SizedBox(height: 4),

                      Text(
                        _isLogin ? 'Welcome back! Ready to build?' : 'Join us and start building!',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

                      const SizedBox(height: 24),

                      if (!_isLogin)
                        _buildTextField(
                          controller: _nameController,
                          hint: 'Full Name',
                          icon: Icons.person_outline,
                        ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1),

                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email Address',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF2979FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 12),

                      // Legal Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToLegal,
                              onChanged: (val) {
                                setState(() {
                                  _agreedToLegal = val ?? false;
                                });
                              },
                              activeColor: const Color(0xFF2979FF),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              side: const BorderSide(
                                  color: Colors.black38, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              children: [
                                const Text('I agree to the ',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 13)),
                                GestureDetector(
                                  onTap: () => _showLegalBottomSheet(
                                      'Terms & Conditions',
                                      LegalTexts.termsAndConditions),
                                  child: const Text('Terms & Conditions',
                                      style: TextStyle(
                                          color: Color(0xFF2979FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const Text(' and ',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 13)),
                                GestureDetector(
                                  onTap: () => _showLegalBottomSheet(
                                      'Privacy Policy',
                                      LegalTexts.privacyPolicy),
                                  child: const Text('Privacy Policy',
                                      style: TextStyle(
                                          color: Color(0xFF2979FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 480.ms),

                      const SizedBox(height: 16),

                      // Primary Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              (_isLoading || !_agreedToLegal) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _agreedToLegal
                                ? const Color(0xFF2979FF)
                                : const Color(0xFF2979FF)
                                    .withValues(alpha: 0.5),
                            disabledBackgroundColor:
                                const Color(0xFF2979FF).withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLogin ? 'Signing In...' : 'Signing Up...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLogin ? 'Sign In' : 'Sign Up',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 20),
                                  ],
                                ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .slideY(begin: 0.1)
                          .shimmer(
                              delay: 1.seconds,
                              duration: 1200.ms,
                              color: Colors.white24),

                      const SizedBox(height: 24),

                      // OR divider
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: Colors.grey[200], thickness: 1.5)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                                  color: Colors.grey[200], thickness: 1.5)),
                        ],
                      ).animate().fadeIn(delay: 550.ms),

                      const SizedBox(height: 20),

                      // Social Logins
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialBtn(
                            'Google',
                            Icons.g_mobiledata,
                            Colors.red,
                            Image.asset(
                              'assets/images/search.png',
                              height: 24,
                              width: 24,
                            )
                                .animate(
                                    onPlay: (controller) =>
                                        controller.repeat(reverse: true))
                                .scaleXY(
                                    end: 1.1,
                                    duration: 1.seconds,
                                    curve: Curves.easeInOut)
                                .shimmer(
                                    duration: 2.seconds,
                                    color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ).animate().fadeIn(delay: 600.ms),

                      const SizedBox(height: 16),

                      // Toggle Login/Signup
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _emailController.clear();
                              _passwordController.clear();
                              _nameController.clear();
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                              style: const TextStyle(color: Colors.black54, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: _isLogin ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(
                                    color: Color(0xFF2979FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 650.ms),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .slideY(begin: 1.0, duration: 600.ms, curve: Curves.easeOutQuart)
              .shimmer(duration: 1.seconds, color: Colors.white12),
        ],
      ),
    );
  }
}

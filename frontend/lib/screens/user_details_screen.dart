import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const UserDetailsScreen({super.key, this.userData});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.userData?['name'] ?? '');
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitDetails() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all details to proceed')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_address', _addressController.text.trim());

    if (widget.userData?['email'] != null) {
      await prefs.setString('user_email', widget.userData!['email']);
    }

    // Small delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => ShellScreen(userData: widget.userData)),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 243, 241, 241),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.blueAccent[200], size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 16 : 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_pin_rounded,
                          size: 80, color: Color(0xFF2979FF))
                      .animate()
                      .fadeIn()
                      .scale(),
                  const SizedBox(height: 24),
                  const Text(
                    'Complete Your Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
                  const SizedBox(height: 8),
                  const Text(
                    'We need a few more details to personalize your DreamHome experience and generate accurate reports.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
                  _buildTextField(
                    controller: _addressController,
                    hint: 'Full Address',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor:
                            const Color(0xFF2979FF).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Continue to App',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

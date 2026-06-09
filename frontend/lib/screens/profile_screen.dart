import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ProfileScreen({super.key, this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController1;
  late AnimationController _bgController2;
  late AnimationController _bgController3;
  late AnimationController _bgController4;

  String name = '';
  String email = '';
  String phone = '';
  String address = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _bgController1 =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat(reverse: true);
    _bgController2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 16))
          ..repeat(reverse: true);
    _bgController3 =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat(reverse: true);
    _bgController4 =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController1.dispose();
    _bgController2.dispose();
    _bgController3.dispose();
    _bgController4.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('user_name') ??
          widget.userData?['user_metadata']?['name'] ??
          'User';
      email = prefs.getString('user_email') ?? widget.userData?['email'] ?? '';
      phone = prefs.getString('user_phone') ??
          widget.userData?['user_metadata']?['phone'] ??
          '';
      address = prefs.getString('user_address') ?? 'No Address Provided';
    });
  }

  Widget _buildBall(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.0)],
          center: Alignment.center,
          radius: 0.8,
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Column(
      children: List.generate(
          5,
          (i) => Row(
                children: List.generate(
                    5,
                    (j) => Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )),
              )),
    );
  }

  Widget _buildListItem(
      IconData icon, String title, Widget trailingOrSubtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue[600], size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                trailingOrSubtitle,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    return Scaffold(
      backgroundColor: const Color(
          0xFFF4F7FF), // Light gradient-like background matching AuthScreen
      body: Stack(
        children: [
          // Background blobs for soft wave effect
          AnimatedBuilder(
            animation: _bgController1,
            builder: (context, child) {
              return Positioned(
                top: -100 + 50 * sin(_bgController1.value * 2 * pi),
                left: -80 + 50 * cos(_bgController1.value * 2 * pi),
                child: _buildBall(
                    300, const Color(0xFFD4DEFF)), // Top left light blue
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController2,
            builder: (context, child) {
              return Positioned(
                bottom: -150 + 60 * cos(_bgController2.value * 2 * pi),
                left: -100 + 60 * sin(_bgController2.value * 2 * pi),
                child: _buildBall(
                    400, const Color(0xFF8BA6FF)), // Bottom left strong blue
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController3,
            builder: (context, child) {
              return Positioned(
                bottom: 50 + 40 * sin(_bgController3.value * 2 * pi),
                right: -100 + 40 * cos(_bgController3.value * 2 * pi),
                child: _buildBall(
                    250, const Color(0xFFE2D9FF)), // Bottom right light purple
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController4,
            builder: (context, child) {
              return Positioned(
                top: 80 + 70 * sin(_bgController4.value * 2 * pi),
                right: -50 + 70 * cos(_bgController4.value * 2 * pi),
                child: _buildBall(
                    200, const Color(0xFFC7D3FF)), // Top right soft blue
              );
            },
          ),

          // Top left and bottom right dot patterns
          Positioned(top: 120, right: 24, child: _buildDots()),
          Positioned(bottom: 80, left: 24, child: _buildDots()),

          // Main Glassmorphism Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Profile Avatar
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.blue[300]!, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      blurRadius: 15,
                                      spreadRadius: 2)
                                ],
                                image: const DecorationImage(
                                  image: NetworkImage(
                                      'https://i.pravatar.cc/300?img=11'), // Placeholder for engineer
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ).animate().scale(
                                delay: 200.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutBack),

                            const SizedBox(height: 10),

                            // Name
                            Text(
                              name,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue[900]),
                            ),

                            const SizedBox(height: 6),

                            // Premium Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium,
                                      color: Colors.blue[600], size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Premium Member',
                                    style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // List Items
                            _buildListItem(
                              Icons.person_outline,
                              'Name',
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            )
                                .animate()
                                .fadeIn(delay: 300.ms)
                                .slideY(begin: 0.2, end: 0),

                            _buildListItem(
                              Icons.phone_outlined,
                              'Phone Number',
                              Text(phone,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            )
                                .animate()
                                .fadeIn(delay: 400.ms)
                                .slideY(begin: 0.2, end: 0),

                            _buildListItem(
                              Icons.email_outlined,
                              'Email Address',
                              Text(email,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            )
                                .animate()
                                .fadeIn(delay: 450.ms)
                                .slideY(begin: 0.2, end: 0),

                            _buildListItem(
                              Icons.home_work_outlined,
                              'Address',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(address,
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 500.ms)
                                .slideY(begin: 0.2, end: 0),

                            const SizedBox(height: 16),

                            // Logout Button
                            SizedBox(
                              width: 160,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[600]!
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                          builder: (_) => const AuthScreen()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 700.ms).scale(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top App Bar Area (MOVED TO BOTTOM OF STACK SO IT IS TAPPABLE)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: Colors.blue[900], size: 20),
                    ),
                  ),
                  Text(
                    '\nMy Profile',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 40), // Spacer for balance
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

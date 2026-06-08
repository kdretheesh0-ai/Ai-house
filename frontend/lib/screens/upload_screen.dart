import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/planx_report_popup.dart';
import 'secure_payment_screen.dart';

class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> project, Set<String> selectedIds)?
      onProjectLoaded;
  final Function(XFile ground, XFile? first, XFile? second, int floors,
      Set<String> selectedIds)? onStartGeneration;
  final bool isExternalLoading;

  const UploadScreen({
    super.key,
    this.onProjectLoaded,
    this.onStartGeneration,
    this.isExternalLoading = false,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  int _selectedFloors = 0;
  XFile? _groundFile;
  XFile? _firstFloorFile;
  XFile? _secondFloorFile;

  // Animation controller for the building effect
  AnimationController? _buildController;
  Animation<double>? _buildAnimation;

  AnimationController? _timelineController;
  Animation<double>? _timelineAnimation;

  // ─── Light Theme Colors ───────────────────────────────────────────────────
  static const _bg = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF0F172A);
  static const _textLight = Color(0xFF64748B);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _buildController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _buildAnimation = CurvedAnimation(
      parent: _buildController!,
      curve: Curves.easeInOutSine,
    );

    _timelineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _timelineAnimation =
        Tween<double>(begin: 0, end: 6).animate(_timelineController!);
  }

  @override
  void dispose() {
    _buildController?.dispose();
    _timelineController?.dispose();
    super.dispose();
  }

  Future<void> _pick(int floorIndex) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) {
      setState(() {
        if (floorIndex == 0) {
          _groundFile = f;
        } else if (floorIndex == 1) {
          _firstFloorFile = f;
        } else if (floorIndex == 2) {
          _secondFloorFile = f;
        }
      });

      // Automatically proceed when all required files are uploaded
      if (_canProceed) {
        _generate();
      }
    }
  }

  bool get _canProceed {
    if (_selectedFloors == 0) return _groundFile != null;
    if (_selectedFloors == 1) {
      return _groundFile != null && _firstFloorFile != null;
    }
    if (_selectedFloors == 2) {
      return _groundFile != null && _firstFloorFile != null && _secondFloorFile != null;
    }
    return false;
  }

  Future<void> _generate() async {
    if (!_canProceed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) => PlanXReportPopup(
        onContinue: (selectedIds) {
          final totalAmount = (selectedIds.contains('3d') ? 499.0 : 0.0) +
              (selectedIds.contains('vastu') ? 299.0 : 0.0) +
              (selectedIds.contains('cost') ? 199.0 : 0.0) +
              (selectedIds.contains('structural') ? 999.0 : 0.0) +
              (selectedIds.contains('elevation') ? 799.0 : 0.0);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SecurePaymentScreen(
                amount: totalAmount,
                selectedItems:
                    selectedIds.map((id) => id.toUpperCase()).toList(),
                onFinish: () {
                  widget.onStartGeneration?.call(
                    _groundFile!,
                    _firstFloorFile,
                    _secondFloorFile,
                    _selectedFloors,
                    selectedIds,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_buildAnimation == null || _timelineAnimation == null) {
      _initAnimation();
    }

    final h = MediaQuery.of(context).size.height;
    


    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ─── PANNING CONSTRUCTION ANIMATION ─────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.45,
            child: AnimatedBuilder(
              animation: _buildAnimation!,
              builder: (context, child) {
                final alignmentX = -1.0 + (_buildAnimation!.value * 2.0);
                return Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage(
                          'assets/viewer/3d-house-model-with-modern-architecture.jpg'),
                      fit: BoxFit.cover,
                      alignment: Alignment(alignmentX, 0.0),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── MAIN CONTENT ─────────────────────────────
          Positioned(
            top: h * 0.23, // Lifted up to show all content clearly
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                // Glowing Pill
                _buildGlowingPill(),

                // Connecting vertical line with moving effect
                Container(
                  width: 2,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 4,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.blueAccent,
                              blurRadius: 10,
                              spreadRadius: 2)
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat()).moveY(
                          begin: -15,
                          end: 35,
                          duration: 1.5.seconds,
                        ),
                  ),
                ),

                // White Glass Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, -5),
                        )
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Center vertical line overlay inside the white container
                        Positioned(
                          top: 0,
                          bottom: 140, // rough height to ground floor card
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blueAccent.withValues(alpha: 0.5),
                                    blurRadius: 5)
                              ],
                            ),
                          ),
                        ),

                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top connecting dot
                              Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.blueAccent,
                                            blurRadius: 8,
                                            spreadRadius: 2)
                                      ],
                                      border: Border.all(
                                          color: Colors.white, width: 2)),
                                ),
                              ),

                              const SizedBox(height: 12),
                              const _SectionTitle(title: 'SELECT FLOORS'),
                              const SizedBox(height: 12),

                              // ── FLOOR PLAN SELECTION (Custom Design) ─────────
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildFloorToggle(
                                          0,
                                          '0 Floor',
                                          'Ground Floor Plan',
                                          Icons.home_outlined)),
                                  // Glowing line segment
                                  Container(
                                          width: 12,
                                          height: 2,
                                          color: Colors.blueAccent
                                              .withValues(alpha: 0.5))
                                      .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true))
                                      .fade(
                                          begin: 0.3,
                                          end: 1.0,
                                          duration: 800.ms),
                                  // Home Icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.blueAccent
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 10,
                                              spreadRadius: 3),
                                          BoxShadow(
                                              color: Colors.blueAccent
                                                  .withValues(alpha: 0.2),
                                              spreadRadius: 6), // outer ring
                                        ]),
                                    child: const Icon(Icons.home_outlined,
                                        color:
                                            Color.fromARGB(255, 194, 226, 243),
                                        size: 20),
                                  )
                                      .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true))
                                      .scaleXY(end: 1.15, duration: 800.ms)
                                      .shimmer(
                                          duration: 1200.ms,
                                          color: const Color.fromARGB(
                                                  255, 176, 222, 251)
                                              .withValues(alpha: 0.8)),
                                  // Glowing line segment
                                  Container(
                                          width: 12,
                                          height: 2,
                                          color: Colors.blueAccent
                                              .withValues(alpha: 0.5))
                                      .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true))
                                      .fade(
                                          begin: 0.3,
                                          end: 1.0,
                                          duration: 800.ms),
                                  Expanded(
                                      child: _buildFloorToggle(1, '1 Floors',
                                          'G + 1 Floor Plan', Icons.domain)),
                                ],
                              ),

                              const SizedBox(height: 24),
                              const _SectionTitle(title: 'FLOOR PLANS'),
                              const SizedBox(height: 12),

                              // Upload Ground Floor
                              _buildUploadCard(
                                title: 'Ground Floor 2D Design',
                                isRequired: true,
                                file: _groundFile,
                                onTap: () => _pick(0),
                              ),

                              // Upload First Floor (if 1 floor selected)
                              if (_selectedFloors == 1) ...[
                                const SizedBox(height: 12),
                                _buildUploadCard(
                                  title: 'First Floor 2D Design',
                                  isRequired: true,
                                  file: _firstFloorFile,
                                  onTap: () => _pick(1),
                                ),
                              ],

                              const SizedBox(height: 24),
                              _featureRow(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.isExternalLoading) _loadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildFloorToggle(
      int value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedFloors == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFloors = value),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F62FE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  isSelected ? const Color(0xFF0F62FE) : Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF0F62FE).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : _textDark, size: 24),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected ? Colors.white70 : _textLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _featureRow() {
    final items = [
      (
        '3D View',
        '₹499',
        Icons.view_in_ar_rounded,
        const Color(0xFFEFF6FF),
        const Color(0xFF0F62FE)
      ),
      (
        'Vastu Analysis',
        '₹299',
        Icons.explore_outlined,
        const Color(0xFFECFDF5),
        Colors.green
      ),
      (
        'Estimation',
        '₹499',
        Icons.price_check_rounded,
        const Color(0xFFFEF2F2),
        const Color.fromARGB(255, 239, 205, 68)
      ),
      (
        'Structural Plan',
        '₹999',
        Icons.architecture_rounded,
        const Color(0xFFFAF5FF),
        Colors.purple
      ),
      (
        'Elevation',
        '₹799',
        Icons.apartment_rounded,
        const Color(0xFFFEF2F2),
        _red
      ),
    ];

    return SizedBox(
      height: 125,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = items[i];
          return Container(
            width: 110,
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: f.$4,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(f.$3, color: f.$5, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    f.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: f.$4,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f.$2,
                      style: TextStyle(
                        color: f.$5,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 8),
        child: Container(
          color: Colors.white.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/house.gif',
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.home_rounded,
                        size: 100, color: Color(0xFF2979FF));
                  },
                ),
                const SizedBox(height: 32),
                const Text(
                  'Loading your Plan...',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF475569),
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(
                          onPlay: (controller) => controller.repeat(),
                        )
                        .scaleXY(
                          begin: 0.5,
                          end: 1.5,
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                          delay: (index * 100).ms,
                        )
                        .then()
                        .scaleXY(
                          begin: 1.5,
                          end: 0.5,
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingPill() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.8), // Dark glass
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2)
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.domain, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('G + 1 Floors',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Row(children: const [
                  Text('Project Complete',
                      style:
                          TextStyle(color: Colors.greenAccent, fontSize: 10)),
                  SizedBox(width: 4),
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 12),
                ])
              ])
        ]));
  }

  Widget _buildUploadCard({
    required String title,
    required bool isRequired,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    final has = file != null;
    return Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedLightningBorder(
            isActive: !has,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: has
                          ? (kIsWeb
                              ? Image.network(file.path, fit: BoxFit.cover)
                              : Image.file(File(file.path), fit: BoxFit.cover))
                          : Image.asset(
                              'assets/images/image.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: has
                          ? Colors.green.withValues(alpha: 0.1)
                          : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      has ? Icons.check_circle : Icons.cloud_upload_outlined,
                      color: has ? Colors.green : const Color(0xFF0F62FE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (isRequired && !has) ...[
                              const Text(
                                'Required',
                                style: TextStyle(
                                  color: _red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                ' · ',
                                style: TextStyle(color: _textLight),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                has ? file.name : 'Upload 2D floor plan',
                                style: TextStyle(
                                  color: has ? Colors.green : _textLight,
                                  fontSize: 11,
                                  fontWeight:
                                      has ? FontWeight.w500 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildTag('JPG'),
                            _buildTag('PNG'),
                            _buildTag('PDF'),
                            const Text(
                              'upto 10MB',
                              style: TextStyle(
                                color: _textLight,
                                fontSize: 10,
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F62FE),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      elevation: 0,
                    ),
                    child: Icon(
                      has ? Icons.edit : Icons.arrow_forward,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
          // Connecting dot at the top edge of the card
          Positioned(
              top: -6,
              child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          blurRadius: 5)
                    ],
                  )))
        ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedLightningBorder extends StatefulWidget {
  final Widget child;
  final bool isActive;
  const AnimatedLightningBorder(
      {super.key, required this.child, this.isActive = true});
  @override
  State<AnimatedLightningBorder> createState() =>
      _AnimatedLightningBorderState();
}

class _AnimatedLightningBorderState extends State<AnimatedLightningBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedLightningBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: LightningBorderPainter(_controller.value),
          child: widget.child,
        );
      },
    );
  }
}

class LightningBorderPainter extends CustomPainter {
  final double animationValue;

  LightningBorderPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Inflate rect slightly so lightning plays on the outer edge
    final rect = (Offset.zero & size).inflate(2.0);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Shader to make the lightning rotate around the card
    final sweepGradient = SweepGradient(
      transform: GradientRotation(animationValue * math.pi * 2),
      colors: [
        const Color.fromARGB(255, 254, 251, 251),
        const Color.fromARGB(255, 234, 235, 236).withValues(alpha: 0.2),
        const Color.fromARGB(255, 207, 221, 221),
        const Color.fromARGB(255, 236, 240, 241),
        const Color.fromARGB(255, 255, 255, 255),
        const Color.fromARGB(255, 198, 225, 233).withValues(alpha: 0.2),
        const Color.fromARGB(255, 245, 243, 243),
      ],
      stops: const [0.0, 0.2, 0.4, 0.45, 0.5, 0.7, 1.0],
    );
    final shader = sweepGradient.createShader(rect);

    final paintGlow = Paint()
      ..shader = shader
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paintCore = Paint()
      ..shader = shader
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    final jaggedPath = Path();
    // Update lightning shape rapidly (15 times per second)
    final random = math.Random((animationValue * 15).toInt());

    const step = 6.0;
    for (double d = 0; d <= length; d += step) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent == null) continue;

      final position = tangent.position;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

      // Random displacement
      final noise = (random.nextDouble() - 0.5) * 8.0; // +/- 4 pixels
      final point = position + normal * noise;

      if (d == 0) {
        jaggedPath.moveTo(point.dx, point.dy);
      } else {
        jaggedPath.lineTo(point.dx, point.dy);
      }
    }
    jaggedPath.close();

    // Secondary branches
    final jaggedPath2 = Path();
    final random2 = math.Random((animationValue * 15).toInt() + 100);
    for (double d = 0; d <= length; d += step * 1.5) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent == null) continue;
      final position = tangent.position;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

      final branchNoise = random2.nextDouble() > 0.6
          ? (random2.nextDouble() - 0.5) * 20.0
          : 0.0;
      final point = position + normal * branchNoise;

      if (d == 0) {
        jaggedPath2.moveTo(point.dx, point.dy);
      } else {
        jaggedPath2.lineTo(point.dx, point.dy);
      }
    }
    jaggedPath2.close();

    canvas.drawPath(jaggedPath, paintGlow);
    canvas.drawPath(jaggedPath2, paintGlow);
    canvas.drawPath(jaggedPath, paintCore);

    final baseGlow = Paint()
      ..shader = shader
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect, baseGlow);
  }

  @override
  bool shouldRepaint(covariant LightningBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

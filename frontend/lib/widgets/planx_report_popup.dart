import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReportOption {
  final String id;
  final String title;
  final String description;
  final int price;
  final IconData icon;
  final Color iconColor;

  ReportOption({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    required this.iconColor,
  });
}

class PlanXReportPopup extends StatefulWidget {
  final void Function(Set<String> selectedIds) onContinue;
  const PlanXReportPopup({super.key, required this.onContinue});

  @override
  State<PlanXReportPopup> createState() => _PlanXReportPopupState();
}

class _PlanXReportPopupState extends State<PlanXReportPopup> {
  final List<ReportOption> _options = [
    ReportOption(
      id: '3d',
      title: '3D View Visualization',
      description: 'Realistic 3D model of your home',
      price: 499,
      icon: Icons.view_in_ar_rounded,
      iconColor: const Color(0xFF2979FF),
    ),
    ReportOption(
      id: 'vastu',
      title: 'Vastu Analysis',
      description: 'AI-powered vastu score & tips',
      price: 299,
      icon: Icons.explore_rounded,
      iconColor: Colors.orange,
    ),
    ReportOption(
      id: 'cost',
      title: 'Cost Estimation',
      description: 'Detailed construction cost estimation',
      price: 199,
      icon: Icons.calculate_rounded,
      iconColor: Colors.green,
    ),
    ReportOption(
      id: 'structural',
      title: 'Structural Design',
      description: 'Structural analysis & safety report',
      price: 999,
      icon: Icons.architecture_rounded,
      iconColor: Colors.deepPurple,
    ),
    ReportOption(
      id: 'elevation',
      title: 'Elevation Design',
      description: 'Modern elevation views',
      price: 799,
      icon: Icons.home_work_rounded,
      iconColor: Colors.redAccent,
    ),
  ];

  final Set<String> _selectedIds = {'3d', 'vastu'}; // Default selections

  int get _totalPrice => _options
      .where((opt) => _selectedIds.contains(opt.id))
      .fold(0, (sum, opt) => sum + opt.price);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopSection(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: _buildGrid(),
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        )
            .animate()
            .scale(
              duration: 400.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(0.8, 0.8),
            )
            .fadeIn(),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, left: 24, right: 24, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF4ADE80),
              size: 40,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          const Text(
            'Floor Plan Uploaded!',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the pages you want to generate.\nPay only for what you select.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final opt = _options[index];
        final isSelected = _selectedIds.contains(opt.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                if (_selectedIds.length > 1) _selectedIds.remove(opt.id);
              } else {
                _selectedIds.add(opt.id);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2979FF)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2979FF).withValues(alpha: 0.08),
                        blurRadius: 15,
                        spreadRadius: -2,
                      )
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: opt.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(opt.icon, color: opt.iconColor, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      opt.title,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.description,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '₹${opt.price}',
                      style: TextStyle(
                        color: opt.id == '3d' ? const Color(0xFF2979FF) : opt.iconColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2979FF)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: (index * 50).ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, -5),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2979FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2979FF), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedIds.length} Services Selected',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Total: ',
                                style: TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹$_totalPrice',
                                style: const TextStyle(
                                  color: Color(0xFF2979FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security, color: Colors.green, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Payment',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '100% Protected',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
               ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => widget.onContinue(_selectedIds),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

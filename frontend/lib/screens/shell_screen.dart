import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'upload_screen.dart';
import 'viewer_screen.dart';
import 'vastu_screen.dart';
import 'estimation_screen.dart';
import 'structural_screen.dart';
import 'elevation_screen.dart';
import 'download_screen.dart';
import 'profile_screen.dart';

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _navItems = [
  _NavItem(Icons.home_outlined, 'Home Map'),
  _NavItem(Icons.view_in_ar_rounded, '3D View'),
  _NavItem(Icons.self_improvement_outlined, 'Vastu Report'),
  _NavItem(Icons.calculate_outlined, 'Classic Estimation'),
  _NavItem(Icons.foundation_outlined, 'Structural Report'),
  _NavItem(Icons.architecture_outlined, 'Elevation'),
  _NavItem(Icons.download_outlined, 'Download Report'),
];

// ─── Color Palette (Professional Light Theme) ──────────────────────────────────
const _bgDark = Color.fromARGB(255, 245, 247, 250); // Clean light background
const _sidebar = Color.fromARGB(255, 255, 255, 255); // Pure white sidebar
const _accent = Color(0xFF2979FF); // Professional blue
const _accentDim = Color(0x152979FF);
const _textPri = Color(0xFF1E293B); // Dark slate for primary text
const _textSec = Color(0xFF64748B); // Slate gray for secondary text
const _divider = Color(0x15000000); // Subtle dark divider

class ShellScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ShellScreen({super.key, this.userData});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selectedIndex = 0;
  bool _isGenerating = false;
  Map<String, dynamic>? _projectData;
  Set<String> _selectedReportIds = {};
  final bool _hasShownLogin = false;

  void _onProjectLoaded(Map<String, dynamic> project, Set<String> selectedIds) {
    setState(() {
      _projectData = project;
      _selectedReportIds = selectedIds;
      // Navigate to the first selected report if available, else 3D View
      if (selectedIds.contains('3d')) {
        _selectedIndex = 1;
      } else if (selectedIds.isNotEmpty) {
        // Map first selected ID to index
        _selectedIndex = _getMappedIndex(selectedIds.first);
      } else {
        _selectedIndex = 1;
      }
    });
  }

  Future<void> _startAIGeneration(XFile groundFile, XFile? firstFile,
      XFile? secondFile, int floors, Set<String> selectedIds) async {
    setState(() => _isGenerating = true);
    debugPrint('SHELL: Starting AI Generation pipeline...');

    try {
      final apiService = ApiService();
      final res = await apiService.uploadPlan(
        groundFile,
        firstFile,
        secondFile,
        'Project ${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}',
      );

      debugPrint('SHELL: Upload successful, processing results...');

      if (mounted) {
        _onProjectLoaded(res['project'] as Map<String, dynamic>, selectedIds);
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      debugPrint('SHELL: Upload error: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Generation failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  int _getMappedIndex(String id) {
    switch (id) {
      case '3d':
        return 1;
      case 'vastu':
        return 2;
      case 'cost':
      case 'boq':
        return 3;
      case 'structural':
        return 4;
      case 'elevation':
        return 5;
      default:
        return 1;
    }
  }

  List<int> get _visibleIndices {
    List<int> indices = [0]; // Always show Home Map
    if (_selectedReportIds.contains('3d')) indices.add(1);
    if (_selectedReportIds.contains('vastu')) indices.add(2);
    if (_selectedReportIds.contains('cost') ||
        _selectedReportIds.contains('boq')) {
      indices.add(3);
    }
    if (_selectedReportIds.contains('structural')) indices.add(4);
    if (_selectedReportIds.contains('elevation')) indices.add(5);
    indices.add(6); // Always show Download Report
    return indices;
  }

  Widget _buildBody(int index) {
    switch (index) {
      case 0:
        return UploadScreen(
          onProjectLoaded: _onProjectLoaded,
          onStartGeneration: _startAIGeneration,
          isExternalLoading: _isGenerating,
        );
      case 1:
        return _projectData != null
            ? ViewerScreen(
                projectData: _projectData!,
                onNavigateToVastu: () => setState(() => _selectedIndex = 2),
              )
            : _EmptyState(
                icon: Icons.view_in_ar_rounded,
                title: '3D View',
                subtitle:
                    'Upload a floor plan on the Home Map screen\nto generate your 3D model.',
                accentColor: _accent,
              );
      case 2:
        return _projectData != null
            ? VastuScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.self_improvement_outlined,
                title: 'Vastu Report',
                subtitle:
                    'Generate a project first to view\nyour Vastu analysis.',
                accentColor: _accent,
              );
      case 3:
        return _projectData != null
            ? EstimationScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.calculate_outlined,
                title: 'Estimation',
                subtitle:
                    'Generate a project first to view\nyour cost estimate.',
                accentColor: _accent,
              );
      case 4:
        return _projectData != null
            ? StructuralScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.foundation_outlined,
                title: 'Structural Report',
                subtitle:
                    'Generate a project first to view\nthe structural analysis.',
                accentColor: _accent,
              );
      case 5:
        return _projectData != null
            ? ElevationScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.architecture_outlined,
                title: 'Elevation',
                subtitle:
                    'Generate a project first to view\nthe elevation design.',
                accentColor: _accent,
              );
      case 6:
        return _projectData != null
            ? DownloadScreen(
                projectData: _projectData!,
                selectedReportIds: _selectedReportIds,
                onNavigateTo3D: () => setState(() => _selectedIndex = 1),
                userData: widget.userData,
              )
            : _EmptyState(
                icon: Icons.download_outlined,
                title: 'Download Report',
                subtitle:
                    'Generate a project first to\ndownload your full report.',
                accentColor: _accent,
              );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    if (isWide) {
      return Scaffold(
        backgroundColor: _bgDark,
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: _selectedIndex,
              visibleIndices: _visibleIndices,
              onTap: (i) => setState(() => _selectedIndex = i),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _bgDark,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 30,
                        offset: const Offset(-10, 0),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: _buildBody(_selectedIndex),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: Drawer(
        backgroundColor: _sidebar,
        child: _Sidebar(
          selectedIndex: _selectedIndex,
          visibleIndices: _visibleIndices,
          onTap: (i) {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() => _selectedIndex = i);
            });
          },
        ),
      ),
      appBar: _MobileAppBar(
        selectedIndex: _selectedIndex,
        userData: widget.userData,
      ),
      body: _buildBody(_selectedIndex),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<int> visibleIndices;
  final ValueChanged<int> onTap;

  const _Sidebar({
    required this.selectedIndex,
    required this.visibleIndices,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: _sidebar,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 80,
                fit: BoxFit.contain,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 3.seconds, color: _accentDim),
            ],
          ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.2),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              itemCount: visibleIndices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final realIndex = visibleIndices[i];
                final item = _navItems[realIndex];
                final isActive = realIndex == selectedIndex;
                return _SidebarItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () => onTap(realIndex),
                  delay: i * 50,
                );
              },
            ),
          ),
          const Divider(color: _divider, thickness: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: _accent,
                child: Text(
                  'Ki',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kanavu illam v1.0',
                style: TextStyle(
                  color: _textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int delay;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? _accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          border: isActive
              ? Border.all(color: _accent.withValues(alpha: 0.2), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isActive ? _accent : _textSec),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? _accent : _textSec,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: -0.1, end: 0);
  }
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final Map<String, dynamic>? userData;

  const _MobileAppBar({
    required this.selectedIndex,
    this.userData,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _sidebar,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: _textPri)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2.seconds, color: _accentDim),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _navItems[selectedIndex].label.toUpperCase(),
                style: const TextStyle(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: _accent, size: 24),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.05, duration: 2.seconds),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfileScreen(userData: userData)),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                color: _textPri,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSec,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}

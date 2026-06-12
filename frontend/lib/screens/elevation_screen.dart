import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import 'js_stub.dart' if (dart.library.html) 'dart:js_interop';

// Conditional imports to prevent mobile build crashes
import 'web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

import 'web_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;

const _bg = Colors.white;
const _accent = Color(0xFF00C896);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF475569);

class ElevationScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const ElevationScreen({super.key, required this.projectData});

  @override
  State<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends State<ElevationScreen> {
  late final WebViewController _mobileController;
  final String _viewId =
      'elevation-iframe-${DateTime.now().millisecondsSinceEpoch}';
  web.HTMLIFrameElement? _webIFrame;
  bool _isReady = false;
  int _selectedDesignIndex = 0;

  // ─── Dynamic Design Gallery ────────────────────────────────────────────────
  List<Map<String, dynamic>> _designs = [];

  // ─── Backend base URL (strips "/api" suffix) ───────────────────────────────
  static String get _backendBase =>
      ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');

  /// Pollinations AI supports CORS natively, so we can bypass the backend proxy
  /// and avoid any backend network parsing errors.
  String _proxyUrl(String rawUrl) {
    if (rawUrl.startsWith('http')) {
      return '${ApiService.baseUrl}/proxy-image?url=${Uri.encodeComponent(rawUrl)}';
    }
    return rawUrl;
  }

  @override
  void initState() {
    super.initState();
    _prepareDesigns();
    if (kIsWeb) {
      _setupWeb();
    } else {
      _setupMobile();
    }
  }

  void _prepareDesigns() {
    final modelData =
        widget.projectData['model_data'] as Map<String, dynamic>? ?? {};
    final floors = modelData['floors'] as Map<String, dynamic>? ?? {};

    final ground = floors['ground'] as Map<String, dynamic>? ?? {};
    final project = (ground['project'] as Map<String, dynamic>?) ??
        (modelData['project'] as Map<String, dynamic>?) ??
        {};

    final pw = (project['width'] as num?)?.toDouble() ?? 30.0;
    final ph = (project['height'] as num?)?.toDouble() ?? 40.0;

    int floorCount = 1;
    if (floors.containsKey('first')) floorCount = 2;
    if (floors.containsKey('second')) floorCount = 3;

    String floorText = 'single-story (ground floor only) house';
    String floorConstraint =
        'STRICTLY SINGLE-STORY (Ground Floor Only) house. The roof must be a simple flat open terrace with a parapet wall. DO NOT add a first floor, second floor, or any upper rooms. ';
    if (floorCount == 2) {
      floorText = 'two-story (G+1) house';
      floorConstraint = 'A two-story (Ground + First floor) house. ';
    } else if (floorCount == 3) {
      floorText = 'three-story (G+2) house';
      floorConstraint = 'A three-story (G+2) house. ';
    }

    final baseDesc = "${pw.toInt()}x${ph.toInt()}ft $floorText house";
    final constraintDesc = floorConstraint;
    // Create a stable seed based on the project ID so the image doesn't change on page reload
    final String projectId = widget.projectData['id']?.toString() ?? 'default';
    final timestamp = projectId.hashCode.abs();
    // --- Spatial Awareness Logic ---
    final rooms = ground['rooms'] as List? ?? [];
    String spatialFeatures = '';

    // Assume the "front" is where y is maximum (bottom of the plan)
    double maxY = 0.0;
    for (var r in rooms) {
      double ry = (r['y'] as num?)?.toDouble() ?? 0.0;
      double rh = (r['height'] as num?)?.toDouble() ?? 0.0;
      if (ry + rh > maxY) maxY = ry + rh;
    }

    // Get front-facing rooms (within 12ft of front edge)
    final frontRooms = rooms.where((r) {
      double ry = (r['y'] as num?)?.toDouble() ?? 0.0;
      double rh = (r['height'] as num?)?.toDouble() ?? 0.0;
      return (ry + rh) >= maxY - 12.0;
    }).toList();

    for (var r in frontRooms) {
      final name = (r['name']?.toString() ?? '').toLowerCase();
      final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
      final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
      final centerX = rx + (rw / 2);

      String side = 'in the center';
      if (centerX < pw / 3) {
        side = 'on the left side';
      } else if (centerX > (pw * 2) / 3) side = 'on the right side';

      if (name.contains('portico') ||
          name.contains('parking') ||
          name.contains('car')) {
        spatialFeatures += 'Features an open car parking portico $side. ';
      } else if (name.contains('stair') || name.contains('step')) {
        spatialFeatures += 'Features an enclosed staircase tower $side. ';
      } else if (name.contains('kitchen')) {
        spatialFeatures += 'Features a prominent kitchen window $side. ';
      } else if (name.contains('toilet') ||
          name.contains('bath') ||
          name.contains('wc')) {
        spatialFeatures += 'Features a small ventilator window $side. ';
      } else if (name.contains('bedroom')) {
        spatialFeatures += 'Features a large bedroom window $side. ';
      }
    }

    if (spatialFeatures.isEmpty) {
      spatialFeatures =
          'Features a well-defined main entrance, modern windows, and an elegant portico. ';
    }

    final visualData =
        (widget.projectData['visual_data'] as Map<String, dynamic>?) ??
            (modelData['_visual'] as Map<String, dynamic>?) ??
            {};
    final variations =
        (visualData['elevations'] ?? visualData['variations']) as List? ?? [];

    if (variations.isNotEmpty) {
      final v = variations[0]; // ONLY ONE ELEVATION
      _designs = [
        {
          'title': 'AI Elevation',
          'openAIPrompt': v['prompt'] ?? 'Professional ${v['style']} elevation',
          'desc':
              'AI generated ${v['style']} structural visualization directly derived from 2D floor plan.',
          'badge': 'AI VISION',
          'isNetwork': true,
          'directUrl': v['image_url']
        }
      ];
    } else {
      String fallbackPrompt =
          'Professional front elevation of a Modern Indian $baseDesc. STRICT RULES: $constraintDesc $spatialFeatures Maintain exact portico and staircase location. STYLE REQUIREMENTS: Modern Contemporary Architecture, Flat Roof with Parapet Wall, Premium White + Light Grey Color Combination, Wooden Texture Accent Panels, Clean Geometric Design, Modern Entrance Canopy, Premium Main Door, Realistic Glass Windows, Exterior Wall Lighting, Architectural Groove Lines. RENDER SETTINGS: Ultra Realistic, Front Elevation View, Daylight, High Resolution, Architectural Visualization, Photorealistic, 4K Quality, Professional CAD-Based Elevation';
      _designs = [
        {
          'title': 'AI Dynamic Elevation',
          'openAIPrompt': fallbackPrompt,
          'desc':
              'Unique AI-generated elevation design strictly structurally derived from your floor plan.',
          'badge': 'AI DYNAMIC',
          'isNetwork': true,
          'directUrl':
              'https://image.pollinations.ai/prompt/${Uri.encodeComponent(fallbackPrompt)}?width=1024&height=1024&seed=$timestamp&nologo=true&model=flux'
        }
      ];
    }

    _selectedDesignIndex = 0;
  }

  void _setupWeb() {
    const url = 'assets/viewer/viewer.html?view=elevation&hideToolbar=true';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      _webIFrame = web.HTMLIFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..src = url;
      web.window.addEventListener(
        'message',
        (web.Event event) {
          final msg = event as web.MessageEvent;
          if (msg.data.toString() == 'viewer_ready') _sendData();
        }.toJS,
      );
      return _webIFrame!;
    });
    Future.microtask(() {
      if (mounted) setState(() => _isReady = true);
    });
  }

  void _sendData() {
    if (_webIFrame == null) return;
    final modelData = widget.projectData['model_data'];
    if (modelData == null) return;
    final data = json.encode({'type': 'render', 'data': modelData});
    _webIFrame!.contentWindow?.postMessage(data.toJS, '*'.toJS);
  }

  void _setupMobile() {
    _mobileController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _isReady = true);
            _injectMobile();
          },
        ),
      )
      ..loadFlutterAsset(
        'assets/viewer/viewer.html?view=elevation&hideToolbar=true',
      );
  }

  void _injectMobile() {
    final modelData = widget.projectData['model_data'];
    if (modelData == null) return;
    final jsonData = json.encode(modelData);
    _mobileController.runJavaScript('window.renderProject($jsonData);');
    Future.delayed(
      const Duration(milliseconds: 400),
      () => _mobileController.runJavaScript(
        "if(window.setView) setView('elevation');",
      ),
    );
  }

  Widget _buildNetworkImage(String url,
      {BoxFit fit = BoxFit.cover, Key? key, bool isThumbnail = false}) {
    return Image.network(
      url,
      key: key ?? ValueKey(url),
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: isThumbnail
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: _accent,
                    strokeWidth: 2,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: _accent,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Generating AI design...',
                      style: TextStyle(color: _textSec, fontSize: 12),
                    ),
                  ],
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Center(
        child: isThumbnail
            ? const Icon(Icons.broken_image_outlined, color: _textSec, size: 24)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: _textSec, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Image failed to load',
                    style: const TextStyle(color: _textSec, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_designs.isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final design = _designs[_selectedDesignIndex];
    final imageUrl = design['directUrl'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (imageUrl != null)
            _buildNetworkImage(_proxyUrl(imageUrl), fit: BoxFit.cover)
          else
            const Center(
              child: Text(
                'No Elevation Image Available',
                style: TextStyle(color: _textSec, fontSize: 16),
              ),
            ),

          // Dark Gradient Overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
              ),
            ),
          ),

          // Header
          Positioned(
            left: 20,
            top: 40,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _accent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          design['badge'] ?? 'AI VISION',
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        design['title'] ?? 'AI Elevation',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        design['desc'] ??
                            'Photorealistic 3D generated elevation.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 2,
                                offset: Offset(0, 1))
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons at Bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Trigger download or save
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Saving elevation image...')),
                      );
                    },
                    icon:
                        const Icon(Icons.download_rounded, color: Colors.white),
                    label: const Text('Save Design',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _NativeElevationPainter extends CustomPainter {
  final Map<String, dynamic> ground;
  final Map<String, dynamic> first;
  final double pw, ph;

  _NativeElevationPainter({
    required this.ground,
    required this.first,
    required this.pw,
    required this.ph,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double floorH = 10.0;

    final cosA = 0.866;
    final sinA = 0.5;

    double totalZ = first.isNotEmpty ? (floorH * 2 + 3.0) : (floorH + 3.0);

    double isoW = (pw + ph) * cosA;
    double isoH = (pw + ph) * sinA + totalZ;

    final drawW = size.width * 0.8;
    final drawH = size.height * 0.7;

    double sX = drawW / isoW;
    double sY = drawH / isoH;
    double scale = sX < sY ? sX : sY;

    // Perfectly center the isometric projection box
    double offsetX = size.width / 2 - (pw - ph) * cosA * scale / 2;
    double offsetY =
        size.height / 2 + (isoH * scale) / 2 - (pw + ph) * sinA * scale / 2;

    Offset iso(double x, double y, double z) {
      double sx = (x - y) * cosA * scale;
      double sy = (x + y) * sinA * scale - (z * scale);
      return Offset(offsetX + sx, offsetY + sy);
    }

    final wallPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    final wallBorder = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final slabPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    final compoundPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final windowBorder = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final doorPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    List<_Poly3D> polys = [];

    void addWall(double x1, double y1, double x2, double y2, double z1,
        double z2, Paint fill, Paint stroke,
        {bool isWindow = false}) {
      Path path = Path();
      path.moveTo(iso(x1, y1, z1).dx, iso(x1, y1, z1).dy);
      path.lineTo(iso(x2, y2, z1).dx, iso(x2, y2, z1).dy);
      path.lineTo(iso(x2, y2, z2).dx, iso(x2, y2, z2).dy);
      path.lineTo(iso(x1, y1, z2).dx, iso(x1, y1, z2).dy);
      path.close();
      double depth = (x1 + x2 + y1 + y2) / 4;
      polys.add(_Poly3D(depth, path, fill, stroke, isWindow ? 1 : 0));

      if (isWindow) {
        double mx = (x1 + x2) / 2;
        double my = (y1 + y2) / 2;
        double mz = (z1 + z2) / 2;
        Path cross = Path();
        cross.moveTo(iso(mx, my, z1).dx, iso(mx, my, z1).dy);
        cross.lineTo(iso(mx, my, z2).dx, iso(mx, my, z2).dy);
        cross.moveTo(iso(x1, y1, mz).dx, iso(x1, y1, mz).dy);
        cross.lineTo(iso(x2, y2, mz).dx, iso(x2, y2, mz).dy);
        polys.add(_Poly3D(depth + 0.1, cross,
            Paint()..color = Colors.transparent, stroke, 2));
      }
    }

    void addSlab(double x, double y, double w, double l, double z, Paint fill,
        Paint stroke) {
      Path path = Path();
      path.moveTo(iso(x, y, z).dx, iso(x, y, z).dy);
      path.lineTo(iso(x + w, y, z).dx, iso(x + w, y, z).dy);
      path.lineTo(iso(x + w, y + l, z).dx, iso(x + w, y + l, z).dy);
      path.lineTo(iso(x, y + l, z).dx, iso(x, y + l, z).dy);
      path.close();
      double depth = (x + x + w + y + y + l) / 4;
      polys.add(_Poly3D(depth, path, fill, stroke, 0));
    }

    // Compound Wall
    double cwH = 4.0;
    addWall(0, 0, pw, 0, 0, cwH, compoundPaint, wallBorder); // Back
    addWall(pw, 0, pw, ph, 0, cwH, compoundPaint, wallBorder); // Right
    addWall(0, 0, 0, ph, 0, cwH, compoundPaint, wallBorder); // Left
    // Front with Main Gate opening (assumed right side)
    addWall(
        0, ph, pw - 14, ph, 0, cwH, compoundPaint, wallBorder); // Front Left
    addWall(pw - 2, ph, pw, ph, 0, cwH, compoundPaint,
        wallBorder); // Front Right corner

    void addFloor(Map<String, dynamic> floor, double baseZ) {
      final rooms = floor['rooms'] as List? ?? [];
      for (var r in rooms) {
        double x = (r['x'] as num?)?.toDouble() ?? 0;
        double y = (r['y'] as num?)?.toDouble() ?? 0;
        double w = (r['width'] as num?)?.toDouble() ?? 0;
        double l = (r['height'] as num?)?.toDouble() ?? 0;
        String name = (r['name']?.toString() ?? '').toLowerCase();

        if (name.contains('portico') ||
            name.contains('parking') ||
            name.contains('car')) {
          addSlab(x, y, w, l, baseZ + floorH, slabPaint, wallBorder);
          // Pillars at outer corners
          addWall(x + w - 1.0, y + l - 1.0, x + w, y + l, baseZ, baseZ + floorH,
              wallPaint, wallBorder);
          addWall(x, y + l - 1.0, x + 1.0, y + l, baseZ, baseZ + floorH,
              wallPaint, wallBorder);
        } else if (name.contains('stair') || name.contains('step')) {
          // Stairs going UP from front (y+l) to back (y)
          int steps = 10;
          for (int i = 0; i < steps; i++) {
            double stepH = floorH / steps;
            double stepY = y + l - (l / steps) * (i + 1); // Front to back

            addSlab(x, stepY, w, l / steps, baseZ + stepH * (i + 1), slabPaint,
                wallBorder); // Tread
            addWall(x, stepY + l / steps, x + w, stepY + l / steps, baseZ,
                baseZ + stepH * (i + 1), slabPaint, wallBorder); // Riser
            addWall(x + w, stepY, x + w, stepY + l / steps, baseZ,
                baseZ + stepH * (i + 1), slabPaint, wallBorder); // Side
          }
        } else {
          addSlab(x, y, w, l, baseZ + floorH, slabPaint, wallBorder);
        }
      }

      final walls = floor['walls'] as List? ?? [];
      for (var w in walls) {
        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        if (w['start'] is List) {
          x1 = (w['start'][0] as num).toDouble();
          y1 = (w['start'][1] as num).toDouble();
          x2 = (w['end'][0] as num).toDouble();
          y2 = (w['end'][1] as num).toDouble();
        } else if (w['start_x'] != null) {
          x1 = (w['start_x'] as num).toDouble();
          y1 = (w['start_y'] as num).toDouble();
          x2 = (w['end_x'] as num).toDouble();
          y2 = (w['end_y'] as num).toDouble();
        }
        addWall(x1, y1, x2, y2, baseZ, baseZ + floorH, wallPaint, wallBorder);
      }

      final doors = floor['doors'] as List? ?? [];
      for (var d in doors) {
        double x = (d['x'] as num?)?.toDouble() ?? 0;
        double y = (d['y'] as num?)?.toDouble() ?? 0;
        double dw = (d['width'] as num?)?.toDouble() ?? 3.5;
        addWall(x, y, x + dw, y, baseZ, baseZ + 7.0, doorPaint, wallBorder);
      }

      final windows = floor['windows'] as List? ?? [];
      for (var w in windows) {
        double x = (w['x'] as num?)?.toDouble() ?? 0;
        double y = (w['y'] as num?)?.toDouble() ?? 0;
        double ww = (w['width'] as num?)?.toDouble() ?? 4.0;
        addWall(x, y, x + ww, y, baseZ + 3.0, baseZ + 7.0, windowPaint,
            windowBorder,
            isWindow: true);
      }
    }

    addFloor(ground, 0);
    if (first.isNotEmpty) {
      addFloor(first, floorH);
      final walls = first['walls'] as List? ?? [];
      for (var w in walls) {
        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        if (w['start'] is List) {
          x1 = (w['start'][0] as num).toDouble();
          y1 = (w['start'][1] as num).toDouble();
          x2 = (w['end'][0] as num).toDouble();
          y2 = (w['end'][1] as num).toDouble();
        } else if (w['start_x'] != null) {
          x1 = (w['start_x'] as num).toDouble();
          y1 = (w['start_y'] as num).toDouble();
          x2 = (w['end_x'] as num).toDouble();
          y2 = (w['end_y'] as num).toDouble();
        }
        addWall(x1, y1, x2, y2, floorH * 2, floorH * 2 + 3.0, wallPaint,
            wallBorder);
      }
    } else {
      final walls = ground['walls'] as List? ?? [];
      for (var w in walls) {
        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        if (w['start'] is List) {
          x1 = (w['start'][0] as num).toDouble();
          y1 = (w['start'][1] as num).toDouble();
          x2 = (w['end'][0] as num).toDouble();
          y2 = (w['end'][1] as num).toDouble();
        } else if (w['start_x'] != null) {
          x1 = (w['start_x'] as num).toDouble();
          y1 = (w['start_y'] as num).toDouble();
          x2 = (w['end_x'] as num).toDouble();
          y2 = (w['end_y'] as num).toDouble();
        }
        addWall(x1, y1, x2, y2, floorH, floorH + 3.0, wallPaint, wallBorder);
      }
    }

    polys.sort((a, b) {
      if (a.depth == b.depth) return a.type.compareTo(b.type);
      return a.depth.compareTo(b.depth);
    });

    Path gPath = Path();
    gPath.moveTo(iso(0, 0, 0).dx, iso(0, 0, 0).dy);
    gPath.lineTo(iso(pw, 0, 0).dx, iso(pw, 0, 0).dy);
    gPath.lineTo(iso(pw, ph, 0).dx, iso(pw, ph, 0).dy);
    gPath.lineTo(iso(0, ph, 0).dx, iso(0, ph, 0).dy);
    gPath.close();

    canvas.drawPath(
        gPath,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..style = PaintingStyle.fill);
    canvas.drawPath(gPath, wallBorder);

    for (var p in polys) {
      canvas.drawPath(p.path, p.fill);
      canvas.drawPath(p.path, p.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Poly3D {
  final double depth;
  final Path path;
  final Paint fill;
  final Paint stroke;
  final int type;

  _Poly3D(this.depth, this.path, this.fill, this.stroke, this.type);
}

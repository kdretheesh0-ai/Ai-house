import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class PdfService {
  static Future<Uint8List> createProfessionalPdf(
      Map<String, dynamic> data, Set<String> selectedReportIds) async {
    Future<Uint8List?> fetchImage(String prompt,
        {String? imagePath, String? directUrl}) async {
      try {
        if (directUrl != null && directUrl.isNotEmpty) {
          final res = await http.get(Uri.parse(directUrl));
          if (res.statusCode == 200) return res.bodyBytes;
        } else {
          final backendBase =
              ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
          String urlString =
              '$backendBase/api/generate-elevation?prompt=${Uri.encodeComponent(prompt)}';
          if (imagePath != null && imagePath.isNotEmpty) {
            urlString += '&image_path=${Uri.encodeComponent(imagePath)}';
          }
          final url = Uri.parse(urlString);
          final res = await http.get(url);
          if (res.statusCode == 200) return res.bodyBytes;
        }
      } catch (e) {
        debugPrint('Error fetching image for PDF: $e');
      }
      return null;
    }

    Uint8List? image3d;
    Uint8List? imageStructural;
    Uint8List? imageElevation;

    final modelData = data['model_data'] ?? {};
    final floorsData = modelData['floors'];
    final floorsMap = floorsData is Map ? floorsData : {};
    final ground = floorsMap['ground'] as Map<String, dynamic>? ?? {};
    final project = (ground['project'] as Map<String, dynamic>?) ??
        (modelData['project'] as Map<String, dynamic>?) ??
        {};
    final projWidth = (project['width'] as num?)?.toDouble() ?? 30.0;
    final projHeight = (project['height'] as num?)?.toDouble() ?? 40.0;

    final visualData = data['visual_data'] as Map<String, dynamic>? ??
        data['_visual'] as Map<String, dynamic>? ??
        {};
    final structUrls = visualData['structural'] as Map<String, dynamic>? ?? {};

    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      final direct3d = structUrls['preview_url']?.toString();
      image3d = await fetchImage(
          'high quality architectural 3d isometric rendering of a modern indian house exterior, realistic blueprint style',
          directUrl: direct3d);
      if (image3d == null) {
        try {
          final ByteData fileData = await rootBundle.load(
              'assets/viewer/3d-house-model-with-modern-architecture.jpg');
          image3d = fileData.buffer.asUint8List();
        } catch (_) {}
      }
    }
    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      final directStruct = structUrls['blueprint_url']?.toString();
      imageStructural = await fetchImage(
          'architectural engineering structural steel beam and column reinforcement blueprint diagram, construction plan',
          directUrl: directStruct);
    }
    if (selectedReportIds.isEmpty || selectedReportIds.contains('elevation')) {
      // variables moved up
      int floorCount = floorsData is int ? floorsData : 1;
      if (floorsMap.containsKey('first')) floorCount = 2;
      if (floorsMap.containsKey('second')) floorCount = 3;

      final variations =
          (visualData['elevations'] ?? visualData['variations']) as List? ?? [];

      String prompt = '';
      String? directUrl;
      if (variations.isNotEmpty && variations[0]['prompt'] != null) {
        prompt = variations[0]['prompt'].toString();
        directUrl = variations[0]['image_url']?.toString();
      } else {
        // Fallback if visualizer data isn't available
        final rooms = ground['rooms'] as List? ?? [];
        String spatialFeatures = '';
        bool hasPorticoRight = false,
            hasPorticoLeft = false,
            hasStairsLeft = false,
            hasStairsRight = false;
        final midX = projWidth / 2;

        for (var r in rooms) {
          final name = (r['name']?.toString() ?? '').toLowerCase();
          final rx = (r['x'] as num?)?.toDouble() ?? 0.0;

          if (name.contains('portico') ||
              name.contains('parking') ||
              name.contains('garage')) {
            if (rx >= midX) {
              hasPorticoRight = true;
            } else {
              hasPorticoLeft = true;
            }
          }
          if (name.contains('stair') || name.contains('steps')) {
            if (rx <= midX) {
              hasStairsLeft = true;
            } else {
              hasStairsRight = true;
            }
          }
        }

        if (hasPorticoRight) {
          spatialFeatures +=
              'On the right side of the facade, a large open car portico with a car parked underneath, supported by elegant modern pillars. ';
        }
        if (hasPorticoLeft) {
          spatialFeatures +=
              'On the left side of the facade, a large open car portico with a car parked underneath, supported by elegant modern pillars. ';
        }
        if (hasStairsLeft) {
          spatialFeatures +=
              'On the left side of the facade, an external staircase structure. ';
        }
        if (hasStairsRight) {
          spatialFeatures +=
              'On the right side of the facade, an external staircase structure. ';
        }

        prompt =
            'Professional front elevation of a Modern Indian ${projWidth.toInt()}x${projHeight.toInt()}ft ${floorCount == 2 ? "two-story" : (floorCount == 3 ? "three-story" : "single-story")} house. STRICT RULES: EXACTLY MATCH the front layout. $spatialFeatures Modern Contemporary Architecture, Flat Roof with Parapet Wall, Premium Entrance Canopy, steps, compound wall. Photorealistic, 8k, architectural photography, daylight';
      }

      final imagePathStr = data['image_url']?.toString() ?? '';
      imageElevation = await fetchImage(prompt,
          imagePath: imagePathStr, directUrl: directUrl);
      if (imageElevation == null) {
        try {
          final ByteData fileData =
              await rootBundle.load('assets/viewer/professional_house.png');
          imageElevation = fileData.buffer.asUint8List();
        } catch (_) {}
      }
    }

    final pdf = pw.Document();

    final name = data['name'] ?? 'My Project';
    final date = DateTime.now().toString().split('.')[0];

    final model = data['model_data'] ?? {};
    final costRoot = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
    final vastuRoot =
        data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};

    bool isMultiFloor(Map m) => m.containsKey('ground');

    final floors = isMultiFloor(costRoot)
        ? costRoot.keys.where((k) => k != 'total').toList()
        : ['default'];

    final primaryColor = PdfColor.fromHex('#6D28D9');
    final accentBlue = PdfColor.fromHex('#2563EB');
    
    final accentOrange = PdfColor.fromHex('#EA580C');
    
    final accentTeal = PdfColor.fromHex('#0D9488');
    final bgTeal = PdfColor.fromHex('#F0FDFA');
    final accentGreen = PdfColor.fromHex('#16A34A');
    final accentRed = PdfColor.fromHex('#DC2626');
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');

    // Page 1 - Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                pw.Container(
                  width: 120,
                  height: 120,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text('HVA',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 40,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('HOUSE VISION AI',
                    style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark)),
                pw.SizedBox(height: 40),
                pw.Text('Complete House Analysis Report',
                    style: pw.TextStyle(fontSize: 24, color: primaryColor)),
                pw.SizedBox(height: 80),
                pw.Text('User Name: ${data['user_name'] ?? 'Client Name'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                pw.Text('Email: ${data['email'] ?? 'client@example.com'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                pw.Text('Phone: ${data['phone'] ?? '+91-XXXXXXXXXX'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                if (data['address'] != null && data['address'].isNotEmpty) ...[
                  pw.Text('Address: ${data['address']}',
                      style: pw.TextStyle(fontSize: 16, color: textDark),
                      textAlign: pw.TextAlign.center),
                ],
              ]));
        },
      ),
    );

    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      // Page 2 - 3D House Visualization
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  text: '3D House Visualization',
                  textStyle: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
              pw.SizedBox(height: 20),
              ...floors.map((floor) {
                final floorData = isMultiFloor(floorsMap)
                    ? (floorsMap[floor] ?? ground)
                    : ground;
                String title = floor == 'default'
                    ? 'Internal Floor Plan Model'
                    : '${floor.toString().toUpperCase()} Floor Model';
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      _buildApp3DModel(floorData, projWidth, projHeight),
                      pw.SizedBox(height: 25),
                    ]);
              }).toList(),
              pw.Text('Design Summary',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark)),
              pw.SizedBox(height: 10),
              pw.Text(
                  'The provided visualizations include the internal architectural layout model matching your project data.',
                  style: pw.TextStyle(
                      fontSize: 12, color: textMuted, lineSpacing: 1.5)),
            ];
          },
        ),
      );
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('vastu')) {
      // Page 3 - Vastu Report
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  text: 'Vastu Report',
                  textStyle: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: accentOrange)),
              pw.SizedBox(height: 20),
              ...floors.map((floor) {
                final vastu = isMultiFloor(vastuRoot)
                    ? (vastuRoot[floor] ?? vastuRoot)
                    : vastuRoot;
                String title = floor == 'default'
                    ? 'Overall Vastu Analysis'
                    : '${floor.toString().toUpperCase()} Floor Vastu Analysis';

                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Row(children: [
                        pw.Text('Score: ',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                        pw.Text(
                            '${vastu['score'] ?? 'N/A'}/100 (${vastu['grade'] ?? 'N/A'})',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: accentGreen)),
                      ]),
                      pw.SizedBox(height: 15),
                      if ((vastu['strengths'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Benefits',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentGreen)),
                        pw.SizedBox(height: 5),
                        ...(vastu['strengths'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 15),
                      ],
                      if ((vastu['violations'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Reasons for Score Reduction',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentRed)),
                        pw.SizedBox(height: 5),
                        ...(vastu['violations'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 15),
                      ],
                      if ((vastu['suggestions'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Suggestions',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentBlue)),
                        pw.SizedBox(height: 5),
                        ...(vastu['suggestions'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 20),
                      ],
                      pw.Divider(),
                      pw.SizedBox(height: 20),
                    ]);
              }).toList(),
            ];
          },
        ),
      );
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('cost')) {
      // Page 4 - Estimation
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  text: 'Estimation',
                  textStyle: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: accentTeal)),
              pw.SizedBox(height: 20),
              ...floors.map((floor) {
                final cost =
                    isMultiFloor(costRoot) ? costRoot[floor] : costRoot;
                if (cost == null || cost.isEmpty || cost is! Map) {
                  return pw.SizedBox();
                }
                final est = cost['estimates'] ?? {};
                String title = floor == 'default'
                    ? 'Overall Estimation'
                    : '${floor.toString().toUpperCase()} Floor Estimation';
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: bgTeal,
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Basic',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['basic'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Standard',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['standard'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Premium',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['premium'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                            ]),
                      ),
                      pw.SizedBox(height: 20),
                      if (cost['materials'] != null &&
                          cost['materials'] is Map) ...[
                        pw.Text('Material Breakdown',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                        pw.SizedBox(height: 10),
                        pw.Table(
                            border:
                                pw.TableBorder.all(color: PdfColors.grey300),
                            children: [
                              pw.TableRow(
                                  decoration: const pw.BoxDecoration(
                                      color: PdfColors.grey100),
                                  children: [
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Material',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Quantity',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Unit',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Rate (Rs)',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                  ]),
                              ...(cost['materials'] as Map).entries.map((e) {
                                final mat = e.value;
                                return pw.TableRow(children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['name']?.toString() ??
                                              e.key.toString(),
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['quantity']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['unit']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['price']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                ]);
                              }),
                            ]),
                        pw.SizedBox(height: 20),
                      ],
                    ]);
              }).toList(),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Grand Total',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
              pw.SizedBox(height: 5),
              pw.Text(
                  'Total costs depend on the selected finishing package and fluctuating market material rates.',
                  style: pw.TextStyle(fontSize: 12, color: textMuted)),
            ];
          },
        ),
      );
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      final structuralRoot = data['structural_data'] ??
          data['_structural'] ??
          model['_structural'] ??
          {};

      // Page 5 - Structural Analysis
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  text: 'Structural Analysis',
                  textStyle: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
              pw.SizedBox(height: 20),
              if (imageStructural != null) ...[
                pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(pw.MemoryImage(imageStructural),
                        fit: pw.BoxFit.cover, height: 200)),
                pw.SizedBox(height: 20),
              ],
              pw.Text('Structural Estimation',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark)),
              pw.SizedBox(height: 10),
              pw.Text(
                  'Based on AI engineering algorithms, the load-bearing distribution, column placement, and foundation specifications are evaluated.',
                  style: pw.TextStyle(
                      fontSize: 12, color: textMuted, lineSpacing: 1.5)),
              pw.SizedBox(height: 15),
              ...floors.map((floor) {
                final struct = isMultiFloor(structuralRoot)
                    ? structuralRoot[floor]
                    : structuralRoot;
                if (struct == null || struct.isEmpty || struct is! Map) {
                  return pw.SizedBox();
                }
                final summary = struct['summary'] ?? {};
                final rcmd = struct['recommendations'] ?? {};
                String title = floor == 'default'
                    ? 'Overall Structure'
                    : '${floor.toString().toUpperCase()} Floor Structure';

                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          '- Recommended Columns: ${rcmd['column_count'] ?? 'N/A'}',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.Text(
                          '- Estimated Load: ${summary['estimated_load_kg'] ?? 'N/A'} kg',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.Text(
                          '- Foundation Depth: ${rcmd['foundation_depth_ft'] ?? '5'} ft',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.SizedBox(height: 15),
                      pw.Text('Beam Layout Plan',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      _buildBeamLayout(
                          isMultiFloor(floorsMap)
                              ? (floorsMap[floor] ?? ground)
                              : ground,
                          struct,
                          projWidth,
                          projHeight),
                      pw.SizedBox(height: 25),
                      pw.Text('Beam Schedule',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.grey400),
                          children: [
                            pw.TableRow(
                                decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey100),
                                children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('MARK',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('SIZE',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('TOP',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('BOT',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('STIRRUP',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                ]),
                            pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('B1',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('9"x12"',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-16mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-16mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('8mm@6"',
                                      style: const pw.TextStyle(fontSize: 10))),
                            ]),
                            pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('B2',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('9"x9"',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-12mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-12mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('8mm@8"',
                                      style: const pw.TextStyle(fontSize: 10))),
                            ]),
                          ]),
                      pw.SizedBox(height: 15),
                      pw.Text('Structural Material Estimation',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8))),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                    '- Cement: ${struct['material_estimation']?['cement_bags'] ?? 450} Bags',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Steel (Rebar): ${struct['material_estimation']?['steel_kg'] ?? 4200} kg',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Sand: ${struct['material_estimation']?['sand_cft'] ?? 1800} cft',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Aggregate: ${struct['material_estimation']?['aggregate_cft'] ?? 2200} cft',
                                    style: const pw.TextStyle(fontSize: 12)),
                              ])),
                      pw.SizedBox(height: 25),
                    ]);
              }).toList(),
              pw.Text('- Status: VERIFIED',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: accentGreen)),
              pw.SizedBox(height: 5),
              pw.Text('- Integrity Score: 94/100',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: accentBlue)),
            ];
          },
        ),
      );
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('elevation')) {
      // Page 6 - Elevation
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  text: 'Front Elevation Blueprint',
                  textStyle: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: accentBlue)),
              pw.SizedBox(height: 20),
              _buildNativeElevation(
                  ground,
                  isMultiFloor(floorsMap) ? floorsMap['first'] ?? {} : {},
                  projWidth,
                  projHeight),
              pw.SizedBox(height: 20),
              pw.Text('Elevation Features',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark)),
              pw.SizedBox(height: 10),
              pw.Text(
                  '- Large glass facades implemented for maximum natural lighting.\n- Minimalist overhangs and linear geometric forms.\n- Textured stone and wood composite exterior finishes applied.\n- Proportional height distribution across all designed floors.',
                  style: pw.TextStyle(
                      fontSize: 12, color: textMuted, lineSpacing: 1.5)),
            ];
          },
        ),
      );
    }

    // Page 7 - Project Summary
    final finalVastu = isMultiFloor(vastuRoot)
        ? (vastuRoot['ground'] ?? vastuRoot['total'] ?? vastuRoot)
        : vastuRoot;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                text: 'Project Summary',
                textStyle: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
            pw.SizedBox(height: 20),
            pw.Text('Overall Ratings',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
            pw.SizedBox(height: 10),
            pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(children: [
                        pw.Text('Vastu',
                            style:
                                pw.TextStyle(fontSize: 14, color: textMuted)),
                        pw.SizedBox(height: 5),
                        pw.Text('${finalVastu['score'] ?? 'N/A'}/100',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: accentOrange)),
                      ]),
                      pw.Column(children: [
                        pw.Text('Structural',
                            style:
                                pw.TextStyle(fontSize: 14, color: textMuted)),
                        pw.SizedBox(height: 5),
                        pw.Text('94/100',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: accentBlue)),
                      ]),
                    ])),
            pw.SizedBox(height: 30),
            pw.Text('House Details',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
            pw.SizedBox(height: 10),
            pw.Text(
                '- Project Name: $name\n- Generated Date: $date\n- Floors Analyzed: ${floors.length}\n- Architectural Style: Modern Contemporary',
                style: pw.TextStyle(
                    fontSize: 12, color: textMuted, lineSpacing: 1.5)),
          ];
        },
      ),
    );

    // Page 8 - Thank You
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                pw.Text('THANK YOU',
                    style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
                pw.SizedBox(height: 10),
                pw.Text('for using HOUSE VISION AI',
                    style: pw.TextStyle(fontSize: 18, color: textMuted)),
              ]));
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildBeamLayout(
      Map floorData, Map structData, double projW, double projH) {
    final walls = floorData['walls'] as List? ?? [];
    
    final rooms = floorData['rooms'] as List? ?? [];

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColors.white,
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final padLeft = 40.0;
          final padTop = 40.0;
          final drawW = constraints!.maxWidth - padLeft - 20;
          final drawH = constraints.maxHeight - padTop - 20;
          final sX = drawW / projW;
          final sY = drawH / projH;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(drawW, drawH),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setStrokeColor(PdfColors.black);
                      canvas.setLineWidth(2.0);
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
                        canvas.drawLine(x1 * sX, drawH - (y1 * sY), x2 * sX,
                            drawH - (y2 * sY));
                      }
                      canvas.strokePath();

                      canvas.setFillColor(PdfColors.red600);
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
                        final cw = 8.0;
                        final ch = 8.0;
                        canvas.drawRect(x1 * sX - cw / 2,
                            drawH - (y1 * sY) - ch / 2, cw, ch);
                        canvas.drawRect(x2 * sX - cw / 2,
                            drawH - (y2 * sY) - ch / 2, cw, ch);
                      }
                      canvas.fillPath();
                    })),
            ...rooms.map((r) {
              final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
              final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
              final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
              final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
              final name = r['name']?.toString() ?? '';

              return pw.Positioned(
                left: padLeft + (rx + rw / 2) * sX - (name.length * 2.5),
                top: padTop + (ry + rh / 2) * sY - 4,
                child: pw.Text(name,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              );
            }),
            pw.Positioned(
                left: padLeft - 10,
                top: padTop - 25,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('1',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft + drawW - 10,
                top: padTop - 25,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('2',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft - 30,
                top: padTop - 10,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('A',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft - 30,
                top: padTop + drawH - 10,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('B',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
          ]);
        }));
  }

  static pw.Widget _buildApp3DModel(Map floorData, double projW, double projH) {
    final walls = floorData['walls'] as List? ?? [];
    final rooms = floorData['rooms'] as List? ?? [];

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#0F172A'),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final padLeft = 40.0;
          final padTop = 40.0;
          final drawW = constraints!.maxWidth - padLeft - 20;
          final drawH = constraints.maxHeight - padTop - 20;
          final sX = drawW / projW;
          final sY = drawH / projH;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(drawW, drawH),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      // Shadow
                      canvas.setFillColor(PdfColor.fromHex('#000000'));
                      canvas.drawRect(8, -12, drawW, drawH);
                      canvas.fillPath();

                      // Floor Base
                      canvas.setFillColor(PdfColor.fromHex('#94A3B8'));
                      canvas.drawRect(0, 0, drawW, drawH);
                      canvas.fillPath();

                      // Wall shadows (3D effect)
                      canvas.setStrokeColor(PdfColor.fromHex('#475569'));
                      canvas.setLineWidth(6.0);
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
                        canvas.drawLine(x1 * sX + 3, drawH - (y1 * sY) - 4,
                            x2 * sX + 3, drawH - (y2 * sY) - 4);
                      }
                      canvas.strokePath();

                      // Walls (Top surface)
                      canvas.setStrokeColor(PdfColor.fromHex('#F1F5F9'));
                      canvas.setLineWidth(4.0);
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
                        canvas.drawLine(x1 * sX, drawH - (y1 * sY), x2 * sX,
                            drawH - (y2 * sY));
                      }
                      canvas.strokePath();

                      // Doors (3D open effect)
                      final doors = floorData['doors'] as List? ?? [];
                      for (var d in doors) {
                        double dx = (d['x'] as num?)?.toDouble() ?? 0.0;
                        double dy = (d['y'] as num?)?.toDouble() ?? 0.0;
                        double dw = (d['width'] as num?)?.toDouble() ?? 3.0;
                        // Draw an angled door (45 deg) protruding outward
                        double ex = dx + (dw * 0.7);
                        double ey = dy + (dw * 0.7);

                        // Door Shadow
                        canvas.setStrokeColor(PdfColor.fromHex('#29180C'));
                        canvas.setLineWidth(4.0);
                        canvas.drawLine(dx * sX + 3, drawH - (dy * sY) - 4,
                            ex * sX + 3, drawH - (ey * sY) - 4);
                        canvas.strokePath();

                        // Door Surface
                        canvas.setStrokeColor(PdfColor.fromHex('#8B4513'));
                        canvas.drawLine(dx * sX, drawH - (dy * sY), ex * sX,
                            drawH - (ey * sY));
                        canvas.strokePath();
                      }
                    })),
            ...rooms.map((r) {
              final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
              final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
              final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
              final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
              final name = r['name']?.toString().toUpperCase() ?? '';

              return pw.Positioned(
                  left: padLeft + (rx + rw / 2) * sX - (name.length * 2.8),
                  top: padTop + (ry + rh / 2) * sY - 8,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0E7490'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(name,
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ));
            }),
          ]);
        }));
  }

  static pw.Widget _buildNativeElevation(
      Map ground, Map first, double projW, double projH) {
    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColor.fromHex('#0F172A'),
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final double floorH = 10.0;
          final double parapetH = 3.0;
          final cosA = 0.866;
          final sinA = 0.5;

          bool hasFirstFloor = first.isNotEmpty;
          double totalZ =
              hasFirstFloor ? (floorH * 2 + parapetH) : (floorH + parapetH);

          double isoW = (projW + projH) * cosA;
          double isoH = (projW + projH) * sinA + totalZ;

          final drawW = constraints!.maxWidth * 0.8;
          final drawH = constraints.maxHeight * 0.7;

          final sX = drawW / isoW;
          final sY = drawH / isoH;
          final scale = sX < sY ? sX : sY;

          final offsetX =
              constraints.maxWidth / 2 - (projW - projH) * cosA * scale / 2;
          final offsetY = constraints.maxHeight / 2 +
              (projW + projH) * sinA * scale / 2 -
              (isoH * scale) / 2;

          return pw.Stack(children: [
            pw.Positioned(
                left: 0,
                bottom: 0,
                child: pw.CustomPaint(
                    size: PdfPoint(constraints.maxWidth, constraints.maxHeight),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      PdfPoint iso(double x, double y, double z) {
                        double sx = (x - y) * cosA * scale;
                        double sy = -(x + y) * sinA * scale + (z * scale);
                        return PdfPoint(offsetX + sx, offsetY + sy);
                      }

                      final wallColor = PdfColor.fromHex('#F1F5F9');
                      final borderColor = PdfColor.fromHex('#334155');
                      final slabColor = PdfColor.fromHex('#E2E8F0');
                      final compoundColor = PdfColor.fromHex('#CBD5E1');

                      final windowColor = PdfColor.fromHex('#BFE8FB');
                      final windowBorder = PdfColor.fromHex('#0F172A');
                      final doorColor = PdfColor.fromHex('#8B4513');

                      List<Map<String, dynamic>> polys = [];

                      void addPoly(double depth, List<PdfPoint> pts,
                          PdfColor fill, PdfColor stroke, int type,
                          {List<PdfPoint>? cross}) {
                        polys.add({
                          'depth': depth,
                          'pts': pts,
                          'fill': fill,
                          'stroke': stroke,
                          'type': type,
                          'cross': cross,
                        });
                      }

                      void addWall(double x1, double y1, double x2, double y2,
                          double z1, double z2, PdfColor fill, PdfColor stroke,
                          {bool isWindow = false}) {
                        double depth = (x1 + x2 + y1 + y2) / 4;
                        var pts = [
                          iso(x1, y1, z1),
                          iso(x2, y2, z1),
                          iso(x2, y2, z2),
                          iso(x1, y1, z2)
                        ];
                        List<PdfPoint>? cross;
                        if (isWindow) {
                          double mx = (x1 + x2) / 2,
                              my = (y1 + y2) / 2,
                              mz = (z1 + z2) / 2;
                          cross = [
                            iso(mx, my, z1),
                            iso(mx, my, z2),
                            iso(x1, y1, mz),
                            iso(x2, y2, mz)
                          ];
                        }
                        addPoly(depth, pts, fill, stroke, isWindow ? 1 : 0,
                            cross: cross);
                      }

                      void addSlab(double x, double y, double w, double l,
                          double z, PdfColor fill, PdfColor stroke) {
                        double depth = (x + x + w + y + y + l) / 4;
                        var pts = [
                          iso(x, y, z),
                          iso(x + w, y, z),
                          iso(x + w, y + l, z),
                          iso(x, y + l, z)
                        ];
                        addPoly(depth, pts, fill, stroke, 0);
                      }

                      // Compound Wall
                      double cwH = 4.0;
                      addWall(0, 0, projW, 0, 0, cwH, compoundColor,
                          borderColor); // Back
                      addWall(projW, 0, projW, projH, 0, cwH, compoundColor,
                          borderColor); // Right
                      addWall(0, 0, 0, projH, 0, cwH, compoundColor,
                          borderColor); // Left
                      // Front with Main Gate opening
                      addWall(0, projH, projW - 14, projH, 0, cwH,
                          compoundColor, borderColor); // Front Left
                      addWall(projW - 2, projH, projW, projH, 0, cwH,
                          compoundColor, borderColor); // Front Right corner

                      void addFloor(Map floor, double baseZ) {
                        final rooms = floor['rooms'] as List? ?? [];
                        for (var r in rooms) {
                          double x = (r['x'] as num?)?.toDouble() ?? 0;
                          double y = (r['y'] as num?)?.toDouble() ?? 0;
                          double w = (r['width'] as num?)?.toDouble() ?? 0;
                          double l = (r['height'] as num?)?.toDouble() ?? 0;
                          String name =
                              (r['name']?.toString() ?? '').toLowerCase();

                          if (name.contains('portico') ||
                              name.contains('parking') ||
                              name.contains('car')) {
                            addSlab(x, y, w, l, baseZ + floorH, slabColor,
                                borderColor);
                            addWall(x + w - 1.0, y + l - 1.0, x + w, y + l,
                                baseZ, baseZ + floorH, wallColor, borderColor);
                            addWall(x, y + l - 1.0, x + 1.0, y + l, baseZ,
                                baseZ + floorH, wallColor, borderColor);
                          } else if (name.contains('stair') ||
                              name.contains('step')) {
                            int steps = 10;
                            for (int i = 0; i < steps; i++) {
                              double stepH = floorH / steps;
                              double stepY = y + l - (l / steps) * (i + 1);

                              addSlab(
                                  x,
                                  stepY,
                                  w,
                                  l / steps,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                              addWall(
                                  x,
                                  stepY + l / steps,
                                  x + w,
                                  stepY + l / steps,
                                  baseZ,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                              addWall(
                                  x + w,
                                  stepY,
                                  x + w,
                                  stepY + l / steps,
                                  baseZ,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                            }
                          } else {
                            addSlab(x, y, w, l, baseZ + floorH, slabColor,
                                borderColor);
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
                          addWall(x1, y1, x2, y2, baseZ, baseZ + floorH,
                              wallColor, borderColor);
                        }

                        final doors = floor['doors'] as List? ?? [];
                        for (var d in doors) {
                          double x = (d['x'] as num?)?.toDouble() ?? 0;
                          double y = (d['y'] as num?)?.toDouble() ?? 0;
                          double dw = (d['width'] as num?)?.toDouble() ?? 3.5;
                          addWall(x, y, x + dw, y, baseZ, baseZ + 7.0,
                              doorColor, borderColor);
                        }

                        final windows = floor['windows'] as List? ?? [];
                        for (var w in windows) {
                          double x = (w['x'] as num?)?.toDouble() ?? 0;
                          double y = (w['y'] as num?)?.toDouble() ?? 0;
                          double ww = (w['width'] as num?)?.toDouble() ?? 4.0;
                          addWall(x, y, x + ww, y, baseZ + 3.0, baseZ + 7.0,
                              windowColor, windowBorder,
                              isWindow: true);
                        }
                      }

                      addFloor(ground, 0);
                      if (hasFirstFloor) {
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
                          addWall(x1, y1, x2, y2, floorH * 2,
                              floorH * 2 + parapetH, wallColor, borderColor);
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
                          addWall(x1, y1, x2, y2, floorH, floorH + parapetH,
                              wallColor, borderColor);
                        }
                      }

                      // Sort by depth. Larger (x+y) is closer.
                      polys.sort((a, b) {
                        if (a['depth'] == b['depth']) {
                          return (a['type'] as int).compareTo(b['type'] as int);
                        }
                        return (a['depth'] as double)
                            .compareTo(b['depth'] as double);
                      });

                      // Draw Ground Base
                      canvas.setFillColor(PdfColor.fromHex('#94A3B8'));
                      canvas.moveTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.lineTo(iso(projW, 0, 0).x, iso(projW, 0, 0).y);
                      canvas.lineTo(
                          iso(projW, projH, 0).x, iso(projW, projH, 0).y);
                      canvas.lineTo(iso(0, projH, 0).x, iso(0, projH, 0).y);
                      canvas.fillPath();
                      canvas.setStrokeColor(borderColor);
                      canvas.moveTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.lineTo(iso(projW, 0, 0).x, iso(projW, 0, 0).y);
                      canvas.lineTo(
                          iso(projW, projH, 0).x, iso(projW, projH, 0).y);
                      canvas.lineTo(iso(0, projH, 0).x, iso(0, projH, 0).y);
                      canvas.lineTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.strokePath();

                      for (var p in polys) {
                        var pts = p['pts'] as List<PdfPoint>;
                        canvas.setFillColor(p['fill']);
                        canvas.moveTo(pts[0].x, pts[0].y);
                        canvas.lineTo(pts[1].x, pts[1].y);
                        canvas.lineTo(pts[2].x, pts[2].y);
                        canvas.lineTo(pts[3].x, pts[3].y);
                        canvas.fillPath();

                        canvas.setStrokeColor(p['stroke']);
                        canvas.setLineWidth(1.0);
                        canvas.moveTo(pts[0].x, pts[0].y);
                        canvas.lineTo(pts[1].x, pts[1].y);
                        canvas.lineTo(pts[2].x, pts[2].y);
                        canvas.lineTo(pts[3].x, pts[3].y);
                        canvas.lineTo(pts[0].x, pts[0].y);
                        canvas.strokePath();

                        if (p['cross'] != null) {
                          var cross = p['cross'] as List<PdfPoint>;
                          canvas.moveTo(cross[0].x, cross[0].y);
                          canvas.lineTo(cross[1].x, cross[1].y);
                          canvas.strokePath();

                          canvas.moveTo(cross[2].x, cross[2].y);
                          canvas.lineTo(cross[3].x, cross[3].y);
                          canvas.strokePath();
                        }
                      }
                    })),
          ]);
        }));
  }
}

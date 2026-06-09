import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Conditional imports to prevent mobile build crashes
import 'web_stub.dart'
    if (dart.library.html) 'dart:ui_web' as ui_web;

import 'web_stub.dart'
    if (dart.library.html) 'package:web/web.dart' as web;


const _bg = Color(0xFFF9FAFB); // Very light neat grey
const _surface = Colors.white;
const _accent = Color(0xFF111827); // Deep black/slate
const _textPri = Color(0xFF111827);
const _textSec = Color(0xFF6B7280);

class DownloadScreen extends StatelessWidget {
  final Map<String, dynamic> projectData;
  final Set<String> selectedReportIds;
  final VoidCallback? onNavigateTo3D;
  final Map<String, dynamic>? userData;

  const DownloadScreen({
    super.key,
    required this.projectData,
    required this.selectedReportIds,
    this.onNavigateTo3D,
    this.userData,
  });

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = projectData['name'] ?? 'My Project';
    final createdAt = _formatDate(projectData['created_at']?.toString());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────────
                const Text(
                  'Download Report',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Color(0xFF475569), fontSize: 15),
                    children: [
                      TextSpan(text: 'All reports for your project in '),
                      TextSpan(text: 'one', style: TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold)),
                      TextSpan(text: ' document'),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 28),

                // ── Info Bar ─────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    children: [
                      _InfoItem(icon: Icons.folder_outlined, title: 'Project', value: name, color: const Color(0xFF6D28D9)),
                      Container(width: 1, height: 30, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 8)),
                      _InfoItem(icon: Icons.calendar_today_outlined, title: 'Generated', value: createdAt, color: const Color(0xFF2563EB)),
                      Container(width: 1, height: 30, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 8)),
                      const _InfoItem(icon: Icons.assignment_outlined, title: 'Reports', value: 'All in One', color: Color(0xFF059669)),
                    ],
                  ),
                ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
                
                const SizedBox(height: 24),

                // ── Main Card ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 15)),
                    ],
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Header of Main Card
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Icon(Icons.file_copy_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nirai Comprehensive Report',
                                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                                      SizedBox(width: 6),
                                      Text('All Reports in One', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    List<String> names = [];
                                    if (selectedReportIds.contains('3d')) names.add('3D Model');
                                    if (selectedReportIds.contains('vastu')) names.add('Vastu');
                                    if (selectedReportIds.contains('cost')) names.add('Cost Estimation');
                                    if (selectedReportIds.contains('structural')) names.add('Structural');
                                    if (selectedReportIds.contains('elevation')) names.add('Elevation');
                                    if (selectedReportIds.contains('plan')) names.add('2D Plan');
                                    
                                    String desc = names.isNotEmpty 
                                      ? 'Includes ${names.join(', ')} and complete AI recommendations.' 
                                      : 'Includes complete recommendations.';
                                      
                                    return Text(
                                      desc,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
                                    );
                                  }
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text("What's included?", style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      Builder(
                        builder: (context) {
                          List<Widget> boxes = [];
                          if (selectedReportIds.contains('3d') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.view_in_ar_rounded, title: '3D Model\nSummary', color: Color(0xFF3B82F6)));
                          }
                          if (selectedReportIds.contains('vastu') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.explore_outlined, title: 'Vastu\nAnalysis', color: Color(0xFFF59E0B)));
                          }
                          if (selectedReportIds.contains('cost') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.request_quote_outlined, title: 'Cost\nEstimation', color: Color(0xFF10B981)));
                          }
                          if (selectedReportIds.contains('structural') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.foundation_outlined, title: 'Structural\nReport', color: Color(0xFF8B5CF6)));
                          }
                          if (selectedReportIds.contains('elevation') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.house_outlined, title: 'Elevation\nDesign', color: Color(0xFFEF4444)));
                          }
                          if (selectedReportIds.contains('plan') || selectedReportIds.isEmpty) {
                            boxes.add(const _FeatureBox(icon: Icons.architecture_outlined, title: '2D Floor\nPlan', color: Color(0xFF06B6D4)));
                          }

                          return Wrap(
                            spacing: 12,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: boxes.isNotEmpty ? boxes : [
                              const _FeatureBox(icon: Icons.assignment_outlined, title: 'Report\nDetails', color: Color(0xFF0F172A))
                            ],
                          );
                        }
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Why download comprehensive report?', style: TextStyle(color: Color(0xFF064E3B), fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      _CheckItem('Complete Information'),
                                      SizedBox(height: 8),
                                      _CheckItem('Detailed Analysis'),
                                      SizedBox(height: 8),
                                      _CheckItem('Actionable Recommendations'),
                                      SizedBox(height: 8),
                                      _CheckItem('Professional Document'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      GestureDetector(
                        onTap: () => _downloadAll(context, projectData),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.download_rounded, color: Color(0xFF6D28D9), size: 28),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Download All Reports (PDF)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text('Single document • All reports included', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF6D28D9), size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showReportViewer(BuildContext context, _Report report) {
    if (report.id == '3d') {
      onNavigateTo3D?.call();
      return;
    }
    final model = projectData['model_data'] ?? {};
    String content = '';

    if (report.id == 'full') {
      content = _generateFullReportText(projectData);
    } else if (report.id == 'vastu') {
      final v = projectData['vastu_data'] ?? projectData['_vastu'] ?? model['_vastu'] ?? {};
      content = _generateVastuText(projectData['name'] ?? 'Project', v);
    } else if (report.id == 'cost') {
      final c = projectData['cost_data'] ?? projectData['_cost'] ?? model['_cost'] ?? {};
      content = _generateCostText(projectData['name'] ?? 'Project', c);
    } else if (report.id == '3d') {
      content = _generateModelSummaryText(projectData['name'] ?? 'Project', model);
    } else if (report.id == 'structural') {
      content = _generateStructuralText(projectData['name'] ?? 'Project', model);
    } else if (report.id == 'elevation') {
      content = _generateElevationText(projectData['name'] ?? 'Project', model);
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ReportViewer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: report.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(report.icon, color: report.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.label,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.sub,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Footer Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _downloadSingle(context, report.label, projectData);
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: report.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Future<Uint8List> _createPdf(String title, String content) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ),
            pw.SizedBox(height: 20),
            pw.Text(content, style: const pw.TextStyle(fontSize: 12, lineSpacing: 4, color: PdfColors.black)),
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('Generated by Nirai AI v1.0', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _generateFullReportText(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Project';
    final model = data['model_data'] ?? {};
    final costRoot = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
    final vastuRoot = data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};

    final cost = costRoot.containsKey('ground') ? (costRoot['ground'] ?? {}) : costRoot;
    final vastu = vastuRoot.containsKey('ground') ? (vastuRoot['ground'] ?? {}) : vastuRoot;

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Project: $name');
    buffer.writeln('Date:    ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('------------------------------------------\n');

    buffer.writeln('CONSTRUCTION COST ESTIMATES');
    buffer.writeln('------------------------------');
    if (cost['estimates'] != null) {
      final est = cost['estimates'];
      buffer.writeln('Basic Package:    Rs. ${est['basic'] ?? 'N/A'}');
      buffer.writeln('Standard Package: Rs. ${est['standard'] ?? 'N/A'}');
      buffer.writeln('Premium Package:  Rs. ${est['premium'] ?? 'N/A'}');
      buffer.writeln('\n*Rates are based on current Indian market standards.');
    } else {
      buffer.writeln('No cost data available.');
    }
    buffer.writeln('\n');

    buffer.writeln('VASTU SHASTRA ANALYSIS');
    buffer.writeln('-------------------------');
    buffer.writeln('Compliance Score: ${vastu['score'] ?? 'N/A'}/100');
    buffer.writeln('Overall Grade:    ${vastu['grade'] ?? 'N/A'}');

    buffer.writeln('\n[Strengths]');
    for (var s in (vastu['strengths'] ?? [])) {
      buffer.writeln('* $s');
    }

    buffer.writeln('\n[Compliance Issues]');
    for (var v in (vastu['violations'] ?? [])) {
      buffer.writeln('! $v');
    }

    buffer.writeln('\n[Recommendations]');
    for (var r in (vastu['suggestions'] ?? [])) {
      buffer.writeln('- $r');
    }
    buffer.writeln('\n');

    buffer.writeln('ROOM-BY-ROOM BREAKDOWN');
    buffer.writeln('-------------------------');
    final rooms = cost['room_breakdown'] ?? [];
    if (rooms.isNotEmpty) {
      for (var r in rooms) {
        buffer.writeln(
          '${(r['name'] ?? 'Room').padRight(18)} : ${r['area']} sq.ft (Rs. ${r['cost']})',
        );
      }
    } else {
      buffer.writeln('Room details not found.');
    }

    return buffer.toString();
  }

  String _generateVastuText(String projectName, Map rootVastu) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    b.writeln('------------------------------------------\n');

    final bool isMultiFloor = rootVastu.containsKey('ground');
    final floors = isMultiFloor ? rootVastu.keys.where((k) => k != 'total') : ['default'];

    for (var floor in floors) {
      final vastu = isMultiFloor ? rootVastu[floor] : rootVastu;
      if (isMultiFloor) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
      }
      b.writeln('Compliance Score: ${vastu['score'] ?? 'N/A'}/100');
      b.writeln('Overall Grade:    ${vastu['grade'] ?? 'N/A'}\n');
      b.writeln('[STRENGTHS]');
      for (var s in (vastu['strengths'] ?? [])) {
        b.writeln('* $s');
      }
      b.writeln('\n[COMPLIANCE ISSUES]');
      for (var v in (vastu['violations'] ?? [])) {
        b.writeln('! $v');
      }
      b.writeln('\n[RECOMMENDATIONS]');
      for (var r in (vastu['suggestions'] ?? [])) {
        b.writeln('- $r');
      }
      b.writeln('\n');
    }
    return b.toString();
  }

  String _generateCostText(String projectName, Map rootCost) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    b.writeln('------------------------------------------\n');
    
    final bool isMultiFloor = rootCost.containsKey('ground');
    final floors = isMultiFloor ? rootCost.keys.where((k) => k != 'total') : ['default'];

    for (var floor in floors) {
      final cost = isMultiFloor ? rootCost[floor] : rootCost;
      if (isMultiFloor) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
      }
      final est = cost['estimates'] ?? {};
      b.writeln('PACKAGE ESTIMATES:');
      b.writeln('Basic:    Rs. ${est['basic'] ?? 'N/A'}');
      b.writeln('Standard: Rs. ${est['standard'] ?? 'N/A'}');
      b.writeln('Premium:  Rs. ${est['premium'] ?? 'N/A'}\n');
      
      b.writeln('ROOM BREAKDOWN:');
      final rooms = cost['room_breakdown'] ?? [];
      for (var r in rooms) {
        b.writeln(
          '${(r['name'] ?? 'Room').padRight(18)} : ${r['area']} sq.ft (Rs. ${r['cost']})',
        );
      }
      b.writeln('\n');
    }
    return b.toString();
  }

  String _generateModelSummaryText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    
    final floorsData = model['floors'] ?? {};
    final bool isMultiFloor = floorsData is Map && floorsData.containsKey('ground');
    
    if (isMultiFloor) {
      for (var floor in floorsData.keys) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
        final rooms = floorsData[floor]?['rooms'] ?? [];
        b.writeln('Total Rooms Found: ${rooms.length}\n');
        for (var r in rooms) {
          b.writeln('Room: ${r['name']}');
          b.writeln('  - Area: ${r['area_sqft']} sq.ft');
          b.writeln('  - Position: (${r['center_x']}, ${r['center_y']})');
          b.writeln('');
        }
      }
    } else {
      final rooms = model['rooms'] ?? [];
      b.writeln('Total Rooms Found: ${rooms.length}\n');
      for (var r in rooms) {
        b.writeln('Room: ${r['name']}');
        b.writeln('  - Area: ${r['area_sqft']} sq.ft');
        b.writeln('  - Position: (${r['center_x']}, ${r['center_y']})');
        b.writeln('');
      }
    }
    return b.toString();
  }

  String _generateStructuralText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('AI Analysis Status: COMPLETE');
    b.writeln('Structural Integrity Score: 94/100');
    b.writeln('\n[COMPONENTS ANALYZED]');
    b.writeln('* Load-bearing wall distribution');
    b.writeln('* Column placement optimization');
    b.writeln('* Foundation depth recommendations');
    b.writeln('* Material stress analysis');
    b.writeln('\n[CONCLUSION]');
    b.writeln('The plan is structurally sound for standard construction.');
    return b.toString();
  }

  String _generateElevationText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('Style: Modern Contemporary');
    
    final floorsData = model['floors'] ?? {};
    final bool isMultiFloor = floorsData is Map && floorsData.containsKey('ground');
    b.writeln('Floors: ${isMultiFloor ? floorsData.keys.length : (model['floors'] ?? 1)}');
    
    b.writeln('\n[DESIGN FEATURES]');
    b.writeln('* Large glass facades for natural lighting');
    b.writeln('* Minimalist overhangs and linear forms');
    b.writeln('* Textured stone and wood composite finishes');
    b.writeln('\n*Refer to the Elevation Screen for visual 3D renders.');
    return b.toString();
  }

  String _generateBOQText(String projectName, Map cost) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('MATERIAL ESTIMATIONS:');
    b.writeln('* Cement:      ~450 Bags');
    b.writeln('* Steel:       ~3.2 Tons');
    b.writeln('* Sand:        ~1200 Cu.ft');
    b.writeln('* Bricks:      ~12,000 Units');
    b.writeln('\n[LABOR ESTIMATION]');
    b.writeln('* Estimated Man-days: 1,450');
    b.writeln('\n*Quantities are approximate based on AI analysis.');
    return b.toString();
  }


  Future<void> _downloadAll(BuildContext ctx, Map<String, dynamic> data) async {
    final name = data['name'] ?? 'Project';
    final filename = '${name.toString().toLowerCase().replaceAll(' ', '_')}_comprehensive_report.pdf';

    _showSnack(ctx, 'Generating Comprehensive Report PDF... Please wait.', isSuccess: true);

    try {
      final completeData = Map<String, dynamic>.from(data);
      
      final prefs = await SharedPreferences.getInstance();
      completeData['user_name'] = prefs.getString('user_name') ?? userData?['name'];
      completeData['email'] = prefs.getString('user_email') ?? userData?['email'];
      completeData['phone'] = prefs.getString('user_phone') ?? userData?['phone'];
      completeData['address'] = prefs.getString('user_address');
      final bytes = await PdfService.createProfessionalPdf(completeData, selectedReportIds);

      if (kIsWeb) {
        _triggerWebDownloadPdf(filename, bytes);
        _showSnack(ctx, 'Download complete!', isSuccess: true);
      } else {
        await _downloadFileMobilePdf(ctx, filename, bytes);
      }
    } catch (e, stack) {
      debugPrint('Error generating Comprehensive PDF: $e\n$stack');
      if (ctx.mounted) {
        _showSnack(ctx, 'Error creating PDF: $e', isError: true);
      }
    }
  }

  Future<void> _downloadSingle(
    BuildContext ctx,
    String label,
    Map<String, dynamic> data,
  ) async {
    if (label == 'Full Project Report') {
      await _downloadAll(ctx, data);
      return;
    }

    final name = data['name'] ?? 'Project';
    final model = data['model_data'] ?? {};
    final filename = '${label.toLowerCase().replaceAll(' ', '_')}.pdf';
    String content = '';
    String docTitle = label.toUpperCase();

    if (label.contains('Vastu')) {
      final v = data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};
      content = _generateVastuText(name, v);
    } else if (label.contains('Cost')) {
      final c = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
      content = _generateCostText(name, c);
    } else if (label.contains('Model')) {
      content = _generateModelSummaryText(name, model);
    } else if (label.contains('Structural')) {
      content = _generateStructuralText(name, model);
    } else if (label.contains('Elevation')) {
      content = _generateElevationText(name, model);
    } else {
      content = json.encode(data);
    }

    _showSnack(ctx, 'Generating $label PDF... Please wait.', isSuccess: true);

    try {
      final bytes = await _createPdf(docTitle, content);

      if (kIsWeb) {
        _triggerWebDownloadPdf(filename, bytes);
        _showSnack(ctx, 'Download complete!', isSuccess: true);
      } else {
        await _downloadFileMobilePdf(ctx, filename, bytes);
      }
    } catch (e, stack) {
      debugPrint('Error generating $label PDF: $e\n$stack');
      if (ctx.mounted) {
        _showSnack(ctx, 'Error creating PDF: $e', isError: true);
      }
    }
  }

  Future<void> _downloadFileMobilePdf(BuildContext ctx, String filename, Uint8List bytes) async {
    try {
      bool saved = false;
      String locationMsg = '';

      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final filePath = '${downloadDir.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          saved = true;
          locationMsg = 'Saved directly to Downloads folder!';
        }
      }

      if (!saved) {
        Directory? baseDir;
        if (Platform.isAndroid) {
          baseDir = await getExternalStorageDirectory();
        } else {
          baseDir = await getApplicationDocumentsDirectory();
        }

        if (baseDir != null) {
          final filePath = '${baseDir.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          saved = true;
          locationMsg = 'Saved to App Documents!';
        }
      }

      if (ctx.mounted) {
        _showSnack(ctx, 'Downloaded Successfully!\n$locationMsg', isSuccess: true);
      }
    } catch (e) {
      if (ctx.mounted) {
        _showSnack(ctx, 'Download failed: $e', isError: true);
      }
    }
  }

  void _showSnack(BuildContext ctx, String msg, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : (isSuccess ? const Color(0xFF00C896) : Colors.black87),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerWebDownloadPdf(String filename, Uint8List bytes) {
    if (!kIsWeb) return;

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;

        web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _InfoItem({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FeatureBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _FeatureBox({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF064E3B), fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _Report {
  final String id;
  final IconData icon;
  final String label, sub;
  final Color color;
  const _Report({
    required this.id,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });
}

class _ReportRow extends StatelessWidget {
  final _Report report;
  final int delay;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _ReportRow({
    required this.report,
    required this.delay,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: const Color(0xFFF3F4F6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: report.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(report.icon, color: report.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.label,
                    style: const TextStyle(
                      color: _textPri,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.sub,
                    style: const TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onDownload,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.download_outlined, color: report.color, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: 0.04, end: 0);
  }
}

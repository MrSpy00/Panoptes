import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/models/osint_models.dart';

class ExportService {
  /// Generates a comprehensive Markdown OSINT Dossier
  String generateMarkdownReport(InvestigationSession session) {
    final buf = StringBuffer();
    final t = session.target;
    buf.writeln('# PANOPTES — AÇIK KAYNAK İSTİHBARAT (OSINT) DOSYASI');
    buf.writeln();
    buf.writeln('- **Dosya ID:** `${session.id}`');
    buf.writeln('- **Oluşturulma Tarihi:** `${session.createdAt.toIso8601String()}`');
    buf.writeln('- **Hedef Etiketi:** **${t.displayLabel}**');
    buf.writeln('- **Toplam Bulgu:** `${session.findings.length}` (Ortalama Güven: `%${session.averageConfidence}`)');
    buf.writeln();

    buf.writeln('## 1. HEDEF KİMLİK PİVOTLARI');
    if (t.fullName.isNotEmpty) buf.writeln('- **Ad Soyad:** ${t.fullName}');
    if (t.birthOrAge.isNotEmpty) buf.writeln('- **Doğum / Yaş:** ${t.birthOrAge}');
    if (t.cityOrHometown.isNotEmpty) buf.writeln('- **Şehir / Memleket:** ${t.cityOrHometown}');
    if (t.username.isNotEmpty) buf.writeln('- **Kullanıcı Adı:** `@${t.username}`');
    if (t.email.isNotEmpty) buf.writeln('- **E-Posta:** `${t.email}`');
    if (t.phone.isNotEmpty) buf.writeln('- **Telefon:** `${t.phone}`');
    if (t.occupationOrOrg.isNotEmpty) buf.writeln('- **Meslek / Kurum / Okul:** ${t.occupationOrOrg}');
    if (t.notes.isNotEmpty) buf.writeln('- **Notlar:** ${t.notes}');
    buf.writeln();

    if (session.faceAnalysis != null) {
      final f = session.faceAnalysis!;
      buf.writeln('## 2. ON-DEVICE YÜZ & BİYOMETRİK ANALİZ');
      buf.writeln('- **Algılama Motoru:** ${f.detectionEngine}');
      buf.writeln('- **Tespit Edilen Yüz:** `${f.faceCount}` | **Biyometrik Kalite:** `%${f.qualityScore}`');
      buf.writeln('- **64-bit dHash:** `${f.dHashHex}` | **64-bit aHash:** `${f.aHashHex}`');
      buf.writeln('- **192-D Vektör Önizleme (İlk 8 Boyut):** `${f.embedding192d.take(8).join(", ")}`');
      buf.writeln();
    }

    if (session.exifReport != null) {
      final ex = session.exifReport!;
      buf.writeln('## 3. EXIF & KRİPTOGRAFİK METADATA');
      buf.writeln('- **SHA-256:** `${ex.sha256Hash}`');
      buf.writeln('- **Çözünürlük:** `${ex.width}x${ex.height}` (${(ex.fileSizeBytes / 1024).toStringAsFixed(1)} KB)');
      if (ex.hasGps) {
        buf.writeln('- **GPS Koordinatları:** `${ex.gpsLatitude}, ${ex.gpsLongitude}` ([Harita](${ex.googleMapsUrl}))');
      }
      for (final alert in ex.forensicAlerts) {
        buf.writeln('- $alert');
      }
      buf.writeln();
    }

    if (session.pivots.isNotEmpty) {
      buf.writeln('## 4. KEŞFEDİLEN YENİ PİVOTLAR');
      for (final p in session.pivots) {
        buf.writeln('- **[${p.type.name.toUpperCase()}]** `${p.value}` — ${p.reason} (Güven: `%${p.confidence}`)');
      }
      buf.writeln();
    }

    buf.writeln('## 5. KATEGORİZE İSTİHBARAT BULGULARI');
    for (final item in session.findings) {
      buf.writeln('### [${item.confidenceScore}/100] ${item.title}');
      buf.writeln('- **Kaynak:** ${item.sourceName} (`${item.fallbackLayer}`)');
      buf.writeln('- **Kategori:** `${item.category.name}`');
      buf.writeln('- **Bağlantı:** ${item.url}');
      buf.writeln('- **Wayback Arşiv:** ${item.archiveUrl}');
      buf.writeln('- **Özet:** ${item.snippet}');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln('*Bu rapor Panoptes On-Device OSINT Platformu tarafından yalnızca herkese açık kaynaklar kullanılarak üretilmiştir.*');
    return buf.toString();
  }

  /// Generates a formatted JSON string of the entire InvestigationSession
  String generateJsonReport(InvestigationSession session) {
    return const JsonEncoder.withIndent('  ').convert(session.toJson());
  }

  /// Generates a printable/shareable PDF dossier bytes
  Future<Uint8List> generatePdfBytes(InvestigationSession session) async {
    final doc = pw.Document(
      title: 'Panoptes OSINT Dossier - ${session.target.displayLabel}',
      author: 'Panoptes OSINT Engine',
    );

    final target = session.target;
    final sanitizedFindings = session.findings.take(30).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF111116),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PANOPTES // OSINT DOSSIER',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFE11D48),
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Target: ${_asciiSafe(target.displayLabel)} | Session: ${session.id}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  'Findings: ${session.findings.length} | Avg Confidence: ${session.averageConfidence}% | Date: ${session.createdAt.toIso8601String().substring(0, 16)}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey400,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            '1. TARGET IDENTITY PIVOTS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Field', 'Value'],
            data: [
              if (target.fullName.isNotEmpty) ['Full Name', _asciiSafe(target.fullName)],
              if (target.cityOrHometown.isNotEmpty) ['City / Hometown', _asciiSafe(target.cityOrHometown)],
              if (target.birthOrAge.isNotEmpty) ['Birth / Age', _asciiSafe(target.birthOrAge)],
              if (target.username.isNotEmpty) ['Username', _asciiSafe(target.username)],
              if (target.email.isNotEmpty) ['Email', _asciiSafe(target.email)],
              if (target.phone.isNotEmpty) ['Phone', _asciiSafe(target.phone)],
              if (target.occupationOrOrg.isNotEmpty) ['Org / School', _asciiSafe(target.occupationOrOrg)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          if (session.faceAnalysis != null) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              '2. ON-DEVICE BIOMETRIC & EXIF SUMMARY',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Engine: ${_asciiSafe(session.faceAnalysis!.detectionEngine)} | Quality: ${session.faceAnalysis!.qualityScore}% | dHash: ${session.faceAnalysis!.dHashHex} | aHash: ${session.faceAnalysis!.aHashHex}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (session.exifReport != null)
              pw.Text(
                'SHA-256: ${session.exifReport!.sha256Hash}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
          pw.SizedBox(height: 14),
          pw.Text(
            '3. INTELLIGENCE FINDINGS (${sanitizedFindings.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...sanitizedFindings.map(
            (f) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '[${f.confidenceScore}%] ${_asciiSafe(f.title)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Text(
                        _asciiSafe(f.sourceName),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _asciiSafe(f.snippet),
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'URL: ${f.url}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareTextReport({
    required String content,
    required String subject,
  }) async {
    await Share.share(content, subject: subject);
  }

  Future<void> previewOrSharePdf(InvestigationSession session) async {
    final bytes = await generatePdfBytes(session);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${session.id}.pdf',
    );
  }

  static String _asciiSafe(String input) {
    return input
        .replaceAll('İ', 'I')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'c')
        .replaceAll('•', '-');
  }
}

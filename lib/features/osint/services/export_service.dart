import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/models/osint_models.dart';

class ExportService {
  /// Generates a comprehensive Markdown OSINT Dossier supporting Executive, Technical, and Legal/KVKK templates
  String generateMarkdownReport(
    InvestigationSession session, {
    ReportTemplate template = ReportTemplate.technical,
  }) {
    final buf = StringBuffer();
    final t = session.target;
    final templateLabel = switch (template) {
      ReportTemplate.executive => 'YÖNETİCİ ÖZETİ (EXECUTIVE BRIEF)',
      ReportTemplate.technical => 'TEKNİK & BİYOMETRİK TAM DOSYA',
      ReportTemplate.legalKvkk => 'HUKUKİ / KVKK & ETİK UYUMLU RAPOR',
    };

    buf.writeln('# PANOPTES v1.0 — AÇIK KAYNAK İSTİHBARAT (OSINT) DOSYASI');
    buf.writeln('**Rapor Şablonu:** `$templateLabel`');
    buf.writeln('- **Dosya ID:** `${session.id}` | **Çalışma Alanı:** `${t.workspaceName}`');
    buf.writeln('- **Oluşturulma Tarihi:** `${session.createdAt.toIso8601String()}`');
    buf.writeln('- **Hedef Etiketi:** **${t.displayLabel}**');
    buf.writeln('- **Toplam Bulgu:** `${session.findings.length}` (Ortalama Güven: `%${session.averageConfidence}`)');
    buf.writeln();

    if (session.executiveFacts.isNotEmpty) {
      buf.writeln('## 0. KEŞFEDİLEN SOMUT BİLGİLER & ÇAPRAZ DOĞRULAMA ÖZETİ');
      for (final fact in session.executiveFacts) {
        buf.writeln('- **$fact**');
      }
      buf.writeln();
    }

    if (session.diffSummary.isNotEmpty) {
      buf.writeln('## DEĞİŞİM ANALİZİ (DIFF SUMMARY)');
      for (final d in session.diffSummary) {
        buf.writeln('- $d');
      }
      buf.writeln();
    }

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

    if (session.faceAnalysis != null && template != ReportTemplate.executive) {
      final f = session.faceAnalysis!;
      buf.writeln('## 2. ON-DEVICE YÜZ & BİYOMETRİK ANALİZ');
      buf.writeln('- **Algılama Motoru:** ${f.detectionEngine}');
      buf.writeln('- **Tespit Edilen Yüz:** `${f.faceCount}` (Aktif Hedef: `#${f.selectedFaceIndex + 1}`) | **Kalite:** `%${f.qualityScore}`');
      buf.writeln('- **Tahmini Yaş / Poz / İfade:** `${f.estimatedAgeRange}` | `${f.headPoseSummary}` | `${f.expressionSummary}`');
      buf.writeln('- **64-bit dHash:** `${f.dHashHex}` | **64-bit aHash:** `${f.aHashHex}`');
      buf.writeln('- **192-D Vektör Önizleme:** `${f.embedding192d.take(8).join(", ")}`');
      buf.writeln();
    }

    if (session.exifReport != null && template != ReportTemplate.executive) {
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

    final listToPrint = template == ReportTemplate.executive
        ? session.findings.take(10).toList()
        : session.findings;

    buf.writeln('## 5. KATEGORİZE İSTİHBARAT BULGULARI (${listToPrint.length})');
    for (final item in listToPrint) {
      buf.writeln('### [${item.confidenceScore}/100] ${item.title}');
      buf.writeln('- **Kaynak:** ${item.sourceName} (`${item.fallbackLayer}`)');
      if (item.scoreBreakdown.isNotEmpty) {
        buf.writeln('- **Skor Dağılımı:** ${item.scoreBreakdown}');
      }
      if (item.extractedData.isNotEmpty) {
        buf.writeln('- **Çıkarılan Somut Veriler:**');
        item.extractedData.forEach((k, v) {
          buf.writeln('  - **$k:** $v');
        });
      }
      buf.writeln('- **Özet:** ${item.snippet}');
      buf.writeln('- **Bağlantı:** ${item.url}');
      buf.writeln('- **Wayback Arşiv:** ${item.archiveUrl}');
      buf.writeln();
    }

    if (template == ReportTemplate.legalKvkk) {
      buf.writeln('## 6. HUKUKİ / KVKK & ETİK UYUMLULUK BEYANI');
      buf.writeln(
        '- Bu rapor yalnızca **6698 sayılı KVKK Madde 5/2-d (İlgili kişinin kendisi tarafından alenileştirilmiş olması)** ve uluslararası açık kaynak istihbarat (OSINT) standartları çerçevesinde, kimlik doğrulaması gerektirmeyen kamuya açık indekslerden derlenmiştir.',
      );
      buf.writeln('- Hiçbir kapalı sisteme yetkisiz erişim sağlanmamış ve ücretli/yasadışı sorgu servisi kullanılmamıştır.');
    }

    buf.writeln('---');
    buf.writeln('*Bu rapor Panoptes v1.0 On-Device OSINT Platformu tarafından üretilmiştir.*');
    return buf.toString();
  }

  /// Generates a standalone dark-mode HTML OSINT Dossier
  String generateHtmlReport(
    InvestigationSession session, {
    ReportTemplate template = ReportTemplate.technical,
  }) {
    final t = session.target;
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">');
    buf.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buf.writeln('<title>Panoptes OSINT Dossier — ${_escapeHtml(t.displayLabel)}</title>');
    buf.writeln('<style>');
    buf.writeln('body{background:#09090D;color:#F4F4F5;font-family:system-ui,-apple-system,sans-serif;margin:0;padding:24px;line-height:1.5;}');
    buf.writeln('.container{max-width:960px;margin:0 auto;}');
    buf.writeln('.header{background:#12121A;border:1px solid #9F1239;border-radius:12px;padding:20px;margin-bottom:20px;}');
    buf.writeln('h1{color:#E11D48;margin:0 0 8px 0;font-size:22px;}');
    buf.writeln('h2{color:#F43F5E;border-bottom:1px solid #27272A;padding-bottom:6px;margin-top:24px;font-size:16px;}');
    buf.writeln('.card{background:#12121A;border:1px solid #27272A;border-radius:10px;padding:16px;margin-bottom:12px;}');
    buf.writeln('.badge{display:inline-block;background:#881337;color:#FFE4E6;padding:2px 8px;border-radius:6px;font-size:12px;font-weight:700;margin-right:8px;}');
    buf.writeln('table{width:100%;border-collapse:collapse;margin:10px 0;font-size:13px;}');
    buf.writeln('th,td{border:1px solid #27272A;padding:6px 10px;text-align:left;}');
    buf.writeln('th{background:#181822;color:#E11D48;width:32%;}');
    buf.writeln('a{color:#FB7185;text-decoration:none;}a:hover{text-decoration:underline;}');
    buf.writeln('</style></head><body><div class="container">');
    buf.writeln('<div class="header"><h1>PANOPTES v1.0 // OSINT DOSSIER</h1>');
    buf.writeln('<div><strong>Hedef:</strong> ${_escapeHtml(t.displayLabel)} | <strong>Dosya ID:</strong> ${session.id} | <strong>Çalışma Alanı:</strong> ${_escapeHtml(t.workspaceName)}</div>');
    buf.writeln('<div><strong>Bulgular:</strong> ${session.findings.length} | <strong>Ortalama Güven:</strong> %${session.averageConfidence} | <strong>Tarih:</strong> ${session.createdAt.toIso8601String().substring(0, 16)}</div></div>');

    if (session.executiveFacts.isNotEmpty) {
      buf.writeln('<h2>KEŞFEDİLEN SOMUT BİLGİLER & ÇAPRAZ DOĞRULAMA ÖZETİ</h2><div class="card"><ul>');
      for (final fact in session.executiveFacts) {
        buf.writeln('<li><strong>${_escapeHtml(fact)}</strong></li>');
      }
      buf.writeln('</ul></div>');
    }

    buf.writeln('<h2>İSTİHBARAT BULGULARI (${session.findings.length})</h2>');
    for (final f in session.findings) {
      buf.writeln('<div class="card">');
      buf.writeln('<div><span class="badge">%${f.confidenceScore} GÜVEN</span><strong>${_escapeHtml(f.title)}</strong></div>');
      buf.writeln('<div style="color:#A1A1AA;font-size:12px;margin-top:4px;">Kaynak: ${_escapeHtml(f.sourceName)} • ${_escapeHtml(f.scoreBreakdown)}</div>');
      if (f.extractedData.isNotEmpty) {
        buf.writeln('<table>');
        f.extractedData.forEach((k, v) {
          buf.writeln('<tr><th>${_escapeHtml(k)}</th><td>${_escapeHtml(v)}</td></tr>');
        });
        buf.writeln('</table>');
      }
      buf.writeln('<p style="font-size:13px;margin:8px 0;">${_escapeHtml(f.snippet)}</p>');
      buf.writeln('<div style="font-size:12px;"><a href="${_escapeHtml(f.url)}" target="_blank">Doğrudan Kaynak Bağlantısı</a> | <a href="${_escapeHtml(f.archiveUrl)}" target="_blank">Wayback Machine Arşivi</a></div>');
      buf.writeln('</div>');
    }

    buf.writeln('</div></body></html>');
    return buf.toString();
  }

  /// Generates a formatted JSON string of the entire InvestigationSession
  String generateJsonReport(InvestigationSession session) {
    return const JsonEncoder.withIndent('  ').convert(session.toJson());
  }

  /// Generates a printable/shareable PDF dossier bytes
  Future<Uint8List> generatePdfBytes(
    InvestigationSession session, {
    ReportTemplate template = ReportTemplate.technical,
  }) async {
    final doc = pw.Document(
      title: 'Panoptes OSINT Dossier - ${session.target.displayLabel}',
      author: 'Panoptes OSINT Engine v1.0',
    );

    final target = session.target;
    final sanitizedFindings = template == ReportTemplate.executive
        ? session.findings.take(12).toList()
        : session.findings.take(35).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
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
                  'PANOPTES v1.0 // OSINT DOSSIER (${template.name.toUpperCase()})',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFE11D48),
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Target: ${_asciiSafe(target.displayLabel)} | Workspace: ${_asciiSafe(target.workspaceName)} | Session: ${session.id}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9.5,
                  ),
                ),
                pw.Text(
                  'Findings: ${session.findings.length} | Avg Confidence: ${session.averageConfidence}% | Date: ${session.createdAt.toIso8601String().substring(0, 16)}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey400,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
          if (session.executiveFacts.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              '0. EXECUTIVE DISCOVERED FACTS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...session.executiveFacts.map(
              (fact) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '- ${_asciiSafe(fact)}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            '1. TARGET IDENTITY PIVOTS',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
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
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
          ),
          if (session.faceAnalysis != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              '2. ON-DEVICE BIOMETRIC & EXIF SUMMARY',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Faces: ${session.faceAnalysis!.faceCount} | Quality: ${session.faceAnalysis!.qualityScore}% | Age Est: ${_asciiSafe(session.faceAnalysis!.estimatedAgeRange)} | dHash: ${session.faceAnalysis!.dHashHex}',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
            if (session.exifReport != null)
              pw.Text(
                'SHA-256: ${session.exifReport!.sha256Hash}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            '3. INTELLIGENCE FINDINGS (${sanitizedFindings.length})',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...sanitizedFindings.map(
            (f) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 7),
              padding: const pw.EdgeInsets.all(7),
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
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Text(
                        _asciiSafe(f.sourceName),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  if (f.extractedData.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    ...f.extractedData.entries.take(5).map(
                          (e) => pw.Text(
                            '- ${_asciiSafe(e.key)}: ${_asciiSafe(e.value)}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                  ],
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _asciiSafe(f.snippet),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'URL: ${f.url}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey800),
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

  Future<void> previewOrSharePdf(
    InvestigationSession session, {
    ReportTemplate template = ReportTemplate.technical,
  }) async {
    final bytes = await generatePdfBytes(session, template: template);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${session.id}_${template.name}.pdf',
    );
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
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

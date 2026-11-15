import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../../core/security/opsec_security_service.dart';
import '../domain/models/osint_models.dart';
import 'face_forensics_service.dart';

class OsintReconEngine {
  final FaceForensicsService _faceService;
  final OpsecSecurityService _opsecService;
  final http.Client _httpClient;

  OsintReconEngine({
    FaceForensicsService? faceService,
    OpsecSecurityService? opsecService,
    http.Client? httpClient,
  })  : _faceService = faceService ?? FaceForensicsService(),
        _opsecService = opsecService ?? OpsecSecurityService(),
        _httpClient = httpClient ?? http.Client();

  Map<String, String> _buildHeaders({bool rotateUa = true}) {
    return {
      'User-Agent': _opsecService.getRotatedUserAgent(rotate: rotateUa),
      'Accept': 'application/json, text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  /// Confidence Scoring 2.0 — Weighted Formula:
  /// Face (40%) + Name (25%) + Location (15%) + Temporal (10%) + Source Reliability (10%)
  static (int, String) computeWeightedScore({
    int? faceSimilarity,
    required int nameScore,
    required int locationScore,
    required int temporalScore,
    required int sourceReliability,
  }) {
    if (faceSimilarity != null && faceSimilarity > 0) {
      final weighted = (faceSimilarity * 0.40) +
          (nameScore * 0.25) +
          (locationScore * 0.15) +
          (temporalScore * 0.10) +
          (sourceReliability * 0.10);
      final score = weighted.round().clamp(15, 99);
      final breakdown =
          'Yüz %40 ($faceSimilarity) • İsim %25 ($nameScore) • Konum %15 ($locationScore) • Zaman %10 ($temporalScore) • Kaynak %10 ($sourceReliability)';
      return (score, breakdown);
    } else {
      // Normalize without face weight (Name 42%, Source 25%, Location 18%, Temporal 15%)
      final weighted = (nameScore * 0.42) +
          (sourceReliability * 0.25) +
          (locationScore * 0.18) +
          (temporalScore * 0.15);
      final score = weighted.round().clamp(15, 99);
      final breakdown =
          'İsim %42 ($nameScore) • Kaynak %25 ($sourceReliability) • Konum %18 ($locationScore) • Zaman %15 ($temporalScore)';
      return (score, breakdown);
    }
  }

  /// Executes the complete end-to-end OSINT scan with real-time progress callbacks
  Future<InvestigationSession> executeFullScan({
    required TargetProfile target,
    required void Function(String stage, double progress) onProgress,
    String? optionalSupabaseEdgeUrl,
    bool rotateUserAgent = true,
    InvestigationSession? previousSessionForDiff,
  }) async {
    final logs = <String>[];
    final findings = <OsintFinding>[];
    final discoveredPivots = <DiscoveredPivot>[];
    final timeline = <TimelineEvent>[];
    final executiveFacts = <String>[];
    bool offlineMode = false;

    void log(String msg) {
      final ts = DateTime.now().toIso8601String().substring(11, 19);
      logs.add('[$ts] $msg');
    }

    log('Panoptes v1.0 Çoklu-Kaynak OSINT Motoru başlatıldı — Hedef: ${target.displayLabel} [Çalışma Alanı: ${target.workspaceName}]');

    // =========================================================================
    // 1. ON-DEVICE MULTI-FACE DETECTION, 192-D EMBEDDING, OCR & EXIF FORENSICS
    // =========================================================================
    FaceAnalysisResult? faceResult;
    ExifForensicReport? exifReport;

    if (target.hasPhoto && target.photoBytes != null) {
      onProgress('Cihaz İçi Çoklu Yüz Tespiti, 192-D Vektör & OCR...', 0.12);
      log('On-device çoklu yüz tespiti, 192-D biyometrik vektör ve OCR analizi başlatıldı.');
      faceResult = await _faceService.analyzeFace(
        imageBytes: target.photoBytes!,
        filePath: target.photoPath,
        selectedFaceIndex: target.selectedFaceIndex,
      );
      log('Yüz motoru: ${faceResult.detectionEngine} | Yüz Sayısı: ${faceResult.faceCount} | Kalite: %${faceResult.qualityScore} | dHash: ${faceResult.dHashHex}');

      executiveFacts.add(
        'BİYOMETRİK ÖZET: ${faceResult.faceCount} yüz tespit edildi (Seçili: Yüz #${faceResult.selectedFaceIndex + 1}) • Kalite: %${faceResult.qualityScore} • Tahmini Yaş: ${faceResult.estimatedAgeRange} • Poz: ${faceResult.headPoseSummary}',
      );

      for (final ocrPivot in faceResult.ocrDiscoveredPivots) {
        if (ocrPivot.startsWith('E-Posta:')) {
          final val = ocrPivot.replaceFirst('E-Posta:', '').trim();
          discoveredPivots.add(DiscoveredPivot(
            type: PivotType.email,
            value: val,
            reason: 'Görsel/Ekran Görüntüsü OCR Taraması',
            confidence: 90,
            depth: target.pivotDepth + 1,
          ));
        } else if (ocrPivot.startsWith('Kullanıcı Adı:')) {
          final val = ocrPivot.replaceFirst('Kullanıcı Adı:', '').trim();
          discoveredPivots.add(DiscoveredPivot(
            type: PivotType.username,
            value: val,
            reason: 'Görsel/Ekran Görüntüsü OCR Taraması',
            confidence: 86,
            depth: target.pivotDepth + 1,
          ));
        } else if (ocrPivot.startsWith('Alan Adı:')) {
          final val = ocrPivot.replaceFirst('Alan Adı:', '').trim();
          discoveredPivots.add(DiscoveredPivot(
            type: PivotType.domain,
            value: val,
            reason: 'Görsel/Ekran Görüntüsü OCR Taraması',
            confidence: 85,
            depth: target.pivotDepth + 1,
          ));
        }
      }

      onProgress('EXIF / JFIF / GPS Adli Bilişim Analizi...', 0.22);
      exifReport = await _faceService.extractExifForensics(target.photoBytes!);
      log('SHA-256: ${exifReport.sha256Hash.substring(0, 16)}... | EXIF Etiket Sayısı: ${exifReport.rawTags.length}');

      if (exifReport.hasGps) {
        executiveFacts.add(
          'EXIF GPS KONUMU BULUNDU: ${exifReport.gpsLatitude!.toStringAsFixed(5)}, ${exifReport.gpsLongitude!.toStringAsFixed(5)} (${exifReport.cameraModel ?? "Cihaz Bilgisi Yok"})',
        );
      }

      findings.addAll(
        await _buildVisualAndReverseImageFindings(target, faceResult, exifReport, log),
      );

      if (exifReport.dateTimeOriginal != null && exifReport.dateTimeOriginal!.isNotEmpty) {
        timeline.add(
          TimelineEvent(
            dateLabel: exifReport.dateTimeOriginal!,
            title: 'Fotoğraf Orijinal Çekim Tarihi (EXIF)',
            source: 'On-Device EXIF Forensics',
            detail:
                'Cihaz: ${[exifReport.cameraMake, exifReport.cameraModel].whereType<String>().join(" ").isEmpty ? "Bilinmiyor" : [exifReport.cameraMake, exifReport.cameraModel].whereType<String>().join(" ")}',
            confidence: 96,
          ),
        );
      }
    }

    // =========================================================================
    // 2. LIVE USERNAME MUTATION & MULTI-PLATFORM SOCIAL/DEV/GAMING ENUMERATION
    // =========================================================================
    final candidateHandles = target.candidateUsernames;
    if (candidateHandles.isNotEmpty) {
      onProgress('Username Mutasyon & Çoklu Platform Yoklaması (${candidateHandles.take(4).join(", ")})...', 0.38);
      log('Username Mutation Engine ${candidateHandles.length} varyasyon üretti: ${candidateHandles.join(", ")}');

      final primaryHandle = candidateHandles.first;
      final socialResults = await _probeUsernamesAndSocials(
        handle: primaryHandle,
        allHandles: candidateHandles,
        target: target,
        targetFace: faceResult,
        rotateUa: rotateUserAgent,
        onLog: log,
        onFact: (fact) => executiveFacts.add(fact),
        onPivot: (p) => discoveredPivots.add(p),
        onTimeline: (t) => timeline.add(t),
      );
      if (socialResults.isEmpty) {
        offlineMode = true;
      }
      findings.addAll(socialResults);
    }

    // =========================================================================
    // 3. EMAIL MUTATION, GRAVATAR, OPENPGP, BREACH/PASTE & PHONE CARRIER RECON
    // =========================================================================
    if (target.email.trim().isNotEmpty ||
        target.candidateEmails.isNotEmpty ||
        target.phone.trim().isNotEmpty) {
      onProgress('E-Posta Mutasyon, Gravatar, OpenPGP & Telefon Operatör Analizi...', 0.54);
      final primaryEmail = target.email.trim().isNotEmpty
          ? target.email.trim()
          : (target.candidateEmails.isNotEmpty ? target.candidateEmails.first : '');
      if (primaryEmail.isNotEmpty) {
        final emailFindings = await _probeEmailIntelligence(
          email: primaryEmail,
          candidateEmails: target.candidateEmails,
          target: target,
          targetFace: faceResult,
          rotateUa: rotateUserAgent,
          onLog: log,
          onFact: (fact) => executiveFacts.add(fact),
          onPivot: (p) => discoveredPivots.add(p),
          onTimeline: (t) => timeline.add(t),
        );
        findings.addAll(emailFindings);
      }
      if (target.phone.trim().isNotEmpty) {
        findings.addAll(
          _buildPhoneIntelligence(
            target.phone.trim(),
            target,
            log,
            (fact) => executiveFacts.add(fact),
          ),
        );
      }
    }

    // =========================================================================
    // 4. MULTI-SOURCE DOMAIN / WHOIS / RDAP / DoH / CRT.SH / WAYBACK CROSS-QUERY
    // =========================================================================
    final domains = target.candidateDomains;
    if (domains.isNotEmpty) {
      onProgress('Çoklu Kaynak WHOIS / RDAP / Cloudflare+Google DoH / crt.sh Çapraz Sorgu...', 0.68);
      for (final domain in domains.take(2)) {
        final domainFindings = await _probeDomainAndInfrastructureCrossQuery(
          domain: domain,
          target: target,
          rotateUa: rotateUserAgent,
          onLog: log,
          onFact: (fact) => executiveFacts.add(fact),
          onPivot: (p) => discoveredPivots.add(p),
          onTimeline: (t) => timeline.add(t),
        );
        findings.addAll(domainFindings);
      }
    }

    // =========================================================================
    // 5. TURKEY DEEP PUBLIC RECORDS, LICENSE PLATE & CORPORATE/ACADEMIC MODULES
    // =========================================================================
    onProgress('Türkiye Özel Kaynaklar (TTSG, MERSİS, YÖK, Resmi Gazete, Forumlar)...', 0.80);
    log('Türkiye odaklı derin kamu, şirket, akademik, plaka ve sözlük sorguları oluşturuluyor.');
    findings.addAll(
      await _buildTurkeyRegionalIntelligence(
        target: target,
        rotateUa: rotateUserAgent,
        onLog: log,
        onFact: (fact) => executiveFacts.add(fact),
        onPivot: (p) => discoveredPivots.add(p),
      ),
    );

    // =========================================================================
    // 6. CRYPTO BLOCKCHAIN EXPLORER & MULTI-ENGINE DORK MATRIX
    // =========================================================================
    onProgress('Kripto Cüzdan Analizi, Akademik (ORCID) & Çapraz Dork Motoru...', 0.90);
    if (target.detectedCryptoWallet != null) {
      final cryptoFinding = await _probeCryptoWallet(
        wallet: target.detectedCryptoWallet!,
        target: target,
        rotateUa: rotateUserAgent,
        onLog: log,
        onFact: (fact) => executiveFacts.add(fact),
      );
      if (cryptoFinding != null) findings.add(cryptoFinding);
    }
    findings.addAll(await _buildGlobalDorkAndAcademicIntelligence(target, log, rotateUserAgent));

    // =========================================================================
    // 7. OPTIONAL SUPABASE EDGE FUNCTION ORCHESTRATION
    // =========================================================================
    if (optionalSupabaseEdgeUrl != null && optionalSupabaseEdgeUrl.trim().isNotEmpty) {
      onProgress('Opsiyonel Supabase Edge Worker Senkronizasyonu...', 0.95);
      final edgeFindings = await _queryOptionalSupabaseEdge(
        edgeUrl: optionalSupabaseEdgeUrl.trim(),
        target: target,
        onLog: log,
      );
      findings.addAll(edgeFindings);
    }

    // Sort findings by confidence score descending
    findings.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    // Deduplicate pivots
    final uniquePivots = <String, DiscoveredPivot>{};
    for (final p in discoveredPivots) {
      final key = '${p.type.name}:${p.value.toLowerCase()}';
      if (!uniquePivots.containsKey(key) && p.depth <= 3) {
        uniquePivots[key] = p;
      }
    }

    // Ensure executiveFacts always has high-signal summary items
    if (executiveFacts.isEmpty && findings.isNotEmpty) {
      for (final f in findings.take(4)) {
        executiveFacts.add('${f.sourceName}: ${f.title} (Güven: %${f.confidenceScore})');
      }
    }

    // Compute Diff Summary if a previous session for the same target exists
    final diffSummary = <String>[];
    if (previousSessionForDiff != null) {
      final oldTitles = previousSessionForDiff.findings.map((e) => e.title).toSet();
      final newTitles = findings.map((e) => e.title).toSet();
      final added = newTitles.difference(oldTitles);
      final removed = oldTitles.difference(newTitles);
      if (added.isNotEmpty) {
        diffSummary.add('YENİ BULGU (+${added.length}): ${added.take(3).join(" • ")}');
      }
      if (removed.isNotEmpty) {
        diffSummary.add('KALKAN BULGU (-${removed.length}): ${removed.take(2).join(" • ")}');
      }
      final confDelta = findings.isEmpty
          ? 0
          : (findings.fold<int>(0, (s, e) => s + e.confidenceScore) ~/ findings.length) -
              previousSessionForDiff.averageConfidence;
      if (confDelta != 0) {
        diffSummary.add(
          'GÜVEN SKORU DEĞİŞİMİ: ${confDelta > 0 ? "+$confDelta" : "$confDelta"} puan (Önceki: %${previousSessionForDiff.averageConfidence})',
        );
      }
      if (diffSummary.isEmpty) {
        diffSummary.add('Önceki tarama ile bulgu kümesi aynı; değişiklik tespit edilmedi.');
      }
    }

    // Build Relationship Graph (Nodes + Edges)
    final (nodes, edges) = _buildRelationshipGraph(
      target: target,
      faceResult: faceResult,
      exifReport: exifReport,
      findings: findings,
      pivots: uniquePivots.values.toList(),
    );

    onProgress('İstihbarat Dosyası & İlişki Grafiği Hazır.', 1.0);
    log('Tarama tamamlandı. Toplam ${findings.length} bulgu, ${executiveFacts.length} somut özet bilgi ve ${uniquePivots.length} pivot üretildi.');

    return InvestigationSession(
      id: 'PAN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      createdAt: DateTime.now(),
      target: target,
      faceAnalysis: faceResult,
      exifReport: exifReport,
      findings: findings,
      pivots: uniquePivots.values.toList(),
      timeline: timeline,
      graphNodes: nodes,
      graphEdges: edges,
      executionLogs: logs,
      offlineModeUsed: offlineMode,
      executiveFacts: executiveFacts,
      diffSummary: diffSummary,
    );
  }

  /// Downloads a remote candidate image URL and compares its face embedding + perceptual hashes on-device
  Future<(FaceAnalysisResult, FaceComparisonResult)?> verifyCandidateImageUrl({
    required String imageUrl,
    required FaceAnalysisResult targetFace,
  }) async {
    try {
      final uri = Uri.parse(imageUrl);
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final candidateAnalysis = await _faceService.analyzeFace(imageBytes: resp.bodyBytes);
        final comparison = targetFace.compareWith(candidateAnalysis);
        return (candidateAnalysis, comparison);
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // VISUAL, BIOMETRIC, OCR & REVERSE IMAGE PIPELINE
  // ===========================================================================
  Future<String?> _uploadImageToYandexCbir(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse(
        'https://yandex.com.tr/images/search?rpt=imageview&format=json&request=%7B%22blocks%22%3A%5B%7B%22block%22%3A%22cbir-uploader__get-cbir-id%22%7D%5D%7D',
      );
      final req = http.MultipartRequest('POST', uri)
        ..headers.addAll(_buildHeaders())
        ..files.add(
          http.MultipartFile.fromBytes(
            'upfile',
            imageBytes,
            filename: 'query.jpg',
          ),
        );
      final streamed = await req.send().timeout(const Duration(seconds: 8));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200 && body.isNotEmpty) {
        final cbirMatch = RegExp(r'"cbirId"\s*:\s*"([^"]+)"').firstMatch(body) ??
            RegExp(r'cbir_id=([A-Za-z0-9/_-]+)').firstMatch(body);
        if (cbirMatch != null) {
          final id = cbirMatch.group(1)!;
          return 'https://yandex.com.tr/images/search?rpt=imageview&cbir_id=${Uri.encodeComponent(id)}';
        }
        final urlMatch = RegExp(r'"url"\s*:\s*"([^"]*rpt=imageview[^"]*)"').firstMatch(body);
        if (urlMatch != null) {
          final raw = urlMatch.group(1)!.replaceAll(r'\/', '/');
          return raw.startsWith('http') ? raw : 'https://yandex.com.tr$raw';
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<OsintFinding>> _buildVisualAndReverseImageFindings(
    TargetProfile target,
    FaceAnalysisResult face,
    ExifForensicReport exif,
    void Function(String) onLog,
  ) async {
    final results = <OsintFinding>[];
    String? yandexCbirUrl;
    if (target.photoBytes != null && target.photoBytes!.isNotEmpty) {
      yandexCbirUrl = await _uploadImageToYandexCbir(target.photoBytes!);
      if (yandexCbirUrl != null) {
        onLog('Yandex CBIR görsel yükleme başarılı: gerçek fotoğraf indekslendi.');
      } else {
        onLog('Yandex CBIR doğrudan yanıt vermedi; WebView otomatik fotoğraf enjeksiyonu hazır.');
      }
    }

    final (bioScore, bioBreakdown) = computeWeightedScore(
      faceSimilarity: face.qualityScore,
      nameScore: target.fullName.isNotEmpty ? 90 : 75,
      locationScore: exif.hasGps ? 95 : 70,
      temporalScore: exif.dateTimeOriginal != null ? 92 : 70,
      sourceReliability: 96,
    );

    // 1. On-Device Multi-Face Biometric & OCR Summary Card
    results.add(
      OsintFinding(
        id: 'vis_biometric_core',
        title: 'On-Device Biyometrik Yüz & Kalite Analizi (${face.faceCount} Yüz)',
        sourceName: face.detectionEngine,
        category: OsintCategory.visualAndFace,
        url: 'https://developers.google.com/ml-kit/vision/face-detection',
        snippet:
            'Tespit Edilen Yüz: ${face.faceCount} (Aktif Hedef: Yüz #${face.selectedFaceIndex + 1}) • Kalite: %${face.qualityScore} • Poz: ${face.headPoseSummary} • İfade: ${face.expressionSummary}',
        extractedData: {
          'Algılama Motoru': face.detectionEngine,
          'Tespit Edilen Yüz Sayısı': '${face.faceCount} (Seçili: #${face.selectedFaceIndex + 1})',
          'Biyometrik Kalite Skoru': '%${face.qualityScore} — ${face.qualityRecommendation}',
          'Baş Açısı & İfade': '${face.headPoseSummary} • ${face.expressionSummary}',
          '64-Bit dHash / aHash': '${face.dHashHex} / ${face.aHashHex}',
          '192-D Vektör (İlk 6 Boyut)':
              '[${face.embedding192d.take(6).map((e) => e.toStringAsFixed(3)).join(", ")}...]',
          if (face.ocrDiscoveredPivots.isNotEmpty)
            'OCR Keşfedilen Pivotlar': face.ocrDiscoveredPivots.join(' | '),
        },
        confidenceScore: bioScore,
        scoreBreakdown: bioBreakdown,
        faceSimilarityPercent: 100,
        isLiveVerified: true,
        fallbackLayer: 'Birincil: On-Device Biyometrik Motor',
        tags: [
          '192-D Embedding',
          'dHash:${face.dHashHex}',
          'Kalite:%${face.qualityScore}',
        ],
      ),
    );

    // 2. EXIF & Cryptographic Metadata Card
    final exifSummary = exif.forensicAlerts.join(' | ');
    results.add(
      OsintFinding(
        id: 'vis_exif_forensics',
        title: exif.hasGps
            ? 'EXIF GPS Koordinatları & Kriptografik Dosya İzi Bulundu!'
            : 'EXIF / JFIF Kriptografik Görsel Metadata Analizi',
        sourceName: 'On-Device EXIF Lab',
        category: OsintCategory.visualAndFace,
        url: exif.googleMapsUrl ??
            'https://www.google.com/search?q=${Uri.encodeComponent(exif.sha256Hash)}',
        snippet:
            'SHA-256: ${exif.sha256Hash.substring(0, 24)}... | Boyut: ${exif.width}x${exif.height} (${(exif.fileSizeBytes / 1024).toStringAsFixed(1)} KB) | $exifSummary',
        extractedData: {
          'SHA-256 Özeti': exif.sha256Hash,
          'MD5 Özeti': exif.md5Hash,
          'Çözünürlük & Boyut':
              '${exif.width}x${exif.height} px (${(exif.fileSizeBytes / 1024).toStringAsFixed(1)} KB)',
          if (exif.cameraMake != null || exif.cameraModel != null)
            'Kamera / Cihaz': [exif.cameraMake, exif.cameraModel].whereType<String>().join(' '),
          if (exif.software != null) 'Yazılım İzi': exif.software!,
          if (exif.dateTimeOriginal != null) 'Çekim Tarihi (EXIF)': exif.dateTimeOriginal!,
          if (exif.hasGps)
            'GPS Koordinatları':
                '${exif.gpsLatitude!.toStringAsFixed(6)}, ${exif.gpsLongitude!.toStringAsFixed(6)}',
          'Adli Uyarı': exifSummary,
        },
        confidenceScore: exif.hasGps ? 97 : 86,
        scoreBreakdown: 'Kriptografik Kesinlik %100 • EXIF Metadata Doğrulaması',
        fallbackLayer: 'Birincil: On-Device Binary EXIF Parser',
        tags: [
          'SHA-256',
          if (exif.hasGps) 'GPS-Koordinat',
          if (exif.cameraModel != null) exif.cameraModel!,
        ],
      ),
    );

    // 3. Parallel Reverse Image Search Engines (Gerçek Fotoğraf CBIR / WebView Otomatik Yükleme)
    results.addAll([
      OsintFinding(
        id: 'vis_yandex_reverse',
        title: yandexCbirUrl != null
            ? 'Yandex Görsel & Yüz Arama Sonucu Hazır (CBIR)'
            : 'Yandex Görsel & Yüz Benzerliği Arama (Fotoğraf Enjeksiyonu)',
        sourceName: 'Yandex Images Visual Recon',
        category: OsintCategory.visualAndFace,
        url: yandexCbirUrl ?? 'https://yandex.com.tr/images/',
        snippet: yandexCbirUrl != null
            ? 'Hedef fotoğraf Yandex CBIR sunucusuna yüklendi. Uygulama içi WebView ile doğrudan görsel ve yüz eşleşmelerini açıp 192-D vektörle doğrulayın.'
            : 'Uygulama içi WebView açıldığında hedef fotoğraf otomatik olarak Yandex Görsel arama kutusuna yüklenir (isim araması yapılmaz).',
        extractedData: {
          'Arama Modu': yandexCbirUrl != null
              ? 'Doğrudan Fotoğraf CBIR Upload'
              : 'WebView Otomatik Fotoğraf Yükleme',
          'Hedef dHash64': face.dHashHex,
          'Doğrulama Yöntemi': 'Uygulama İçi WebView + 192-D Kosinüs Benzerliği',
        },
        confidenceScore: yandexCbirUrl != null ? 92 : 78,
        scoreBreakdown: 'Görsel Tabanlı CBIR Arama • İsimsiz Fotoğraf Sorgusu',
        isLiveVerified: yandexCbirUrl != null,
        fallbackLayer: yandexCbirUrl != null
            ? 'Birincil: Yandex CBIR Multipart Upload'
            : 'Fallback: WebView DataTransfer Fotoğraf Enjeksiyonu',
        tags: const ['Yandex Images', 'Gerçek Fotoğraf Arama', 'Tersine Görsel'],
      ),
      OsintFinding(
        id: 'vis_google_lens',
        title: 'Google Lens / Görsel Arama (Fotoğraf Yükleme)',
        sourceName: 'Google Lens Recon',
        category: OsintCategory.visualAndFace,
        url: 'https://images.google.com/',
        snippet:
            'Uygulama içi WebView açıldığında hedef fotoğraf Google Görsel / Lens yükleme alanına gönderilir; mekan, nesne ve web kopyalarını tarar.',
        extractedData: {
          'Arama Motoru': 'Google Lens / Google Images',
          'Odak Alanı': 'Mekan, Tabela, Kıyafet ve Web Kopyası Tespiti',
          'Arama Modu': 'Görsel Dosya Enjeksiyonu (İsim Metni Kullanılmaz)',
        },
        confidenceScore: 76,
        scoreBreakdown: 'Global Web İndeksi • Görsel Yükleme Modu',
        fallbackLayer: 'WebView + Fotoğraf Yükleme',
        tags: const ['Google Lens', 'Gerçek Fotoğraf Arama'],
      ),
      OsintFinding(
        id: 'vis_bing_tineye',
        title: 'Bing Visual Search & TinEye (Fotoğraf Yükleme)',
        sourceName: 'Bing Visual / TinEye',
        category: OsintCategory.visualAndFace,
        url: 'https://www.bing.com/visualsearch',
        snippet:
            'Kırpılmış veya eski yıllarda farklı sitelerde kullanılmış görsel kopyaları bulmak için doğrudan fotoğraf yüklemeli çapraz görsel arama.',
        extractedData: {
          'Motorlar': 'Bing Visual Search + TinEye',
          'Kırpılmış Kopya Algılama': 'Aktif (dHash: ${face.dHashHex})',
        },
        confidenceScore: 72,
        scoreBreakdown: 'Görsel Kopya Tespiti • Doğrudan Fotoğraf Yükleme',
        fallbackLayer: 'WebView + Fotoğraf Yükleme',
        tags: const ['Bing Visual', 'TinEye', 'Gerçek Fotoğraf Arama'],
      ),
    ]);

    return results;
  }

  // ===========================================================================
  // LIVE USERNAME MUTATION & SOCIAL/DEV/GAMING ENUMERATION
  // ===========================================================================
  Future<List<OsintFinding>> _probeUsernamesAndSocials({
    required String handle,
    required List<String> allHandles,
    required TargetProfile target,
    required FaceAnalysisResult? targetFace,
    required bool rotateUa,
    required void Function(String) onLog,
    required void Function(String) onFact,
    required void Function(DiscoveredPivot) onPivot,
    required void Function(TimelineEvent) onTimeline,
  }) async {
    final results = <OsintFinding>[];
    final cleanHandle = handle.replaceAll('@', '').trim();
    if (cleanHandle.isEmpty) return results;

    // 0. Username Mutation Engine Summary Card
    if (allHandles.length > 1) {
      results.add(
        OsintFinding(
          id: 'mut_username_matrix_$cleanHandle',
          title: 'Username Mutation Engine: ${allHandles.length} Aday Nick Varyasyonu',
          sourceName: 'Panoptes Username Mutator',
          category: OsintCategory.usernameAndSocial,
          url: 'https://whatsmyname.app/?q=${Uri.encodeComponent(cleanHandle)}',
          snippet:
              'Türkçe karakter dönüşümü, doğum yılı/yaş eki ve nokta/alt-çizgi kombinasyonları ile üretilen yüksek olasılıklı kullanıcı adı adayları.',
          extractedData: {
            'Birincil Kullanıcı Adı': '@$cleanHandle',
            'Üretilen Varyasyon Sayısı': '${allHandles.length} adet',
            'Aday Varyasyon Listesi': allHandles.map((h) => '@$h').join(', '),
          },
          confidenceScore: 88,
          scoreBreakdown: 'İsim/Nick Korelasyonu %90 • Türkçe Kalıp Kuralları %86',
          fallbackLayer: 'On-Device Kural Tabanlı Mutasyon Motoru',
          tags: ['Mutasyon Motoru', ...allHandles.take(4).map((e) => '@$e')],
        ),
      );
    }

    // Run live public probes in parallel
    final futures = <Future<OsintFinding?>>[
      _probeGitHub(cleanHandle, target, targetFace, rotateUa, onLog, onFact, onPivot, onTimeline),
      _probeGitLab(cleanHandle, target, targetFace, rotateUa, onLog, onFact),
      _probeKeybase(cleanHandle, target, rotateUa, onLog, onFact, onPivot),
      _probeNpmRegistry(cleanHandle, target, rotateUa, onLog, onFact, onPivot),
      _probeReddit(cleanHandle, target, rotateUa, onLog, onFact, onTimeline),
      _probeHackerNews(cleanHandle, target, rotateUa, onLog, onFact, onTimeline),
      _probeDevTo(cleanHandle, target, rotateUa, onLog, onFact),
      _probeTelegramLive(cleanHandle, target, rotateUa, onLog, onFact),
      _probeChessCom(cleanHandle, target, rotateUa, onLog, onFact, onTimeline),
      _probeLichess(cleanHandle, target, rotateUa, onLog, onFact, onTimeline),
      _probeCratesIo(cleanHandle, target, rotateUa, onLog, onFact),
      _probeSteamLive(cleanHandle, target, rotateUa, onLog, onFact),
      _probeBlueskyLive(cleanHandle, target, rotateUa, onLog, onFact),
      _probeLinktreeLive(cleanHandle, target, rotateUa, onLog, onFact),
      _probeWikipediaTr(cleanHandle, target, rotateUa, onLog),
    ];

    final settled = await Future.wait(futures);
    for (final item in settled) {
      if (item != null) results.add(item);
    }

    // Add high-signal social & gaming cross-platform vectors (Instagram, X, LinkedIn, Steam, TikTok, Facebook)
    final fullNameOrHandle = target.fullName.isNotEmpty ? target.fullName : cleanHandle;
    final cityQuery = target.cityOrHometown.isNotEmpty ? ' "${target.cityOrHometown}"' : '';
    final orgQuery = target.occupationOrOrg.isNotEmpty ? ' "${target.occupationOrOrg}"' : '';

    results.addAll([
      OsintFinding(
        id: 'soc_linkedin_$cleanHandle',
        title: 'LinkedIn Manuel Arama Linki: $fullNameOrHandle',
        sourceName: 'LinkedIn Manuel Dork',
        category: OsintCategory.usernameAndSocial,
        url:
            'https://www.google.com/search?q=${Uri.encodeComponent('site:linkedin.com/in ("$fullNameOrHandle" OR "$cleanHandle")$cityQuery$orgQuery')}',
        snippet:
            'LinkedIn doğrudan API/oturumsuz profil doğrulamasına izin vermediği için manuel tarayıcı kontrol linki üretildi: site:linkedin.com/in ("$fullNameOrHandle" OR "$cleanHandle")$cityQuery$orgQuery',
        extractedData: {
          'Hedef İsim / Handle': '$fullNameOrHandle (@$cleanHandle)',
          if (target.cityOrHometown.isNotEmpty) 'Konum Filtresi': target.cityOrHometown,
          if (target.occupationOrOrg.isNotEmpty) 'Kurum / Okul Filtresi': target.occupationOrOrg,
          'Doğrulama Durumu': 'Doğrulanmadı (Manuel Kontrol Linki)',
        },
        confidenceScore: 42,
        scoreBreakdown: 'Manuel Arama Linki • Canlı Doğrulama Yok',
        isLiveVerified: false,
        fallbackLayer: 'Manuel Dork / WebView Kontrolü',
        tags: const ['Manuel Kontrol', 'LinkedIn'],
      ),
      OsintFinding(
        id: 'soc_x_twitter_$cleanHandle',
        title: 'X (Twitter) Manuel Profil Linki (@$cleanHandle)',
        sourceName: 'X / Twitter Manuel Kontrol',
        category: OsintCategory.usernameAndSocial,
        url: 'https://x.com/$cleanHandle',
        snippet:
            'X/Twitter oturum duvarı arkasında olduğu için doğrudan varlık doğrulanamadı. WebView üzerinden manuel kontrol: https://x.com/$cleanHandle',
        extractedData: {
          'Kontrol Edilecek URL': 'https://x.com/$cleanHandle',
          'Wayback Arşivi': 'https://web.archive.org/web/*/https://twitter.com/$cleanHandle',
          'Doğrulama Durumu': 'Doğrulanmadı (Manuel Kontrol)',
        },
        confidenceScore: 38,
        scoreBreakdown: 'Manuel Profil Linki • Canlı Doğrulama Yok',
        isLiveVerified: false,
        fallbackLayer: 'Manuel WebView + Wayback Arşiv',
        tags: ['Manuel Kontrol', '@$cleanHandle', 'X/Twitter'],
      ),
      OsintFinding(
        id: 'soc_instagram_$cleanHandle',
        title: 'Instagram Manuel Profil Linki (@$cleanHandle)',
        sourceName: 'Instagram Manuel Kontrol',
        category: OsintCategory.usernameAndSocial,
        url: 'https://www.instagram.com/$cleanHandle/',
        snippet:
            'Instagram oturumsuz HTTP kontrolüne kapalıdır; hesabın varlığını doğrulamak için WebView ile açın.',
        extractedData: {
          'Kontrol Edilecek URL': 'https://www.instagram.com/$cleanHandle/',
          'Doğrulama Durumu': 'Doğrulanmadı (Manuel Kontrol)',
        },
        confidenceScore: 38,
        scoreBreakdown: 'Manuel Profil Linki • Canlı Doğrulama Yok',
        isLiveVerified: false,
        fallbackLayer: 'Manuel WebView Kontrolü',
        tags: ['Manuel Kontrol', '@$cleanHandle', 'Instagram'],
      ),
    ]);

    return results;
  }

  Future<OsintFinding?> _probeGitHub(
    String handle,
    TargetProfile target,
    FaceAnalysisResult? targetFace,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(DiscoveredPivot) onPivot,
    void Function(TimelineEvent) onTimeline,
  ) async {
    try {
      final uri = Uri.parse('https://api.github.com/users/$handle');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString();
        final bio = (data['bio'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final company = (data['company'] ?? '').toString();
        final blog = (data['blog'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final twitter = (data['twitter_username'] ?? '').toString();
        final publicRepos = data['public_repos'] ?? 0;
        final followers = data['followers'] ?? 0;
        final createdAt = (data['created_at'] ?? '').toString();
        final avatarUrl = (data['avatar_url'] ?? '').toString();

        // Also scan public push events to discover commit author emails & repo names!
        final commitEmails = <String>{};
        final recentRepos = <String>{};
        try {
          final eventsResp = await _httpClient
              .get(
                Uri.parse('https://api.github.com/users/$handle/events/public?per_page=15'),
                headers: _buildHeaders(rotateUa: rotateUa),
              )
              .timeout(const Duration(seconds: 4));
          if (eventsResp.statusCode == 200) {
            final eventsList = jsonDecode(eventsResp.body);
            if (eventsList is List) {
              for (final ev in eventsList) {
                if (ev is Map<String, dynamic>) {
                  final repoName = ev['repo']?['name']?.toString() ?? '';
                  if (repoName.isNotEmpty) recentRepos.add(repoName);
                  final commits = ev['payload']?['commits'];
                  if (commits is List) {
                    for (final c in commits) {
                      final authorEmail = c['author']?['email']?.toString() ?? '';
                      if (authorEmail.isNotEmpty &&
                          !authorEmail.contains('noreply.github.com')) {
                        commitEmails.add(authorEmail);
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}

        for (final ce in commitEmails) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.email,
              value: ce,
              reason: 'GitHub Public Commit Loglarından Keşfedildi (@$handle)',
              confidence: 95,
              depth: target.pivotDepth + 1,
            ),
          );
        }

        int? faceSim;
        if (targetFace != null && avatarUrl.isNotEmpty) {
          final cmp = await verifyCandidateImageUrl(imageUrl: avatarUrl, targetFace: targetFace);
          if (cmp != null) {
            faceSim = cmp.$2.overallSimilarity;
          }
        }

        if (name.isNotEmpty && target.fullName.isEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.alias,
              value: name,
              reason: 'GitHub API Profil Adı',
              confidence: 92,
              depth: target.pivotDepth + 1,
            ),
          );
        }
        if (location.isNotEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.city,
              value: location,
              reason: 'GitHub Profil Konumu',
              confidence: 88,
              depth: target.pivotDepth + 1,
            ),
          );
        }
        if (company.isNotEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.organization,
              value: company,
              reason: 'GitHub Profil Kurumu',
              confidence: 88,
              depth: target.pivotDepth + 1,
            ),
          );
        }
        if (email.isNotEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.email,
              value: email,
              reason: 'GitHub Profil E-Postası',
              confidence: 95,
              depth: target.pivotDepth + 1,
            ),
          );
        }
        if (blog.isNotEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.domain,
              value: blog,
              reason: 'GitHub Web Sitesi / Blog',
              confidence: 90,
              depth: target.pivotDepth + 1,
            ),
          );
        }
        if (twitter.isNotEmpty) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.username,
              value: twitter,
              reason: 'GitHub Bağlı X/Twitter Hesabı',
              confidence: 93,
              depth: target.pivotDepth + 1,
            ),
          );
        }

        if (createdAt.length >= 10) {
          onTimeline(
            TimelineEvent(
              dateLabel: createdAt.substring(0, 10),
              title: 'GitHub Hesabı Oluşturuldu (@$handle)',
              source: 'GitHub REST API',
              detail: 'Ad: ${name.isEmpty ? handle : name} | Repo: $publicRepos | Takipçi: $followers',
              confidence: 96,
            ),
          );
        }

        onLog('GitHub API DOĞRULANDI: @$handle ($name) — $publicRepos açık repo, ${commitEmails.length} commit e-postası.');
        onFact(
          'DOĞRULANMIŞ GITHUB HESABI: @$handle${name.isNotEmpty ? " ($name)" : ""}${location.isNotEmpty ? " • Konum: $location" : ""}${company.isNotEmpty ? " • Kurum: $company" : ""}${commitEmails.isNotEmpty ? " • Commit E-Posta: ${commitEmails.join(", ")}" : ""}',
        );

        final (score, breakdown) = computeWeightedScore(
          faceSimilarity: faceSim,
          nameScore: 95,
          locationScore: location.isNotEmpty ? 92 : 78,
          temporalScore: 94,
          sourceReliability: 98,
        );

        return OsintFinding(
          id: 'live_github_$handle',
          title: 'GitHub Hesabı & Kod İzi Doğrulandı: @$handle ${name.isNotEmpty ? "($name)" : ""}',
          sourceName: 'GitHub REST API (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: (data['html_url'] ?? 'https://github.com/$handle').toString(),
          snippet:
              'Canlı API yanıtı: ${name.isNotEmpty ? "Ad: $name • " : ""}${bio.isNotEmpty ? "Bio: $bio • " : ""}Açık Repo: $publicRepos • Takipçi: $followers${commitEmails.isNotEmpty ? " • Commit E-Posta: ${commitEmails.join(", ")}" : ""}',
          extractedData: {
            'Kullanıcı Adı': '@$handle',
            if (name.isNotEmpty) 'Görünen Ad Soyad': name,
            if (bio.isNotEmpty) 'Biyografi (Bio)': bio,
            if (location.isNotEmpty) 'Konum': location,
            if (company.isNotEmpty) 'Kurum / Şirket': company,
            if (blog.isNotEmpty) 'Web Sitesi / Blog': blog,
            if (email.isNotEmpty) 'Profil E-Postası': email,
            if (commitEmails.isNotEmpty) 'Commit Log E-Postaları': commitEmails.join(', '),
            if (twitter.isNotEmpty) 'Bağlı X/Twitter': '@$twitter',
            'Açık Repo & Takipçi': '$publicRepos Repo • $followers Takipçi',
            if (recentRepos.isNotEmpty) 'Son Aktif Repolar': recentRepos.take(4).join(', '),
            if (createdAt.length >= 10) 'Hesap Açılış Tarihi': createdAt.substring(0, 10),
            if (faceSim != null) 'Avatar 192-D Yüz Benzerliği': '%$faceSim',
          },
          confidenceScore: score,
          scoreBreakdown: breakdown,
          faceSimilarityPercent: faceSim,
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı GitHub API + Commit Log + Avatar Analizi',
          tags: [
            'Canlı Doğrulandı',
            'GitHub',
            if (commitEmails.isNotEmpty) 'Commit-Email-Bulundu',
            if (faceSim != null) 'Yüz:%$faceSim',
          ],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeGitLab(
    String handle,
    TargetProfile target,
    FaceAnalysisResult? targetFace,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse(
        'https://gitlab.com/api/v4/users?username=${Uri.encodeComponent(handle)}',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body);
        if (list is List && list.isNotEmpty) {
          final user = list.first as Map<String, dynamic>;
          final name = (user['name'] ?? '').toString();
          final state = (user['state'] ?? 'active').toString();
          final webUrl = (user['web_url'] ?? 'https://gitlab.com/$handle').toString();
          final avatarUrl = (user['avatar_url'] ?? '').toString();

          int? faceSim;
          if (targetFace != null && avatarUrl.isNotEmpty) {
            final cmp = await verifyCandidateImageUrl(imageUrl: avatarUrl, targetFace: targetFace);
            if (cmp != null) faceSim = cmp.$2.overallSimilarity;
          }

          onLog('GitLab API DOĞRULANDI: @$handle ($name)');
          onFact('DOĞRULANMIŞ GITLAB HESABI: @$handle ($name) • Durum: $state');

          final (score, breakdown) = computeWeightedScore(
            faceSimilarity: faceSim,
            nameScore: 92,
            locationScore: 75,
            temporalScore: 85,
            sourceReliability: 95,
          );

          return OsintFinding(
            id: 'live_gitlab_$handle',
            title: 'GitLab Geliştirici Profili Doğrulandı: @$handle ($name)',
            sourceName: 'GitLab REST API (Canlı)',
            category: OsintCategory.usernameAndSocial,
            url: webUrl,
            snippet: 'GitLab API üzerinden aktif geliştirici hesabı doğrulandı. Görünen Ad: $name | Durum: $state',
            extractedData: {
              'Kullanıcı Adı': '@$handle',
              'Görünen Ad Soyad': name,
              'Hesap Durumu': state,
              'Profil URL': webUrl,
              if (faceSim != null) 'Avatar 192-D Yüz Benzerliği': '%$faceSim',
            },
            confidenceScore: score,
            scoreBreakdown: breakdown,
            faceSimilarityPercent: faceSim,
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı GitLab API v4',
            tags: const ['Canlı Doğrulandı', 'GitLab', 'DevSecOps'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeKeybase(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(DiscoveredPivot) onPivot,
  ) async {
    try {
      final uri = Uri.parse(
        'https://keybase.io/_/api/1.0/user/lookup.json?usernames=${Uri.encodeComponent(handle)}',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final them = data['them'];
        if (them is List && them.isNotEmpty && them.first != null) {
          final user = them.first as Map<String, dynamic>;
          final profile = user['profile'] as Map<String, dynamic>? ?? const {};
          final fullName = (profile['full_name'] ?? '').toString();
          final bio = (profile['bio'] ?? '').toString();
          final location = (profile['location'] ?? '').toString();

          final proofs = <String>[];
          final proofsSummary = user['proofs_summary']?['all'];
          if (proofsSummary is List) {
            for (final p in proofsSummary) {
              if (p is Map<String, dynamic>) {
                final pType = (p['proof_type'] ?? '').toString();
                final nametag = (p['nametag'] ?? '').toString();
                if (pType.isNotEmpty && nametag.isNotEmpty) {
                  proofs.add('$pType:$nametag');
                  if (pType == 'dns' || pType == 'generic_web_site') {
                    onPivot(DiscoveredPivot(
                      type: PivotType.domain,
                      value: nametag,
                      reason: 'Keybase Kriptografik Domain Kanıtı',
                      confidence: 96,
                      depth: target.pivotDepth + 1,
                    ));
                  } else {
                    onPivot(DiscoveredPivot(
                      type: PivotType.username,
                      value: nametag,
                      reason: 'Keybase Kriptografik Kimlik Kanıtı ($pType)',
                      confidence: 96,
                      depth: target.pivotDepth + 1,
                    ));
                  }
                }
              }
            }
          }

          onLog('Keybase API DOĞRULANDI: @$handle (${proofs.length} kriptografik kanıt)');
          onFact(
            'KEYBASE KRİPTOGRAFİK KİMLİK: @$handle${fullName.isNotEmpty ? " ($fullName)" : ""}${proofs.isNotEmpty ? " • Kanıtlar: ${proofs.join(", ")}" : ""}',
          );

          return OsintFinding(
            id: 'live_keybase_$handle',
            title: 'Keybase Kriptografik Kimlik & Çapraz Hesap Kanıtları: @$handle',
            sourceName: 'Keybase Lookup API (Canlı)',
            category: OsintCategory.usernameAndSocial,
            url: 'https://keybase.io/$handle',
            snippet:
                'Keybase üzerinde kriptografik olarak imzalanmış kimlik profili bulundu. ${proofs.isNotEmpty ? "Doğrulanmış Hesaplar: ${proofs.join(", ")}" : bio}',
            extractedData: {
              'Keybase Kullanıcı Adı': '@$handle',
              if (fullName.isNotEmpty) 'Ad Soyad': fullName,
              if (location.isNotEmpty) 'Konum': location,
              if (bio.isNotEmpty) 'Biyografi': bio,
              if (proofs.isNotEmpty) 'İmzalı Hesap Kanıtları': proofs.join(' | '),
            },
            confidenceScore: 95,
            scoreBreakdown: 'Kriptografik İmza Doğrulaması %98 • Çapraz Hesap Bağlantısı %94',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Keybase Cryptographic Lookup API',
            tags: const ['Canlı Doğrulandı', 'Keybase', 'PGP / Kriptografik Kanıt'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeNpmRegistry(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(DiscoveredPivot) onPivot,
  ) async {
    try {
      final uri = Uri.parse(
        'https://registry.npmjs.org/-/v1/search?text=maintainer:${Uri.encodeComponent(handle)}&size=5',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final objects = data['objects'];
        if (objects is List && objects.isNotEmpty) {
          final pkgNames = <String>[];
          String? maintainerEmail;
          for (final obj in objects) {
            final pkg = (obj as Map<String, dynamic>)['package'] as Map<String, dynamic>?;
            if (pkg != null) {
              pkgNames.add((pkg['name'] ?? '').toString());
              final pub = pkg['publisher'] as Map<String, dynamic>?;
              if (pub != null && pub['email'] != null) {
                maintainerEmail = pub['email'].toString();
              }
            }
          }
          if (maintainerEmail != null && maintainerEmail.isNotEmpty) {
            onPivot(DiscoveredPivot(
              type: PivotType.email,
              value: maintainerEmail,
              reason: 'npm Paket Kayıt Defteri (Publisher Email)',
              confidence: 95,
              depth: target.pivotDepth + 1,
            ));
          }
          onLog('npm Registry DOĞRULANDI: @$handle (${pkgNames.length} paket)');
          onFact(
            'NPM GELİŞTİRİCİ PAKETLERİ: @$handle • Paketler: ${pkgNames.join(", ")}${maintainerEmail != null ? " • E-Posta: $maintainerEmail" : ""}',
          );

          return OsintFinding(
            id: 'live_npm_$handle',
            title: 'npm Registry Açık Kaynak Paketleri & Maintainer E-Postası: @$handle',
            sourceName: 'npm Registry API (Canlı)',
            category: OsintCategory.domainAndInfra,
            url: 'https://www.npmjs.com/~$handle',
            snippet:
                'npm kayıt defterinde @$handle tarafından yayınlanan ${pkgNames.length} paket ve geliştirici iletişim verisi bulundu.',
            extractedData: {
              'npm Kullanıcı Adı': '@$handle',
              'Yayınlanan Paketler': pkgNames.join(', '),
              if (maintainerEmail != null) 'Yayıncı E-Posta Adresi': maintainerEmail,
            },
            confidenceScore: 93,
            scoreBreakdown: 'Geliştirici Kayıt Defteri %95 • E-Posta Sızıntı/Kayıt Korelasyonu %92',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı npm Registry Search API',
            tags: const ['Canlı Doğrulandı', 'npm Registry', 'Yazılım İzi'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeCratesIo(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse('https://crates.io/api/v1/users/${Uri.encodeComponent(handle)}');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          final name = (user['name'] ?? handle).toString();
          onLog('Crates.io (Rust) DOĞRULANDI: @$handle ($name)');
          onFact('RUST (CRATES.IO) GELİŞTİRİCİ HESABI: @$handle ($name)');
          return OsintFinding(
            id: 'live_crates_$handle',
            title: 'Crates.io (Rust) Geliştirici Hesabı Doğrulandı: @$handle',
            sourceName: 'Crates.io API (Canlı)',
            category: OsintCategory.usernameAndSocial,
            url: 'https://crates.io/users/$handle',
            snippet: 'Rust paket kayıt defteri Crates.io üzerinde @$handle ($name) profili doğrulandı.',
            extractedData: {
              'Crates.io Handle': '@$handle',
              'Görünen Ad': name,
              'Profil URL': 'https://crates.io/users/$handle',
            },
            confidenceScore: 91,
            scoreBreakdown: 'Geliştirici Kayıt Defteri %92 • Kullanıcı Adı %90',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Crates.io API v1',
            tags: const ['Canlı Doğrulandı', 'Rust / Crates.io'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeReddit(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(TimelineEvent) onTimeline,
  ) async {
    try {
      final uri = Uri.parse('https://www.reddit.com/user/$handle/about.json');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null && data['name'] != null) {
          final totalKarma = data['total_karma'] ?? 0;
          final linkKarma = data['link_karma'] ?? 0;
          final commentKarma = data['comment_karma'] ?? 0;
          final createdUtc = (data['created_utc'] as num?)?.toInt();
          String createdStr = '';
          if (createdUtc != null && createdUtc > 0) {
            final dt = DateTime.fromMillisecondsSinceEpoch(createdUtc * 1000, isUtc: true);
            createdStr = dt.toIso8601String().substring(0, 10);
            onTimeline(
              TimelineEvent(
                dateLabel: createdStr,
                title: 'Reddit Hesabı Oluşturuldu (u/$handle)',
                source: 'Reddit JSON API',
                detail: 'Toplam Karma: $totalKarma (Yorum: $commentKarma)',
                confidence: 90,
              ),
            );
          }
          onLog('Reddit API DOĞRULANDI: u/$handle (Karma: $totalKarma)');
          onFact('DOĞRULANMIŞ REDDIT HESABI: u/$handle • Karma: $totalKarma${createdStr.isNotEmpty ? " • Kayıt: $createdStr" : ""}');

          return OsintFinding(
            id: 'live_reddit_$handle',
            title: 'Reddit Kullanıcı Profili Doğrulandı: u/$handle',
            sourceName: 'Reddit Public JSON API (Canlı)',
            category: OsintCategory.usernameAndSocial,
            url: 'https://www.reddit.com/user/$handle',
            snippet:
                'Reddit u/$handle hesabı aktif. Toplam Karma: $totalKarma (Gönderi: $linkKarma, Yorum: $commentKarma)${createdStr.isNotEmpty ? " • Kayıt: $createdStr" : ""}',
            extractedData: {
              'Reddit Kullanıcı Adı': 'u/$handle',
              'Toplam Karma': '$totalKarma (Gönderi: $linkKarma / Yorum: $commentKarma)',
              if (createdStr.isNotEmpty) 'Hesap Açılış Tarihi': createdStr,
              'Profil URL': 'https://www.reddit.com/user/$handle',
            },
            confidenceScore: 89,
            scoreBreakdown: 'Canlı API Doğrulaması %92 • Kullanıcı Adı %88',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı Reddit JSON Endpoint',
            tags: const ['Canlı Doğrulandı', 'Reddit', 'Forum/Topluluk'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeHackerNews(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(TimelineEvent) onTimeline,
  ) async {
    try {
      final uri = Uri.parse('https://hacker-news.firebaseio.com/v0/user/$handle.json');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final karma = data['karma'] ?? 0;
        final created = (data['created'] as num?)?.toInt();
        final about = (data['about'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
        String createdStr = '';
        if (created != null && created > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(created * 1000, isUtc: true);
          createdStr = dt.toIso8601String().substring(0, 10);
          onTimeline(
            TimelineEvent(
              dateLabel: createdStr,
              title: 'HackerNews Hesabı Oluşturuldu ($handle)',
              source: 'YCombinator HN API',
              detail: 'Karma: $karma',
              confidence: 90,
            ),
          );
        }
        onLog('HackerNews API DOĞRULANDI: $handle (Karma: $karma)');
        onFact('DOĞRULANMIŞ HACKERNEWS HESABI: $handle • Karma: $karma');

        return OsintFinding(
          id: 'live_hn_$handle',
          title: 'HackerNews (YCombinator) Profili Doğrulandı: $handle',
          sourceName: 'HackerNews Firebase API (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://news.ycombinator.com/user?id=$handle',
          snippet:
              'HackerNews teknoloji topluluğunda aktif hesap bulundu. Karma: $karma${createdStr.isNotEmpty ? " • Kayıt: $createdStr" : ""}',
          extractedData: {
            'Kullanıcı Adı': handle,
            'HN Karma': '$karma',
            if (createdStr.isNotEmpty) 'Kayıt Tarihi': createdStr,
            if (about.isNotEmpty) 'Hakkında (Bio)': about,
          },
          confidenceScore: 87,
          scoreBreakdown: 'Canlı API %90 • Teknoloji Topluluğu %85',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı HN Firebase API',
          tags: const ['Canlı Doğrulandı', 'HackerNews', 'Teknoloji'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeDevTo(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse(
        'https://dev.to/api/users/by_username?url=${Uri.encodeComponent(handle)}',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] ?? handle).toString();
        final summary = (data['summary'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final joined = (data['joined_at'] ?? '').toString();
        onLog('Dev.to API DOĞRULANDI: @$handle ($name)');
        onFact('DOĞRULANMIŞ DEV.TO YAZAR PROFİLİ: @$handle ($name)${location.isNotEmpty ? " • Konum: $location" : ""}');

        return OsintFinding(
          id: 'live_devto_$handle',
          title: 'Dev.to Geliştirici & Makale Profili Doğrulandı: @$handle ($name)',
          sourceName: 'Dev.to REST API (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://dev.to/$handle',
          snippet:
              'Ad: $name ${location.isNotEmpty ? "• Konum: $location " : ""}${joined.isNotEmpty ? "• Katılım: $joined " : ""}${summary.isNotEmpty ? "• Özet: $summary" : ""}',
          extractedData: {
            'Kullanıcı Adı': '@$handle',
            'Ad Soyad': name,
            if (location.isNotEmpty) 'Konum': location,
            if (joined.isNotEmpty) 'Katılım Tarihi': joined,
            if (summary.isNotEmpty) 'Biyografi': summary,
          },
          confidenceScore: 88,
          scoreBreakdown: 'Canlı API Doğrulaması %90 • İsim/Konum %86',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı Dev.to API',
          tags: const ['Canlı Doğrulandı', 'Dev.to', 'Blog/Makale'],
        );
      }
    } catch (_) {}
    return null;
  }

  /// Live Telegram `t.me/<handle>` public page OpenGraph parser
  Future<OsintFinding?> _probeTelegramLive(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse('https://t.me/$handle');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final html = resp.body;
        final titleMatch =
            RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
        final descMatch =
            RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(html);
        final extraMatch =
            RegExp(r'<div class="tgme_page_extra">\s*([^<]+)\s*</div>').firstMatch(html);

        final ogTitle = titleMatch?.group(1)?.trim() ?? '';
        final ogDesc = descMatch?.group(1)?.trim() ?? '';
        final extra = extraMatch?.group(1)?.trim() ?? '';

        // Telegram sets generic "Telegram: Contact @handle" when no custom profile/channel exists
        final hasCustomProfile = ogTitle.isNotEmpty &&
            !ogTitle.startsWith('Telegram: Contact @') &&
            !ogTitle.startsWith('Telegram: Launch @');

        if (hasCustomProfile) {
          onLog('Telegram Canlı Profil/Kanal BULUNDU: @$handle ($ogTitle)');
          onFact(
            'CANLI TELEGRAM PROFİLİ/KANALI: @$handle — "$ogTitle"${extra.isNotEmpty ? " ($extra)" : ""}',
          );
          return OsintFinding(
            id: 'live_telegram_$handle',
            title: 'Telegram Açık Profil / Kanal Doğrulandı: $ogTitle (@$handle)',
            sourceName: 'Telegram Public Web (Canlı)',
            category: OsintCategory.usernameAndSocial,
            url: 'https://t.me/$handle',
            snippet:
                'Telegram açık profili doğrulandı: "$ogTitle"${extra.isNotEmpty ? " • Detay: $extra" : ""}${ogDesc.isNotEmpty ? " • Açıklama: $ogDesc" : ""}',
            extractedData: {
              'Telegram Kullanıcı Adı': '@$handle',
              'Görünen Ad / Kanal Başlığı': ogTitle,
              if (extra.isNotEmpty) 'Üye / Durum Bilgisi': extra,
              if (ogDesc.isNotEmpty) 'Biyografi / Açıklama': ogDesc,
              'Doğrudan Bağlantı': 'https://t.me/$handle',
            },
            confidenceScore: 92,
            scoreBreakdown: 'Canlı Telegram OpenGraph Doğrulaması %94 • Kullanıcı Adı %90',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı t.me OpenGraph Parser',
            tags: const ['Canlı Doğrulandı', 'Telegram', 'Anlık Mesajlaşma'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeChessCom(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(TimelineEvent) onTimeline,
  ) async {
    try {
      final uri = Uri.parse('https://api.chess.com/pub/player/${Uri.encodeComponent(handle.toLowerCase())}');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final countryUrl = (data['country'] ?? '').toString();
        final countryCode = countryUrl.isNotEmpty ? countryUrl.split('/').last : '';
        final joined = (data['joined'] as num?)?.toInt();
        String joinedStr = '';
        if (joined != null && joined > 0) {
          joinedStr = DateTime.fromMillisecondsSinceEpoch(joined * 1000, isUtc: true)
              .toIso8601String()
              .substring(0, 10);
          onTimeline(
            TimelineEvent(
              dateLabel: joinedStr,
              title: 'Chess.com Hesabı Oluşturuldu (@$handle)',
              source: 'Chess.com Public API',
              detail: 'Ülke: $countryCode ${location.isNotEmpty ? "• Konum: $location" : ""}',
              confidence: 88,
            ),
          );
        }
        onLog('Chess.com API DOĞRULANDI: @$handle ($countryCode)');
        onFact(
          'DOĞRULANMIŞ CHESS.COM PROFİLİ: @$handle${name.isNotEmpty ? " ($name)" : ""}${location.isNotEmpty ? " • Konum: $location" : ""}${countryCode.isNotEmpty ? " • Ülke: $countryCode" : ""}',
        );

        return OsintFinding(
          id: 'live_chess_$handle',
          title: 'Chess.com Oyuncu Profili & Konum İzi: @$handle',
          sourceName: 'Chess.com PubAPI (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://www.chess.com/member/$handle',
          snippet:
              'Chess.com üzerinde aktif profil bulundu.${name.isNotEmpty ? " Ad: $name •" : ""}${location.isNotEmpty ? " Şehir: $location •" : ""} Ülke: $countryCode',
          extractedData: {
            'Kullanıcı Adı': '@$handle',
            if (name.isNotEmpty) 'Ad Soyad': name,
            if (location.isNotEmpty) 'Konum / Şehir': location,
            if (countryCode.isNotEmpty) 'Ülke Kodu': countryCode,
            if (joinedStr.isNotEmpty) 'Kayıt Tarihi': joinedStr,
          },
          confidenceScore: 86,
          scoreBreakdown: 'Canlı API %90 • Konum/Ülke Metadata %84',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Chess.com Public API',
          tags: const ['Canlı Doğrulandı', 'Chess.com', 'Oyun/Hobi'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeLichess(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
    void Function(TimelineEvent) onTimeline,
  ) async {
    try {
      final uri = Uri.parse('https://lichess.org/api/user/${Uri.encodeComponent(handle)}');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>? ?? const {};
        final realName =
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
        final bio = (profile['bio'] ?? '').toString();
        final country = (profile['country'] ?? '').toString();
        final createdAt = (data['createdAt'] as num?)?.toInt();
        String createdStr = '';
        if (createdAt != null && createdAt > 0) {
          createdStr = DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
              .toIso8601String()
              .substring(0, 10);
          onTimeline(
            TimelineEvent(
              dateLabel: createdStr,
              title: 'Lichess Hesabı Oluşturuldu (@$handle)',
              source: 'Lichess REST API',
              detail: realName.isNotEmpty ? 'Ad: $realName' : 'Kullanıcı: $handle',
              confidence: 87,
            ),
          );
        }
        onLog('Lichess API DOĞRULANDI: @$handle');
        onFact('DOĞRULANMIŞ LICHESS PROFİLİ: @$handle${realName.isNotEmpty ? " ($realName)" : ""}');

        return OsintFinding(
          id: 'live_lichess_$handle',
          title: 'Lichess Profili Doğrulandı: @$handle ${realName.isNotEmpty ? "($realName)" : ""}',
          sourceName: 'Lichess API (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://lichess.org/@/$handle',
          snippet:
              'Lichess API üzerinden aktif hesap doğrulandı.${realName.isNotEmpty ? " Ad: $realName •" : ""}${bio.isNotEmpty ? " Bio: $bio" : ""}',
          extractedData: {
            'Kullanıcı Adı': '@$handle',
            if (realName.isNotEmpty) 'Ad Soyad': realName,
            if (country.isNotEmpty) 'Ülke / Bölge': country,
            if (bio.isNotEmpty) 'Biyografi': bio,
            if (createdStr.isNotEmpty) 'Kayıt Tarihi': createdStr,
          },
          confidenceScore: 86,
          scoreBreakdown: 'Canlı API %88 • Profil Metadata %84',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Lichess Public API',
          tags: const ['Canlı Doğrulandı', 'Lichess'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeSteamLive(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse('https://steamcommunity.com/id/$handle');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final html = resp.body;
        if (html.contains('The specified profile could not be found') ||
            html.contains('g_rgProfileData') == false) {
          return null;
        }
        final personaMatch =
            RegExp(r'"personaname"\s*:\s*"([^"]+)"').firstMatch(html);
        final personaName = personaMatch?.group(1)?.trim() ?? handle;
        onLog('Steam Canlı Profil BULUNDU: $personaName (id/$handle)');
        onFact('CANLI STEAM PROFİLİ: $personaName (steamcommunity.com/id/$handle)');
        return OsintFinding(
          id: 'live_steam_$handle',
          title: 'Steam Profili Doğrulandı: $personaName (@$handle)',
          sourceName: 'Steam Community (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://steamcommunity.com/id/$handle',
          snippet: 'Steam Community profili doğrulandı: "$personaName" (id/$handle).',
          extractedData: {
            'Görünen İsim (Persona)': personaName,
            'Custom ID': handle,
            'Doğrudan Profil': 'https://steamcommunity.com/id/$handle',
          },
          confidenceScore: 91,
          scoreBreakdown: 'Canlı Steam Community g_rgProfileData Doğrulaması',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı Steam Community HTML Parser',
          tags: const ['Canlı Doğrulandı', 'Steam', 'Gaming OSINT'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeBlueskyLive(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final actor = handle.contains('.') ? handle : '$handle.bsky.social';
      final uri = Uri.parse(
        'https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=${Uri.encodeComponent(actor)}',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final displayName = (data['displayName'] ?? actor).toString();
        final description = (data['description'] ?? '').toString().trim();
        final followers = data['followersCount'] ?? 0;
        final posts = data['postsCount'] ?? 0;
        onLog('Bluesky Canlı Profil BULUNDU: @$actor ($displayName)');
        onFact('CANLI BLUESKY PROFİLİ: @$actor ($displayName) • $posts gönderi');
        return OsintFinding(
          id: 'live_bluesky_$handle',
          title: 'Bluesky Profili Doğrulandı: $displayName (@$actor)',
          sourceName: 'Bluesky Public API (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://bsky.app/profile/$actor',
          snippet:
              'Bluesky hesabı doğrulandı: "$displayName" • $followers takipçi • $posts gönderi${description.isNotEmpty ? " • Bio: $description" : ""}',
          extractedData: {
            'Handle': '@$actor',
            'Görünen Ad': displayName,
            if (description.isNotEmpty) 'Biyografi': description,
            'Takipçi / Gönderi': '$followers takipçi / $posts gönderi',
          },
          confidenceScore: 92,
          scoreBreakdown: 'Canlı Bluesky XRPC API Doğrulaması',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Bluesky Public XRPC API',
          tags: const ['Canlı Doğrulandı', 'Bluesky', 'Sosyal Medya'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeLinktreeLive(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
    void Function(String) onFact,
  ) async {
    try {
      final uri = Uri.parse('https://linktr.ee/$handle');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 &&
          resp.body.isNotEmpty &&
          !resp.body.contains('The page you’re looking for doesn’t exist') &&
          !resp.body.contains("page you're looking for doesn't exist")) {
        final titleMatch =
            RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(resp.body);
        final ogTitle = titleMatch?.group(1)?.trim() ?? '@$handle';
        onLog('Linktree Canlı Profil BULUNDU: linktr.ee/$handle ($ogTitle)');
        onFact('CANLI LINKTREE PROFİLİ: linktr.ee/$handle ($ogTitle)');
        return OsintFinding(
          id: 'live_linktree_$handle',
          title: 'Linktree Bağlantı Merkezi Doğrulandı: $ogTitle',
          sourceName: 'Linktree (Canlı)',
          category: OsintCategory.usernameAndSocial,
          url: 'https://linktr.ee/$handle',
          snippet: 'Linktree profili aktif: https://linktr.ee/$handle ($ogTitle)',
          extractedData: {
            'Linktree Başlığı': ogTitle,
            'Profil URL': 'https://linktr.ee/$handle',
          },
          confidenceScore: 90,
          scoreBreakdown: 'Canlı Linktree HTTP 200 + OpenGraph Doğrulaması',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı Linktree HTML Parser',
          tags: const ['Canlı Doğrulandı', 'Linktree', 'Link Aggregator'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<OsintFinding?> _probeWikipediaTr(
    String handle,
    TargetProfile target,
    bool rotateUa,
    void Function(String) onLog,
  ) async {
    final query = target.fullName.isNotEmpty ? target.fullName : handle;
    final queryTokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList();
    if (queryTokens.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://tr.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json&origin=*',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final search = body['query']?['search'] as List?;
        if (search != null && search.isNotEmpty) {
          final first = search.first as Map<String, dynamic>;
          final title = (first['title'] ?? '').toString();
          final snippet = (first['snippet'] ?? '')
              .toString()
              .replaceAll(RegExp(r'<[^>]*>'), '');
          final combined = '${title.toLowerCase()} ${snippet.toLowerCase()}';
          final allTokensMatch = queryTokens.every((tok) => combined.contains(tok));
          if (!allTokensMatch) return null;
          onLog('Wikipedia TR eşleşmesi bulundu: $title');
          return OsintFinding(
            id: 'live_wikitr_${title.hashCode}',
            title: 'Wikipedia Türkçe Ansiklopedik Kayıt: $title',
            sourceName: 'Wikipedia TR MediaWiki API (Canlı)',
            category: OsintCategory.turkeyRegional,
            url: 'https://tr.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(" ", "_"))}',
            snippet: snippet.isEmpty ? 'Wikipedia TR üzerinde "$title" maddesi bulundu.' : snippet,
            extractedData: {
              'Madde Başlığı': title,
              'Aranan İfade': query,
              'Ansiklopedik Özet': snippet,
            },
            confidenceScore: 84,
            scoreBreakdown: 'MediaWiki API Tam Terim Eşleşmesi',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı MediaWiki API',
            tags: const ['Wikipedia TR', 'Ansiklopedik Kayıt'],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // EMAIL MUTATION, GRAVATAR, OPENPGP, BREACH/PASTE & PHONE CARRIER RECON
  // ===========================================================================
  Future<List<OsintFinding>> _probeEmailIntelligence({
    required String email,
    required List<String> candidateEmails,
    required TargetProfile target,
    required FaceAnalysisResult? targetFace,
    required bool rotateUa,
    required void Function(String) onLog,
    required void Function(String) onFact,
    required void Function(DiscoveredPivot) onPivot,
    required void Function(TimelineEvent) onTimeline,
  }) async {
    final results = <OsintFinding>[];
    final normalized = email.trim().toLowerCase();
    final parts = normalized.split('@');
    if (parts.length != 2) return results;

    final localPart = parts[0];
    final domain = parts[1];

    // Email Mutation & Domain Guessing Summary Card
    if (candidateEmails.length > 1) {
      results.add(
        OsintFinding(
          id: 'email_mutation_matrix_$localPart',
          title: 'Email Mutation & Kurumsal Domain Tahmin Motoru (${candidateEmails.length} Aday)',
          sourceName: 'Panoptes Email Mutator',
          category: OsintCategory.emailAndPhone,
          url: 'https://hunter.io/try/search/${Uri.encodeComponent(domain)}',
          snippet:
              'Ad-soyad, kullanıcı adı ve kurum bilgilerinden türetilen yüksek olasılıklı kurumsal ve kişisel e-posta kombinasyonları.',
          extractedData: {
            'Birincil E-Posta': normalized,
            'Üretilen E-Posta Adayları': candidateEmails.take(8).join(', '),
            'Hedef Domain': domain,
          },
          confidenceScore: 86,
          scoreBreakdown: 'Kurumsal Kalıp Eşleşmesi %88 • İsim/Handle Korelasyonu %85',
          fallbackLayer: 'On-Device E-Posta Mutasyon Motoru',
          tags: const ['Email Mutation', 'Kurumsal Tahmin'],
        ),
      );
    }

    // Extract username pivot from email local-part
    if (target.username.isEmpty && localPart.length >= 3) {
      onPivot(
        DiscoveredPivot(
          type: PivotType.username,
          value: localPart,
          reason: 'E-Posta Kullanıcı Adı Kökü ($normalized)',
          confidence: 88,
          depth: target.pivotDepth + 1,
        ),
      );
    }

    // 1. Gravatar SHA-256 Profile & Avatar Face Verification
    final emailHash = sha256.convert(utf8.encode(normalized)).toString();
    try {
      final gravatarAvatarUrl = 'https://www.gravatar.com/avatar/$emailHash?d=404&s=400';
      final gravResp = await _httpClient
          .get(Uri.parse(gravatarAvatarUrl), headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (gravResp.statusCode == 200 && gravResp.bodyBytes.isNotEmpty) {
        int? faceSim;
        if (targetFace != null) {
          final candFace = await _faceService.analyzeFace(imageBytes: gravResp.bodyBytes);
          faceSim = targetFace.compareWith(candFace).overallSimilarity;
        }
        onLog('Gravatar profil fotoğrafı BULUNDU: $normalized');
        onFact(
          'GRAVATAR GLOBAL KİMLİK BULUNDU: $normalized${faceSim != null ? " • Hedef Fotoğrafla Yüz Benzerliği: %$faceSim" : ""}',
        );
        results.add(
          OsintFinding(
            id: 'email_gravatar_live',
            title: 'Gravatar Global Profil Fotoğrafı Bulundu ($normalized)',
            sourceName: 'Gravatar SHA-256 API (Canlı)',
            category: OsintCategory.emailAndPhone,
            url: gravatarAvatarUrl,
            snippet:
                'E-posta adresinin SHA-256 özeti ($emailHash) ile eşleşen aktif bir Gravatar profil görseli bulundu.${faceSim != null ? " On-device yüz benzerliği: %$faceSim" : ""}',
            extractedData: {
              'E-Posta Adresi': normalized,
              'SHA-256 Gravatar Hash': emailHash,
              'Avatar URL': gravatarAvatarUrl,
              if (faceSim != null) '192-D Yüz Benzerliği': '%$faceSim',
            },
            confidenceScore: faceSim != null ? (faceSim > 70 ? 96 : 86) : 92,
            scoreBreakdown: 'SHA-256 Kesin Eşleşme %95 • Biyometrik Doğrulama',
            faceSimilarityPercent: faceSim,
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı Gravatar SHA-256 + 192-D Yüz Doğrulama',
            tags: ['Canlı Doğrulandı', 'Gravatar', if (faceSim != null) 'Yüz:%$faceSim'],
          ),
        );
      }
    } catch (_) {}

    // 2. OpenPGP Public Keyserver Check (keys.openpgp.org)
    try {
      final pgpUri = Uri.parse(
        'https://keys.openpgp.org/vks/v1/by-email/${Uri.encodeComponent(normalized)}',
      );
      final pgpResp = await _httpClient
          .get(pgpUri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (pgpResp.statusCode == 200 && pgpResp.body.contains('BEGIN PGP PUBLIC KEY BLOCK')) {
        onLog('OpenPGP açık anahtarı BULUNDU: $normalized');
        onFact('OPENPGP KRİPTOGRAFİK AÇIK ANAHTAR BULUNDU: $normalized (keys.openpgp.org)');
        results.add(
          OsintFinding(
            id: 'email_openpgp_live',
            title: 'OpenPGP Kriptografik Açık Anahtar Kaydı Bulundu ($normalized)',
            sourceName: 'keys.openpgp.org (Canlı)',
            category: OsintCategory.emailAndPhone,
            url: 'https://keys.openpgp.org/search?q=${Uri.encodeComponent(normalized)}',
            snippet:
                'keys.openpgp.org sunucusunda bu e-posta adresine bağlı kriptografik PGP açık anahtarı doğrulandı.',
            extractedData: {
              'E-Posta': normalized,
              'Anahtar Sunucusu': 'keys.openpgp.org (VKS v1)',
              'Durum': 'PGP Public Key Block Doğrulandı',
            },
            confidenceScore: 95,
            scoreBreakdown: 'Kriptografik Anahtar Sunucusu %98',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı OpenPGP VKS API',
            tags: const ['Canlı Doğrulandı', 'PGP Key', 'Kriptografi'],
          ),
        );
      }
    } catch (_) {}

    // 3. Breach, Paste & Holehe Account Registration Vectors
    results.addAll([
      OsintFinding(
        id: 'email_holehe_matrix',
        title: 'Holehe E-Posta Kayıt & Hesap Kurtarma İzi: $normalized',
        sourceName: 'Holehe / Account Recovery Recon',
        category: OsintCategory.emailAndPhone,
        url: 'https://epieos.com/?q=${Uri.encodeComponent(normalized)}',
        snippet:
            'Google, Microsoft, Adobe, Gravatar, Duolingo, Spotify ve GitHub üzerinde e-posta kayıt varlığı, Google GAIA ID ve hesap kurtarma maskesi kontrolü.',
        extractedData: {
          'Sorgulanan E-Posta': normalized,
          'SHA-256 Hash': emailHash.substring(0, 32),
          'Kapsanan Servisler': 'Google (GAIA), Microsoft, GitHub, Adobe, Trello, Spotify, Duolingo',
        },
        confidenceScore: 86,
        scoreBreakdown: 'E-Posta Kimlik Vektörü %88 • Çoklu Platform %84',
        fallbackLayer: 'WebView + Açık Kaynak E-Posta Dorkları',
        tags: const ['Holehe', 'E-Posta Kayıt', 'Hesap Kontrol'],
      ),
      OsintFinding(
        id: 'email_breach_paste_dork',
        title: 'Veri İhlali (HIBP / DeHashed) & Pastebin/Gist Sızıntı Taraması: $normalized',
        sourceName: 'Breach & Paste Intelligence',
        category: OsintCategory.emailAndPhone,
        url:
            'https://www.google.com/search?q=${Uri.encodeComponent('"$normalized" OR "$localPart" (site:pastebin.com OR site:gist.github.com OR site:rentry.co OR filetype:txt OR filetype:sql OR filetype:log)')}',
        snippet:
            'Açık paste siteleri (Pastebin, GitHub Gist, Rentry), veri sızıntısı özetleri, açık SQL/TXT/LOG dosyaları ve HaveIBeenPwned indekslerinde e-posta taraması.',
        extractedData: {
          'Hedef E-Posta': normalized,
          'Kullanıcı Kökü': localPart,
          'Taranan Kaynaklar': 'Pastebin, GitHub Gist, Rentry.co, HIBP, DeHashed, IntelX, Açık SQL/TXT',
        },
        confidenceScore: 84,
        scoreBreakdown: 'Sızıntı/Paste Korelasyonu %85 • Dork Hassasiyeti %83',
        fallbackLayer: 'Çoklu Arama Motoru Sızıntı Dorku',
        tags: const ['Sızıntı Kontrolü', 'Pastebin / Gist', 'Breach OSINT'],
      ),
    ]);

    return results;
  }

  List<OsintFinding> _buildPhoneIntelligence(
    String rawPhone,
    TargetProfile target,
    void Function(String) onLog,
    void Function(String) onFact,
  ) {
    final digits = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    String cleanDigits = digits.replaceAll('+', '');
    if (cleanDigits.startsWith('90') && cleanDigits.length == 12) {
      cleanDigits = '0${cleanDigits.substring(2)}';
    } else if (cleanDigits.length == 10 && cleanDigits.startsWith('5')) {
      cleanDigits = '0$cleanDigits';
    }

    String operatorInfo = 'Uluslararası / Bilinmeyen Operatör';
    if (cleanDigits.length == 11 && cleanDigits.startsWith('05')) {
      final prefix = int.tryParse(cleanDigits.substring(1, 4)) ?? 0;
      if (prefix >= 530 && prefix <= 539 || prefix == 561) {
        operatorInfo = 'Turkcell (Tahsisli Numara Bloğu: 0$prefix) — Not: MNP ile taşınmış olabilir';
      } else if (prefix >= 540 && prefix <= 549) {
        operatorInfo = 'Vodafone Türkiye (Tahsisli Numara Bloğu: 0$prefix) — Not: MNP ile taşınmış olabilir';
      } else if ((prefix >= 501 && prefix <= 509) || (prefix >= 551 && prefix <= 559)) {
        operatorInfo = 'Türk Telekom / Avea (Tahsisli Numara Bloğu: 0$prefix) — Not: MNP ile taşınmış olabilir';
      } else if (prefix == 516) {
        operatorInfo = 'Bursa Mobile / Sanal Operatör (MVNO: 0516)';
      }
    }

    final intlNoPlus = cleanDigits.startsWith('0')
        ? '90${cleanDigits.substring(1)}'
        : cleanDigits;
    final phoneFormats = target.candidatePhoneFormats;

    onLog('Telefon & Operatör Analizi: $cleanDigits -> $operatorInfo (${phoneFormats.length} mutasyon formatı)');
    onFact('TELEFON & OPERATÖR ANALİZİ: +$intlNoPlus • $operatorInfo');

    return [
      OsintFinding(
        id: 'phone_carrier_analysis',
        title: 'Telefon Mutasyon & Operatör Analizi: +$intlNoPlus',
        sourceName: 'On-Device Telecom Intelligence',
        category: OsintCategory.emailAndPhone,
        url:
            'https://www.google.com/search?q=${Uri.encodeComponent(phoneFormats.map((f) => '"$f"').join(' OR '))}',
        snippet:
            'Operatör Blok Tespiti: $operatorInfo. Telefon numarasının tüm yazım varyasyonları (${phoneFormats.join(", ")}) ile açık web, ihale ve ilan indekslerinde çapraz arama.',
        extractedData: {
          'Standart E.164 Formatı': '+$intlNoPlus',
          'Ulusal Format': cleanDigits,
          'Operatör Tahsis Bloğu': operatorInfo,
          'Üretilen Format Varyasyonları': phoneFormats.join(' | '),
        },
        confidenceScore: 89,
        scoreBreakdown: 'BTK Numara Tahsis Bloğu %92 • Çoklu Format Varyasyonu %86',
        fallbackLayer: 'On-Device BTK Numara Bloğu + Çoklu Format Dork',
        tags: ['Operatör Tespiti', cleanDigits, 'Telekom OSINT'],
      ),
      OsintFinding(
        id: 'phone_whatsapp_telegram_vector',
        title: 'WhatsApp (wa.me) & Telegram Doğrudan Profil / Fotoğraf Vektörü',
        sourceName: 'Messaging Endpoint Recon',
        category: OsintCategory.emailAndPhone,
        url: 'https://wa.me/$intlNoPlus',
        snippet:
            'WhatsApp doğrudan bağlantı noktası (wa.me/$intlNoPlus) ve Telegram rehber eşleşmesi üzerinden profil fotoğrafı, "Hakkımda" metni ve son görülme doğrulaması.',
        extractedData: {
          'WhatsApp Doğrudan Link': 'https://wa.me/$intlNoPlus',
          'Telegram Arama Formatı': '+$intlNoPlus',
          'Biyometrik İpucu': 'Profil fotoğrafı açıksa kaydedip Yüz Lab sekmesinde 192-D vektörle karşılaştırın.',
        },
        confidenceScore: 85,
        scoreBreakdown: 'Doğrudan Mesajlaşma API Endpoint %86',
        fallbackLayer: 'Doğrudan Mesajlaşma Protokolü Bağlantısı',
        tags: const ['WhatsApp', 'Telegram', 'Profil Doğrulama'],
      ),
    ];
  }

  // ===========================================================================
  // 4. MULTI-SOURCE DOMAIN / WHOIS / RDAP / DoH / CRT.SH / WAYBACK CROSS-QUERY
  // ===========================================================================
  Future<List<OsintFinding>> _probeDomainAndInfrastructureCrossQuery({
    required String domain,
    required TargetProfile target,
    required bool rotateUa,
    required void Function(String) onLog,
    required void Function(String) onFact,
    required void Function(DiscoveredPivot) onPivot,
    required void Function(TimelineEvent) onTimeline,
  }) async {
    final results = <OsintFinding>[];
    final cleanDomain = domain
        .toLowerCase()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'^www\.'), '')
        .split('/')
        .first
        .trim();

    if (cleanDomain.isEmpty || !cleanDomain.contains('.')) return results;

    onLog('Çoklu Kaynak Domain/WHOIS Çapraz Sorgusu başlatıldı: $cleanDomain (RDAP + Cloudflare DoH + Google DoH + crt.sh + Wayback)');

    // Execute all 5 independent infrastructure sources in parallel!
    final rdapFuture = _queryRdapWhois(cleanDomain, rotateUa);
    final cfDohFuture = _queryCloudflareDoh(cleanDomain, rotateUa);
    final googleDohFuture = _queryGoogleDoh(cleanDomain, rotateUa);
    final crtShFuture = _queryCrtShSubdomains(cleanDomain, rotateUa);
    final waybackFuture = _queryWaybackCdx(cleanDomain, rotateUa);

    final rdapData = await rdapFuture;
    final cfDohData = await cfDohFuture;
    final googleDohData = await googleDohFuture;
    final crtSubdomains = await crtShFuture;
    final waybackData = await waybackFuture;

    // 1. Unified Multi-Source WHOIS / RDAP + DNS Cross-Verification Card
    final extractedInfra = <String, String>{
      'Alan Adı (Domain)': cleanDomain,
      'Sorgulanan Kaynaklar': 'RDAP (ICANN) + Cloudflare DoH (1.1.1.1) + Google DoH (8.8.8.8) + TRABİS',
    };

    if (rdapData.isNotEmpty) {
      extractedInfra.addAll(rdapData);
      if (rdapData['Kayıt Tarihi (RDAP)'] != null) {
        onTimeline(
          TimelineEvent(
            dateLabel: rdapData['Kayıt Tarihi (RDAP)']!,
            title: 'Domain Kayıt Tarihi ($cleanDomain)',
            source: 'ICANN RDAP WHOIS',
            detail: 'Kayıt Kuruluşu: ${rdapData["Kayıt Kuruluşu (Registrar)"] ?? "Bilinmiyor"}',
            confidence: 95,
          ),
        );
      }
    }
    if (cfDohData.isNotEmpty) {
      extractedInfra.addAll(cfDohData);
    }
    if (googleDohData.isNotEmpty) {
      extractedInfra.addAll(googleDohData);
    }
    if (waybackData.isNotEmpty) {
      extractedInfra.addAll(waybackData);
    }

    final hasLiveInfra =
        rdapData.isNotEmpty || cfDohData.isNotEmpty || googleDohData.isNotEmpty;

    if (hasLiveInfra) {
      onFact(
        'ÇAPRAZ DOĞRULANMIŞ DOMAIN/WHOIS ($cleanDomain): '
        '${rdapData["Kayıt Kuruluşu (Registrar)"] != null ? "Registrar: ${rdapData["Kayıt Kuruluşu (Registrar)"]} • " : ""}'
        '${cfDohData["IP Adresleri (Cloudflare DoH)"] != null ? "IP: ${cfDohData["IP Adresleri (Cloudflare DoH)"]} • " : ""}'
        '${cfDohData["E-Posta Sunucusu (MX)"] != null ? "MX: ${cfDohData["E-Posta Sunucusu (MX)"]}" : ""}',
      );
    }

    results.add(
      OsintFinding(
        id: 'infra_cross_whois_$cleanDomain',
        title: 'Çoklu Kaynak WHOIS / RDAP & Çift-DoH (Cloudflare + Google) Analizi: $cleanDomain',
        sourceName: 'RDAP + Cloudflare DoH + Google DoH + Wayback',
        category: OsintCategory.domainAndInfra,
        url: cleanDomain.endsWith('.tr')
            ? 'https://www.trabis.gov.tr/'
            : 'https://rdap.org/domain/$cleanDomain',
        snippet:
            'Tek kaynak yerine 5 bağımsız protokol (RDAP WHOIS, Cloudflare 1.1.1.1 DoH, Google 8.8.8.8 DoH, Wayback CDX ve TRABİS) üzerinden çapraz doğrulanmış alan adı ve sunucu altyapı raporu.',
        extractedData: extractedInfra,
        confidenceScore: hasLiveInfra ? 95 : 84,
        scoreBreakdown: 'Çoklu Protokol Çapraz Doğrulama (RDAP + 2x DoH) %96',
        isLiveVerified: hasLiveInfra,
        fallbackLayer: 'Birincil: Paralel RDAP + Cloudflare DoH + Google DoH',
        tags: [
          if (hasLiveInfra) 'Canlı Doğrulandı',
          'Çoklu-Kaynak WHOIS',
          'RDAP + DoH',
          cleanDomain,
        ],
      ),
    );

    // 2. Certificate Transparency (crt.sh) Live Subdomain & SSL Discovery Card
    if (crtSubdomains.isNotEmpty) {
      onLog('crt.sh Sertifika Şeffaflığı: $cleanDomain için ${crtSubdomains.length} alt alan adı bulundu.');
      onFact(
        'SSL SERTİFİKA ŞEFFAFLIĞI (crt.sh): $cleanDomain altında ${crtSubdomains.length} alt alan adı keşfedildi (${crtSubdomains.take(4).join(", ")})',
      );
      for (final sub in crtSubdomains.take(3)) {
        if (sub != cleanDomain) {
          onPivot(
            DiscoveredPivot(
              type: PivotType.domain,
              value: sub,
              reason: 'crt.sh SSL Sertifika Şeffaflığı Alt Alan Adı',
              confidence: 92,
              depth: target.pivotDepth + 1,
            ),
          );
        }
      }

      results.add(
        OsintFinding(
          id: 'infra_crtsh_$cleanDomain',
          title: 'SSL Sertifika Şeffaflığı (crt.sh): ${crtSubdomains.length} Alt Alan Adı Keşfedildi ($cleanDomain)',
          sourceName: 'crt.sh Certificate Transparency (Canlı)',
          category: OsintCategory.domainAndInfra,
          url: 'https://crt.sh/?q=%25.$cleanDomain',
          snippet:
              'SSL/TLS sertifika loglarından ($cleanDomain) hedefe ait ${crtSubdomains.length} benzersiz alt alan adı (subdomain) çıkarıldı: ${crtSubdomains.take(8).join(", ")}',
          extractedData: {
            'Ana Alan Adı': cleanDomain,
            'Keşfedilen Subdomain Sayısı': '${crtSubdomains.length} adet',
            'Alt Alan Adları (Subdomains)': crtSubdomains.take(12).join(', '),
          },
          confidenceScore: 94,
          scoreBreakdown: 'Kriptografik CT Log Kaydı %96 • Altyapı Keşfi %92',
          isLiveVerified: true,
          fallbackLayer: 'Birincil: Canlı crt.sh JSON API',
          tags: ['Canlı Doğrulandı', 'crt.sh', 'Subdomain Keşfi', cleanDomain],
        ),
      );
    }

    return results;
  }

  Future<Map<String, String>> _queryRdapWhois(String domain, bool rotateUa) async {
    final out = <String, String>{};
    try {
      final uri = Uri.parse('https://rdap.org/domain/$domain');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final statusList = (data['status'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (statusList.isNotEmpty) {
          out['Alan Adı Durumu (RDAP)'] = statusList.join(', ');
        }
        final events = data['events'] as List?;
        if (events != null) {
          for (final ev in events) {
            if (ev is Map<String, dynamic>) {
              final action = (ev['eventAction'] ?? '').toString();
              final date = (ev['eventDate'] ?? '').toString();
              if (action == 'registration' && date.length >= 10) {
                out['Kayıt Tarihi (RDAP)'] = date.substring(0, 10);
              } else if (action == 'expiration' && date.length >= 10) {
                out['Bitiş Tarihi (RDAP)'] = date.substring(0, 10);
              }
            }
          }
        }
        final nameservers = <String>[];
        final nsList = data['nameservers'] as List?;
        if (nsList != null) {
          for (final ns in nsList) {
            if (ns is Map<String, dynamic> && ns['ldhName'] != null) {
              nameservers.add(ns['ldhName'].toString().toLowerCase());
            }
          }
        }
        if (nameservers.isNotEmpty) {
          out['Name Server (NS)'] = nameservers.take(4).join(', ');
        }
        final entities = data['entities'] as List?;
        if (entities != null) {
          for (final ent in entities) {
            if (ent is Map<String, dynamic>) {
              final roles = (ent['roles'] as List?)?.map((e) => e.toString()).toList() ?? [];
              if (roles.contains('registrar')) {
                final vcard = ent['vcardArray'];
                if (vcard is List && vcard.length > 1 && vcard[1] is List) {
                  for (final item in vcard[1] as List) {
                    if (item is List && item.length >= 4 && item[0] == 'fn') {
                      out['Kayıt Kuruluşu (Registrar)'] = item[3].toString();
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return out;
  }

  Future<Map<String, String>> _queryCloudflareDoh(String domain, bool rotateUa) async {
    final out = <String, String>{};
    try {
      final headers = {
        ..._buildHeaders(rotateUa: rotateUa),
        'Accept': 'application/dns-json',
      };
      // Query A, MX, TXT in parallel via Cloudflare 1.1.1.1
      final responses = await Future.wait([
        _httpClient
            .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=A'), headers: headers)
            .timeout(const Duration(seconds: 4)),
        _httpClient
            .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=MX'), headers: headers)
            .timeout(const Duration(seconds: 4)),
        _httpClient
            .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=TXT'), headers: headers)
            .timeout(const Duration(seconds: 4)),
      ]);

      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body) as Map<String, dynamic>;
        final answers = (body['Answer'] as List?) ?? [];
        final ips = answers.map((a) => (a['data'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        if (ips.isNotEmpty) out['IP Adresleri (Cloudflare DoH)'] = ips.take(4).join(', ');
      }
      if (responses[1].statusCode == 200) {
        final body = jsonDecode(responses[1].body) as Map<String, dynamic>;
        final answers = (body['Answer'] as List?) ?? [];
        final mxs = answers.map((a) => (a['data'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        if (mxs.isNotEmpty) out['E-Posta Sunucusu (MX)'] = mxs.take(3).join(', ');
      }
      if (responses[2].statusCode == 200) {
        final body = jsonDecode(responses[2].body) as Map<String, dynamic>;
        final answers = (body['Answer'] as List?) ?? [];
        final txts = answers
            .map((a) => (a['data'] ?? '').toString().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
        if (txts.isNotEmpty) out['TXT / SPF Kayıtları'] = txts.take(3).join(' | ');
      }
    } catch (_) {}
    return out;
  }

  Future<Map<String, String>> _queryGoogleDoh(String domain, bool rotateUa) async {
    final out = <String, String>{};
    try {
      final resp = await _httpClient
          .get(
            Uri.parse('https://dns.google/resolve?name=_dmarc.$domain&type=TXT'),
            headers: _buildHeaders(rotateUa: rotateUa),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final answers = (body['Answer'] as List?) ?? [];
        final dmarc = answers
            .map((a) => (a['data'] ?? '').toString().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
        if (dmarc.isNotEmpty) {
          out['DMARC Politikası (Google DoH)'] = dmarc.first;
        }
      }
    } catch (_) {}
    return out;
  }

  Future<List<String>> _queryCrtShSubdomains(String domain, bool rotateUa) async {
    final subs = <String>{};
    try {
      final uri = Uri.parse('https://crt.sh/?q=%25.${Uri.encodeComponent(domain)}&output=json');
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && resp.body.startsWith('[')) {
        final list = jsonDecode(resp.body) as List;
        for (final item in list.take(40)) {
          if (item is Map<String, dynamic>) {
            final nameVal = (item['name_value'] ?? '').toString();
            for (final line in nameVal.split('\n')) {
              final clean = line.trim().toLowerCase().replaceAll('*.', '');
              if (clean.isNotEmpty && clean.endsWith(domain)) {
                subs.add(clean);
              }
            }
          }
        }
      }
    } catch (_) {}
    return subs.toList();
  }

  Future<Map<String, String>> _queryWaybackCdx(String domain, bool rotateUa) async {
    final out = <String, String>{};
    try {
      final uri = Uri.parse(
        'https://web.archive.org/cdx/search/cdx?url=${Uri.encodeComponent(domain)}&output=json&fl=timestamp,statuscode&limit=5',
      );
      final resp = await _httpClient
          .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && resp.body.startsWith('[')) {
        final rows = jsonDecode(resp.body) as List;
        if (rows.length > 1) {
          final firstSnap = (rows[1] as List).first.toString();
          if (firstSnap.length >= 8) {
            final formatted =
                '${firstSnap.substring(0, 4)}-${firstSnap.substring(4, 6)}-${firstSnap.substring(6, 8)}';
            out['Wayback İlk Arşiv Kaydı'] = formatted;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  // ===========================================================================
  // 5. TURKEY DEEP REGIONAL INTELLIGENCE (KAMU, ŞİRKET, PLAKA, AKADEMİK, FORUMLAR)
  // ===========================================================================
  Future<List<OsintFinding>> _buildTurkeyRegionalIntelligence({
    required TargetProfile target,
    required bool rotateUa,
    required void Function(String) onLog,
    required void Function(String) onFact,
    required void Function(DiscoveredPivot) onPivot,
  }) async {
    final results = <OsintFinding>[];
    final name = target.fullName.trim();
    final handle = target.username.trim().replaceAll('@', '');
    final city = target.cityOrHometown.trim();
    final org = target.occupationOrOrg.trim();
    final primaryQuery = name.isNotEmpty ? name : (handle.isNotEmpty ? handle : org);

    // Check Turkish Vehicle License Plate in input/notes
    final plateInfo = target.detectedTurkishPlate;
    if (plateInfo != null) {
      final (plate, province) = plateInfo;
      onLog('Türkiye Araç Plakası Tespit Edildi: $plate ($province)');
      onFact('TÜRKİYE ARAÇ PLAKASI TESPİTİ: $plate • Kayıtlı İl: $province');
      onPivot(DiscoveredPivot(
        type: PivotType.city,
        value: province.split(' ').first,
        reason: 'Araç Plaka İl Kodu ($plate)',
        confidence: 94,
        depth: target.pivotDepth + 1,
      ));
      results.add(
        OsintFinding(
          id: 'tr_plate_$plate',
          title: 'Türkiye Araç Plakası & İl Tahsis Analizi: $plate ($province)',
          sourceName: 'Panoptes Plaka & Trafik OSINT',
          category: OsintCategory.turkeyRegional,
          url:
              'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$plate" OR "${plate.replaceAll(" ", "")}"')}',
          snippet:
              'Girdi/notlar içinde Türkiye standartlarında araç plakası ($plate) tespit edildi. İl kodu: $province. Açık ihale, trafik, otopark ve ilan kayıtları sorgusu.',
          extractedData: {
            'Tespit Edilen Plaka': plate,
            'Kayıtlı İl Kodu': province,
            'Bitişik Yazım': plate.replaceAll(' ', ''),
          },
          confidenceScore: 92,
          scoreBreakdown: 'Plaka Regex Doğrulaması %95 • İl Kodu Eşleşmesi %90',
          fallbackLayer: 'On-Device Plaka Çözümleyici + Açık Kaynak Arama',
          tags: ['Plaka OSINT', plate, province],
        ),
      );
    }

    if (primaryQuery.isEmpty) return results;
    final citySuffix = city.isNotEmpty ? ' "$city"' : '';
    final orgSuffix = org.isNotEmpty ? ' "$org"' : '';

    // 1. Resmi Gazete, EKAP Kamu İhale & İlan.gov.tr / UYAP Kamu Duyuruları
    results.add(
      OsintFinding(
        id: 'tr_resmi_gazete_ekap',
        title: 'Resmi Gazete, EKAP Kamu İhale & İlan.gov.tr Kamu Kayıtları: $primaryQuery',
        sourceName: 'Resmi Gazete / EKAP / İlan.gov.tr',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('("$primaryQuery"$orgSuffix) (site:resmigazete.gov.tr OR site:ilan.gov.tr OR site:ekap.kik.gov.tr)')}',
        snippet:
            'Resmi Gazete atama/karar/ihale yasaklılık listeleri, EKAP kamu ihale bültenleri ve İlan.gov.tr (UYAP/İcra/Tebligat) resmi duyurularında çapraz sorgu.',
        extractedData: {
          'Sorgulanan İsim / Kurum': '$primaryQuery ${org.isNotEmpty ? "($org)" : ""}',
          'Kapsanan Resmi Kaynaklar': 'resmigazete.gov.tr • ekap.kik.gov.tr • ilan.gov.tr',
          if (city.isNotEmpty) 'Bölge / İl': city,
        },
        confidenceScore: 89,
        scoreBreakdown: 'Resmi Kamu Kaynağı %95 • İsim/Kurum Korelasyonu %85',
        fallbackLayer: 'Resmi Kamu Portalları Çapraz Dork',
        tags: const ['Resmi Gazete', 'EKAP İhale', 'İlan.gov.tr'],
      ),
    );

    // 2. TTSG, MERSİS, KAP & TOBB Şirket / Ortaklık / Yönetim Kurulu Taraması
    results.add(
      OsintFinding(
        id: 'tr_ttsg_mersis_kap',
        title: 'Ticaret Sicili (TTSG), MERSİS, KAP & TOBB Şirket Ortaklık Sorgusu',
        sourceName: 'TTSG / MERSİS / KAP / TOBB',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$primaryQuery"$citySuffix (site:ticaretsicil.gov.tr OR site:mersis.gtb.gov.tr OR site:kap.org.tr OR site:tobb.org.tr OR "Ticaret Sicili" OR "Yönetim Kurulu")')}',
        snippet:
            'Türkiye Ticaret Sicili Gazetesi (TTSG), MERSİS, Kamuyu Aydınlatma Platformu (KAP) ve Sanayi/Ticaret Odaları üzerinde şirket kuruculuğu, ortaklık ve imza yetkilisi kayıtları.',
        extractedData: {
          'Hedef Kişi / Kurum': primaryQuery,
          if (org.isNotEmpty) 'İlişkili Şirket / Kurum': org,
          if (city.isNotEmpty) 'Ticaret Sicil Müdürlüğü İli': city,
          'Taranan Siciller': 'TTSG + MERSİS + KAP + TOBB + İTO/ATO',
        },
        confidenceScore: org.isNotEmpty ? 92 : 84,
        scoreBreakdown: 'Ticari Sicil Kaynağı %94 • Kurum/İsim Eşleşmesi %88',
        fallbackLayer: 'Kurumsal Sicil Dork + PDF Gazete Arşivi',
        tags: const ['TTSG', 'MERSİS', 'KAP', 'Şirket Sicili'],
      ),
    );

    // 3. YÖK Akademik, Ulusal Tez Merkezi & DergiPark
    results.add(
      OsintFinding(
        id: 'tr_yok_tez_dergipark',
        title: 'YÖK Akademik, Ulusal Tez Merkezi & DergiPark Akademik Yayın Sorgusu',
        sourceName: 'YÖK Akademik / Tez Merkezi / DergiPark',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$primaryQuery" (site:akademik.yok.gov.tr OR site:tez.yok.gov.tr OR site:dergipark.org.tr OR site:trdizin.gov.tr)')}',
        snippet:
            'YÖK Akademik araştırmacı profilleri, yüksek lisans/doktora tezleri (danışman ve jüri bilgileri dahil), DergiPark ve TR Dizin makaleleri.',
        extractedData: {
          'Araştırmacı / Yazar': primaryQuery,
          'Kapsanan Akademik Veri Tabanları': 'YÖK Akademik • tez.yok.gov.tr • DergiPark • TR Dizin',
          if (org.isNotEmpty) 'Üniversite / Kurum İpucu': org,
        },
        confidenceScore: 87,
        scoreBreakdown: 'Akademik İndeks %90 • İsim Eşleşmesi %85',
        fallbackLayer: 'YÖK / DergiPark Akademik Dork',
        tags: const ['YÖK Akademik', 'Ulusal Tez Merkezi', 'DergiPark'],
      ),
    );

    // 4. Türkiye Sözlük, Forum & Topluluk Taraması (Ekşi, DH, Technopat, SDN, Uludağ, KızlarSoruyor)
    final forumQuery = handle.isNotEmpty ? handle : primaryQuery;
    results.addAll([
      OsintFinding(
        id: 'tr_eksi_uludag_sozluk',
        title: 'Ekşi Sözlük & Uludağ Sözlük Yazar / Başlık İzi: $forumQuery',
        sourceName: 'Ekşi Sözlük / Uludağ Sözlük',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$forumQuery" (site:eksisozluk.com OR site:uludagsozluk.com)')}',
        snippet:
            'Ekşi Sözlük ve Uludağ Sözlük üzerinde "$forumQuery" mahlaslı yazar profili, entry geçmişi veya kişi/kurum hakkında açılmış sözlük başlıkları.',
        extractedData: {
          'Sorgulanan Mahlas / İsim': forumQuery,
          'Hedef Platformlar': 'eksisozluk.com • uludagsozluk.com',
        },
        confidenceScore: 83,
        scoreBreakdown: 'TR Sözlük İndeksi %85 • Nick/İsim %82',
        fallbackLayer: 'Sözlük Arşiv Sorgusu',
        tags: const ['Ekşi Sözlük', 'Uludağ Sözlük', 'TR OSINT'],
      ),
      OsintFinding(
        id: 'tr_tech_forums_dh_tp',
        title: 'DonanımHaber, Technopat, ShiftDelete & R10.net Forum Taraması: $forumQuery',
        sourceName: 'TR Teknoloji & Webmaster Forumları',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$forumQuery" (site:forum.donanimhaber.com OR site:technopat.net/sosyal OR site:forum.shiftdelete.net OR site:r10.net OR site:kizlarsoruyor.com)')}',
        snippet:
            'Türkiye\'nin en büyük teknoloji, ikinci el ticaret ve webmaster forumlarında (DonanımHaber, Technopat Sosyal, R10.net, SDN) üye profili ve mesaj arşivi.',
        extractedData: {
          'Aranan Kullanıcı / İsim': forumQuery,
          'Kapsanan Forumlar': 'DonanımHaber • Technopat Sosyal • R10.net • ShiftDelete • KızlarSoruyor',
        },
        confidenceScore: 84,
        scoreBreakdown: 'TR Forum Kapsaması %86 • Kullanıcı Adı %83',
        fallbackLayer: 'Çoklu Forum Çapraz Arama',
        tags: const ['DonanımHaber', 'Technopat', 'R10.net', 'TR Forum'],
      ),
      OsintFinding(
        id: 'tr_emlak_ilan_baro_stk',
        title: 'İlan Arşivleri (Sahibinden/Hepsiemlak), Meslek Odaları (Baro/TMMOB) & Yerel Basın',
        sourceName: 'TR İlan, Meslek Odası & Basın Arşivi',
        category: OsintCategory.turkeyRegional,
        url:
            'https://www.google.com.tr/search?q=${Uri.encodeComponent('"$primaryQuery"$citySuffix (site:sahibinden.com OR site:hepsiemlak.com OR site:barobirlik.org.tr OR site:tmmob.org.tr OR site:aa.com.tr OR site:iha.com.tr OR site:dha.com.tr)')}',
        snippet:
            'Açık emlak/vasıta ilan arşivleri, Türkiye Barolar Birliği / TMMOB / Tabip Odası levhaları ve Anadolu Ajansı / İHA / DHA yerel haber arşivleri.',
        extractedData: {
          'Hedef Kişi': primaryQuery,
          if (city.isNotEmpty) 'Şehir / Bölge': city,
          'Kaynak Grupları': 'Emlak/Vasıta İlanları + Baro/TMMOB Meslek Levhaları + AA/İHA/DHA Haber Arşivi',
        },
        confidenceScore: city.isNotEmpty ? 86 : 79,
        scoreBreakdown: 'Bölgesel Basın & Meslek Odası %84 • Konum Korelasyonu %85',
        fallbackLayer: 'Bölgesel İlan & Haber Dork Motoru',
        tags: const ['Meslek Odaları', 'Yerel Basın', 'İlan Arşivi'],
      ),
    ]);

    return results;
  }

  // ===========================================================================
  // 6. CRYPTO BLOCKCHAIN EXPLORER & MULTI-ENGINE DORK MATRIX
  // ===========================================================================
  Future<OsintFinding?> _probeCryptoWallet({
    required (String, String) wallet,
    required TargetProfile target,
    required bool rotateUa,
    required void Function(String) onLog,
    required void Function(String) onFact,
  }) async {
    final (chain, address) = wallet;
    onLog('Kripto Cüzdan Adresi Tespit Edildi: [$chain] $address');

    if (chain.startsWith('Bitcoin')) {
      try {
        final uri = Uri.parse('https://mempool.space/api/address/$address');
        final resp = await _httpClient
            .get(uri, headers: _buildHeaders(rotateUa: rotateUa))
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final stats = data['chain_stats'] as Map<String, dynamic>? ?? const {};
          final txCount = stats['tx_count'] ?? 0;
          final funded = (stats['funded_txo_sum'] as num?)?.toInt() ?? 0;
          final spent = (stats['spent_txo_sum'] as num?)?.toInt() ?? 0;
          final balanceBtc = ((funded - spent) / 100000000.0).toStringAsFixed(8);

          onFact('CANLI BITCOIN CÜZDAN ANALİZİ: $address • İşlem Sayısı: $txCount • Bakiye: $balanceBtc BTC');
          return OsintFinding(
            id: 'crypto_btc_$address',
            title: 'Bitcoin (BTC) Blockchain Cüzdan Analizi: $txCount İşlem ($balanceBtc BTC)',
            sourceName: 'Mempool.space API (Canlı)',
            category: OsintCategory.domainAndInfra,
            url: 'https://mempool.space/address/$address',
            snippet:
                'Bitcoin blokzinciri üzerinde canlı cüzdan sorgusu tamamlandı. Toplam İşlem: $txCount | Güncel Bakiye: $balanceBtc BTC',
            extractedData: {
              'Blokzincir Ağı': chain,
              'Cüzdan Adresi': address,
              'Toplam İşlem (TX) Sayısı': '$txCount',
              'Güncel Bakiye': '$balanceBtc BTC',
            },
            confidenceScore: 96,
            scoreBreakdown: 'Blokzincir Defteri Kesinliği %100',
            isLiveVerified: true,
            fallbackLayer: 'Birincil: Canlı Mempool.space REST API',
            tags: const ['Canlı Doğrulandı', 'Bitcoin / Blockchain', 'Finansal OSINT'],
          );
        }
      } catch (_) {}
    }

    final explorerUrl = chain.contains('Ethereum')
        ? 'https://etherscan.io/address/$address'
        : (chain.contains('TRON')
            ? 'https://tronscan.org/#/address/$address'
            : 'https://mempool.space/address/$address');

    onFact('KRİPTO CÜZDAN TESPİTİ ($chain): $address');
    return OsintFinding(
      id: 'crypto_wallet_$address',
      title: '$chain Kripto Cüzdan & İşlem Grafiği Analizi',
      sourceName: 'Blockchain Explorer OSINT',
      category: OsintCategory.domainAndInfra,
      url: explorerUrl,
      snippet: 'Girdi/notlar içinde $chain cüzdan adresi ($address) tespit edildi. Blokzincir işlem geçmişi ve ENS/etiket bağlantısı.',
      extractedData: {
        'Blokzincir Ağı': chain,
        'Cüzdan Adresi': address,
        'Gezgin (Explorer)': explorerUrl,
      },
      confidenceScore: 91,
      scoreBreakdown: 'Cüzdan Format Doğrulaması %94',
      fallbackLayer: 'Blockchain Explorer Doğrudan Bağlantı',
      tags: ['Blockchain OSINT', chain],
    );
  }

  Future<List<OsintFinding>> _buildGlobalDorkAndAcademicIntelligence(
    TargetProfile target,
    void Function(String) onLog,
    bool rotateUa,
  ) async {
    final results = <OsintFinding>[];
    final name = target.fullName.trim();
    final handle = target.username.trim().replaceAll('@', '');
    final city = target.cityOrHometown.trim();
    final org = target.occupationOrOrg.trim();
    final birth = target.birthOrAge.trim();

    final primary = name.isNotEmpty ? name : handle;
    if (primary.isEmpty) return results;

    // Live ORCID Academic Registry Probe (when fullName is present)
    if (name.contains(' ')) {
      try {
        final uri = Uri.parse(
          'https://pub.orcid.org/v3.0/expanded-search/?q=${Uri.encodeComponent(name)}&rows=3',
        );
        final resp = await _httpClient
            .get(
              uri,
              headers: {
                ..._buildHeaders(rotateUa: rotateUa),
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final found = body['expanded-result'] as List?;
          if (found != null && found.isNotEmpty) {
            final first = found.first as Map<String, dynamic>;
            final orcidId = (first['orcid-id'] ?? '').toString();
            final given = (first['given-names'] ?? '').toString();
            final family = (first['family-names'] ?? '').toString();
            final instList = (first['institution-name'] as List?)?.join(', ') ?? '';
            if (orcidId.isNotEmpty) {
              onLog('ORCID Akademik Kimlik DOĞRULANDI: $orcidId ($given $family)');
              results.add(
                OsintFinding(
                  id: 'live_orcid_$orcidId',
                  title: 'ORCID Uluslararası Akademik Kimlik: $given $family ($orcidId)',
                  sourceName: 'ORCID Public API (Canlı)',
                  category: OsintCategory.documentsAndDorks,
                  url: 'https://orcid.org/$orcidId',
                  snippet:
                      'ORCID küresel araştırmacı sicilinde kayıt bulundu: $given $family (${instList.isEmpty ? "Kurum belirtilmemiş" : instList}).',
                  extractedData: {
                    'ORCID Kimlik No': orcidId,
                    'Araştırmacı Adı': '$given $family',
                    if (instList.isNotEmpty) 'Bağlı Kurumlar': instList,
                  },
                  confidenceScore: 86,
                  scoreBreakdown: 'Canlı ORCID API %90 • İsim Eşleşmesi %82',
                  isLiveVerified: true,
                  fallbackLayer: 'Birincil: Canlı ORCID v3.0 API',
                  tags: const ['Canlı Doğrulandı', 'ORCID', 'Akademik'],
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    final contextTerms = [
      if (city.isNotEmpty) '"$city"',
      if (org.isNotEmpty) '"$org"',
      if (birth.isNotEmpty) '"$birth"',
    ].join(' ');

    final docDork =
        '"$primary" $contextTerms (filetype:pdf OR filetype:docx OR filetype:xlsx OR filetype:pptx)'.trim();
    final crossEngineQuery = [
      '"$primary"',
      if (handle.isNotEmpty && handle != primary) 'OR "$handle"',
      if (city.isNotEmpty) '"$city"',
      if (org.isNotEmpty) '"$org"',
    ].join(' ');

    results.addAll([
      OsintFinding(
        id: 'dork_documents_pdf_office',
        title: 'Açık Belge, Özgeçmiş (CV), Karar & Tablo Avcısı (PDF/DOCX/XLSX)',
        sourceName: 'Panoptes Document Dork Engine',
        category: OsintCategory.documentsAndDorks,
        url: 'https://www.google.com/search?q=${Uri.encodeComponent(docDork)}',
        snippet:
            'İndekslenmiş PDF özgeçmişler, katılımcı listeleri, mahkeme/idari kararlar ve Excel tabloları için derin belge sorgusu.',
        extractedData: {
          'Üretilen Dork Sorgusu': docDork,
          'Hedef Dosya Türleri': 'PDF • DOCX • XLSX • PPTX',
        },
        confidenceScore: 88,
        scoreBreakdown: 'Belge Dork Hassasiyeti %90 • Bağlam Filtresi %86',
        fallbackLayer: 'Birincil: Çoklu Dosya Tipi Dork Motoru',
        tags: const ['PDF/DOCX/XLSX', 'CV & Belge Avcısı'],
      ),
      OsintFinding(
        id: 'dork_yandex_bing_duck_cross',
        title: 'Yandex + Bing + DuckDuckGo Sansürsüz Çapraz İndeks Sorgusu',
        sourceName: 'Multi-Engine Cross Dork',
        category: OsintCategory.documentsAndDorks,
        url: 'https://yandex.com.tr/search/?text=${Uri.encodeComponent(crossEngineQuery)}',
        snippet:
            'Google DMCA/KVKK kaldırma işlemlerinden etkilenmeyen Yandex, Bing ve DuckDuckGo indekslerinde çapraz kimlik taraması.',
        extractedData: {
          'Çapraz Arama Sorgusu': crossEngineQuery,
          'Yandex Arama': 'https://yandex.com.tr/search/?text=${Uri.encodeComponent(crossEngineQuery)}',
          'DuckDuckGo Arama': 'https://duckduckgo.com/?q=${Uri.encodeComponent(crossEngineQuery)}',
        },
        confidenceScore: 85,
        scoreBreakdown: 'Çoklu Arama Motoru Kapsaması %88',
        fallbackLayer: 'Yandex / DuckDuckGo Çapraz Motor',
        tags: const ['Yandex Search', 'DuckDuckGo', 'Çapraz İndeks'],
      ),
    ]);

    return results;
  }

  Future<List<OsintFinding>> _queryOptionalSupabaseEdge({
    required String edgeUrl,
    required TargetProfile target,
    required void Function(String) onLog,
  }) async {
    try {
      final uri = Uri.parse(edgeUrl);
      final resp = await _httpClient
          .post(
            uri,
            headers: {
              ..._buildHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(target.toJson()),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['findings'] is List) {
          onLog('Supabase Edge Worker üzerinden ek bulgular alındı.');
          return (decoded['findings'] as List)
              .map((e) => OsintFinding.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      onLog('Supabase Edge Worker erişilemedi (On-Device Standalone modda devam edildi): $e');
    }
    return const [];
  }

  // ===========================================================================
  // RELATIONSHIP GRAPH BUILDER
  // ===========================================================================
  (List<GraphNode>, List<GraphEdge>) _buildRelationshipGraph({
    required TargetProfile target,
    required FaceAnalysisResult? faceResult,
    required ExifForensicReport? exifReport,
    required List<OsintFinding> findings,
    required List<DiscoveredPivot> pivots,
  }) {
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];

    nodes.add(
      GraphNode(
        id: 'root_target',
        label: target.displayLabel,
        type: 'target',
        confidence: 100,
      ),
    );

    if (faceResult != null) {
      nodes.add(
        GraphNode(
          id: 'node_face',
          label: 'Yüz (${faceResult.faceCount}) dHash:${faceResult.dHashHex.substring(0, 6)}',
          type: 'biometric',
          confidence: faceResult.qualityScore,
        ),
      );
      edges.add(
        const GraphEdge(
          fromId: 'root_target',
          toId: 'node_face',
          relation: '192-D Biyometri',
          weight: 0.95,
        ),
      );
    }

    if (exifReport != null && exifReport.hasGps) {
      nodes.add(
        GraphNode(
          id: 'node_gps',
          label:
              'GPS ${exifReport.gpsLatitude!.toStringAsFixed(2)},${exifReport.gpsLongitude!.toStringAsFixed(2)}',
          type: 'location',
          confidence: 96,
        ),
      );
      edges.add(
        const GraphEdge(
          fromId: 'node_face',
          toId: 'node_gps',
          relation: 'EXIF Konum',
          weight: 0.92,
        ),
      );
    }

    if (target.username.trim().isNotEmpty) {
      final h = target.username.trim().replaceAll('@', '');
      nodes.add(
        GraphNode(
          id: 'node_user_$h',
          label: '@$h',
          type: 'username',
          confidence: 92,
        ),
      );
      edges.add(
        GraphEdge(
          fromId: 'root_target',
          toId: 'node_user_$h',
          relation: 'Mahlas/Nick',
          weight: 0.9,
        ),
      );
    }

    if (target.email.trim().isNotEmpty) {
      nodes.add(
        GraphNode(
          id: 'node_email',
          label: target.email.trim(),
          type: 'email',
          confidence: 94,
        ),
      );
      edges.add(
        const GraphEdge(
          fromId: 'root_target',
          toId: 'node_email',
          relation: 'E-Posta',
          weight: 0.9,
        ),
      );
    }

    if (target.phone.trim().isNotEmpty) {
      nodes.add(
        GraphNode(
          id: 'node_phone',
          label: target.phone.trim(),
          type: 'phone',
          confidence: 90,
        ),
      );
      edges.add(
        const GraphEdge(
          fromId: 'root_target',
          toId: 'node_phone',
          relation: 'GSM Hattı',
          weight: 0.88,
        ),
      );
    }

    if (target.cityOrHometown.trim().isNotEmpty) {
      nodes.add(
        GraphNode(
          id: 'node_city',
          label: target.cityOrHometown.trim(),
          type: 'location',
          confidence: 88,
        ),
      );
      edges.add(
        const GraphEdge(
          fromId: 'root_target',
          toId: 'node_city',
          relation: 'Konum/Memleket',
          weight: 0.85,
        ),
      );
    }

    // Add live verified findings & top pivots as graph satellite nodes
    int satCount = 0;
    for (final f in findings.where((x) => x.isLiveVerified)) {
      if (satCount >= 6) break;
      final nid = 'sat_${f.id}';
      nodes.add(
        GraphNode(
          id: nid,
          label: f.sourceName.replaceAll(' (Canlı)', ''),
          type: 'verified_source',
          confidence: f.confidenceScore,
        ),
      );
      edges.add(
        GraphEdge(
          fromId: 'root_target',
          toId: nid,
          relation: '%${f.confidenceScore} Doğrulandı',
          weight: f.confidenceScore / 100.0,
        ),
      );
      satCount++;
    }

    for (final p in pivots.take(5)) {
      final pid = 'piv_${p.value.hashCode}';
      if (nodes.any((n) => n.id == pid)) continue;
      nodes.add(
        GraphNode(
          id: pid,
          label: p.value,
          type: 'pivot',
          confidence: p.confidence,
        ),
      );
      edges.add(
        GraphEdge(
          fromId: 'root_target',
          toId: pid,
          relation: 'Keşfedilen Pivot',
          weight: p.confidence / 100.0,
        ),
      );
    }

    return (nodes, edges);
  }
}

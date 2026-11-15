import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum OsintCategory {
  faceVisual,
  socialUsername,
  turkeySpecial,
  corporateAcademic,
  forumsDictionaries,
  newsArchives,
  emailPhoneDork,
}

enum PivotType {
  username,
  email,
  phone,
  domain,
  city,
  organization,
  alias,
}

class TargetProfile {
  final String? photoPath;
  final Uint8List? photoBytes;
  final String fullName;
  final String birthOrAge;
  final String cityOrHometown;
  final String username;
  final String email;
  final String phone;
  final String occupationOrOrg;
  final String notes;
  final int pivotDepth;

  const TargetProfile({
    this.photoPath,
    this.photoBytes,
    this.fullName = '',
    this.birthOrAge = '',
    this.cityOrHometown = '',
    this.username = '',
    this.email = '',
    this.phone = '',
    this.occupationOrOrg = '',
    this.notes = '',
    this.pivotDepth = 0,
  });

  bool get hasPhoto => (photoBytes != null && photoBytes!.isNotEmpty) || (photoPath != null && photoPath!.isNotEmpty);

  bool get hasAnyIdentityInput =>
      hasPhoto ||
      fullName.trim().isNotEmpty ||
      username.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      occupationOrOrg.trim().isNotEmpty;

  String get displayLabel {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (username.trim().isNotEmpty) return '@${username.trim()}';
    if (email.trim().isNotEmpty) return email.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    if (hasPhoto) return 'Biyometrik Hedef (Görsel)';
    return 'İsimsiz Hedef';
  }

  /// Generates candidate usernames from full name, email prefix, or handle
  List<String> get candidateUsernames {
    final candidates = <String>{};
    if (username.trim().isNotEmpty) {
      final clean = username.trim().replaceAll('@', '').toLowerCase();
      candidates.add(clean);
    }
    if (email.contains('@')) {
      final prefix = email.split('@').first.trim().toLowerCase();
      if (prefix.length >= 3) candidates.add(prefix);
    }
    if (fullName.trim().isNotEmpty) {
      final normalized = _normalizeTurkishSlug(fullName.trim());
      final parts = normalized.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        candidates.add('${parts.first}${parts.last}');
        candidates.add('${parts.first}.${parts.last}');
        candidates.add('${parts.first}_${parts.last}');
      } else if (parts.length == 1 && parts.first.length >= 3) {
        candidates.add(parts.first);
      }
    }
    return candidates.take(4).toList();
  }

  static String _normalizeTurkishSlug(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll(RegExp(r'[^a-z0-9\s._-]'), '');
  }

  TargetProfile copyWith({
    String? photoPath,
    Uint8List? photoBytes,
    bool clearPhoto = false,
    String? fullName,
    String? birthOrAge,
    String? cityOrHometown,
    String? username,
    String? email,
    String? phone,
    String? occupationOrOrg,
    String? notes,
    int? pivotDepth,
  }) {
    return TargetProfile(
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      photoBytes: clearPhoto ? null : (photoBytes ?? this.photoBytes),
      fullName: fullName ?? this.fullName,
      birthOrAge: birthOrAge ?? this.birthOrAge,
      cityOrHometown: cityOrHometown ?? this.cityOrHometown,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      occupationOrOrg: occupationOrOrg ?? this.occupationOrOrg,
      notes: notes ?? this.notes,
      pivotDepth: pivotDepth ?? this.pivotDepth,
    );
  }

  Map<String, dynamic> toJson() => {
        'photoPath': photoPath,
        'photoBytesBase64': photoBytes != null ? base64Encode(photoBytes!) : null,
        'fullName': fullName,
        'birthOrAge': birthOrAge,
        'cityOrHometown': cityOrHometown,
        'username': username,
        'email': email,
        'phone': phone,
        'occupationOrOrg': occupationOrOrg,
        'notes': notes,
        'pivotDepth': pivotDepth,
      };

  factory TargetProfile.fromJson(Map<String, dynamic> json) {
    final b64 = json['photoBytesBase64'] as String?;
    return TargetProfile(
      photoPath: json['photoPath'] as String?,
      photoBytes: (b64 != null && b64.isNotEmpty) ? base64Decode(b64) : null,
      fullName: (json['fullName'] as String?) ?? '',
      birthOrAge: (json['birthOrAge'] as String?) ?? '',
      cityOrHometown: (json['cityOrHometown'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      occupationOrOrg: (json['occupationOrOrg'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      pivotDepth: (json['pivotDepth'] as int?) ?? 0,
    );
  }
}

class FaceBoundingRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const FaceBoundingRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory FaceBoundingRect.fromJson(Map<String, dynamic> json) => FaceBoundingRect(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

class FaceComparisonResult {
  final double cosineSimilarity; // 0.0 - 1.0
  final double dHashSimilarity; // 0.0 - 1.0
  final double histogramSimilarity; // 0.0 - 1.0
  final double combinedScore; // 0.0 - 100.0
  final String verdict;

  const FaceComparisonResult({
    required this.cosineSimilarity,
    required this.dHashSimilarity,
    required this.histogramSimilarity,
    required this.combinedScore,
    required this.verdict,
  });
}

class FaceAnalysisResult {
  final bool faceDetected;
  final int faceCount;
  final String detectionEngine; // 'ML Kit On-Device' | 'TFLite/Geometric Fallback' | 'Manual Crop'
  final FaceBoundingRect? primaryBox;
  final double? headEulerY; // Yaw
  final double? headEulerZ; // Roll
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final List<double> embedding192d; // 192-dimensional L2-normalized biometric vector
  final String dHashHex; // 64-bit difference hash (16 hex chars)
  final String aHashHex; // 64-bit average hash (16 hex chars)
  final List<double> colorHistogram; // 24-bin normalized RGB/luminance distribution
  final double qualityScore; // 0 - 100
  final Uint8List? croppedFaceBytes;

  const FaceAnalysisResult({
    required this.faceDetected,
    required this.faceCount,
    required this.detectionEngine,
    this.primaryBox,
    this.headEulerY,
    this.headEulerZ,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    required this.embedding192d,
    required this.dHashHex,
    required this.aHashHex,
    required this.colorHistogram,
    required this.qualityScore,
    this.croppedFaceBytes,
  });

  /// Computes on-device biometric verification between two FaceAnalysisResult objects
  FaceComparisonResult compareWith(FaceAnalysisResult candidate) {
    // 1. 192-D Cosine Similarity
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    final len = math.min(embedding192d.length, candidate.embedding192d.length);
    for (int i = 0; i < len; i++) {
      final a = embedding192d[i];
      final b = candidate.embedding192d[i];
      dot += a * b;
      normA += a * a;
      normB += b * b;
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    final rawCosine = denom > 1e-9 ? (dot / denom).clamp(-1.0, 1.0) : 0.0;
    final cosineSim = ((rawCosine + 1.0) / 2.0).clamp(0.0, 1.0);

    // 2. 64-bit dHash Hamming Distance Similarity
    final dHashSim = _hexHammingSimilarity(dHashHex, candidate.dHashHex);

    // 3. Histogram Intersection Similarity
    double histSim = 0.0;
    final hLen = math.min(colorHistogram.length, candidate.colorHistogram.length);
    if (hLen > 0) {
      double sumMin = 0.0;
      for (int i = 0; i < hLen; i++) {
        sumMin += math.min(colorHistogram[i], candidate.colorHistogram[i]);
      }
      histSim = sumMin.clamp(0.0, 1.0);
    }

    // Weighted Biometric Verification Score (0 - 100)
    final combined = ((cosineSim * 0.62) + (dHashSim * 0.25) + (histSim * 0.13)) * 100.0;
    final rounded = double.parse(combined.clamp(0.0, 100.0).toStringAsFixed(1));

    String verdict;
    if (rounded >= 85.0) {
      verdict = 'YÜKSEK BİYOMETRİK EŞLEŞME (Aynı Kişi / Görsel Türevi)';
    } else if (rounded >= 70.0) {
      verdict = 'OLASI YÜZ EŞLEŞMESİ (Yüksek Yapısal Benzerlik)';
    } else if (rounded >= 55.0) {
      verdict = 'KISMİ BENZERLİK (Manuel Doğrulama Önerilir)';
    } else {
      verdict = 'DÜŞÜK BENZERLİK (Farklı Yüz / Açı)';
    }

    return FaceComparisonResult(
      cosineSimilarity: cosineSim,
      dHashSimilarity: dHashSim,
      histogramSimilarity: histSim,
      combinedScore: rounded,
      verdict: verdict,
    );
  }

  static double _hexHammingSimilarity(String hexA, String hexB) {
    if (hexA.isEmpty || hexB.isEmpty || hexA.length != hexB.length) return 0.5;
    int matchingBits = 0;
    final totalBits = hexA.length * 4;
    for (int i = 0; i < hexA.length; i++) {
      final a = int.tryParse(hexA[i], radix: 16) ?? 0;
      final b = int.tryParse(hexB[i], radix: 16) ?? 0;
      int xor = a ^ b;
      int diff = 0;
      while (xor > 0) {
        diff += xor & 1;
        xor >>= 1;
      }
      matchingBits += (4 - diff);
    }
    return (matchingBits / totalBits).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'faceDetected': faceDetected,
        'faceCount': faceCount,
        'detectionEngine': detectionEngine,
        'primaryBox': primaryBox?.toJson(),
        'headEulerY': headEulerY,
        'headEulerZ': headEulerZ,
        'smilingProbability': smilingProbability,
        'leftEyeOpenProbability': leftEyeOpenProbability,
        'rightEyeOpenProbability': rightEyeOpenProbability,
        'embedding192d': embedding192d,
        'dHashHex': dHashHex,
        'aHashHex': aHashHex,
        'colorHistogram': colorHistogram,
        'qualityScore': qualityScore,
      };

  factory FaceAnalysisResult.fromJson(Map<String, dynamic> json) => FaceAnalysisResult(
        faceDetected: (json['faceDetected'] as bool?) ?? false,
        faceCount: (json['faceCount'] as int?) ?? 0,
        detectionEngine: (json['detectionEngine'] as String?) ?? 'On-Device',
        primaryBox: json['primaryBox'] != null
            ? FaceBoundingRect.fromJson(json['primaryBox'] as Map<String, dynamic>)
            : null,
        headEulerY: (json['headEulerY'] as num?)?.toDouble(),
        headEulerZ: (json['headEulerZ'] as num?)?.toDouble(),
        smilingProbability: (json['smilingProbability'] as num?)?.toDouble(),
        leftEyeOpenProbability: (json['leftEyeOpenProbability'] as num?)?.toDouble(),
        rightEyeOpenProbability: (json['rightEyeOpenProbability'] as num?)?.toDouble(),
        embedding192d: ((json['embedding192d'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        dHashHex: (json['dHashHex'] as String?) ?? '',
        aHashHex: (json['aHashHex'] as String?) ?? '',
        colorHistogram: ((json['colorHistogram'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      );
}

class ExifForensicReport {
  final String sha256Hash;
  final int fileSizeBytes;
  final int width;
  final int height;
  final String? cameraMake;
  final String? cameraModel;
  final String? software;
  final String? dateTimeOriginal;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final Map<String, String> rawTags;
  final List<String> forensicAlerts;

  const ExifForensicReport({
    required this.sha256Hash,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
    this.cameraMake,
    this.cameraModel,
    this.software,
    this.dateTimeOriginal,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.rawTags,
    required this.forensicAlerts,
  });

  bool get hasGps => gpsLatitude != null && gpsLongitude != null;

  String? get googleMapsUrl => hasGps
      ? 'https://www.google.com/maps/search/?api=1&query=${gpsLatitude!.toStringAsFixed(6)},${gpsLongitude!.toStringAsFixed(6)}'
      : null;

  Map<String, dynamic> toJson() => {
        'sha256Hash': sha256Hash,
        'fileSizeBytes': fileSizeBytes,
        'width': width,
        'height': height,
        'cameraMake': cameraMake,
        'cameraModel': cameraModel,
        'software': software,
        'dateTimeOriginal': dateTimeOriginal,
        'gpsLatitude': gpsLatitude,
        'gpsLongitude': gpsLongitude,
        'rawTags': rawTags,
        'forensicAlerts': forensicAlerts,
      };

  factory ExifForensicReport.fromJson(Map<String, dynamic> json) => ExifForensicReport(
        sha256Hash: (json['sha256Hash'] as String?) ?? '',
        fileSizeBytes: (json['fileSizeBytes'] as int?) ?? 0,
        width: (json['width'] as int?) ?? 0,
        height: (json['height'] as int?) ?? 0,
        cameraMake: json['cameraMake'] as String?,
        cameraModel: json['cameraModel'] as String?,
        software: json['software'] as String?,
        dateTimeOriginal: json['dateTimeOriginal'] as String?,
        gpsLatitude: (json['gpsLatitude'] as num?)?.toDouble(),
        gpsLongitude: (json['gpsLongitude'] as num?)?.toDouble(),
        rawTags: Map<String, String>.from((json['rawTags'] as Map?) ?? const {}),
        forensicAlerts: List<String>.from((json['forensicAlerts'] as List?) ?? const []),
      );
}

class OsintFinding {
  final String id;
  final OsintCategory category;
  final String sourceName;
  final String title;
  final String subtitle;
  final String snippet;
  final String url;
  final String archiveUrl;
  final int confidenceScore; // 0 - 100
  final double? faceSimilarity; // 0 - 100 if visual match
  final List<String> matchedFields;
  final String fallbackLayer; // 'Birincil (On-Device/Direct)' | 'Fallback 1 (API/DoH)' | 'Fallback 2 (WebView/Dork)'
  final DateTime timestamp;
  final bool isLiveVerified;
  final bool isFavorite;
  final Map<String, String> telemetry;

  const OsintFinding({
    required this.id,
    required this.category,
    required this.sourceName,
    required this.title,
    required this.subtitle,
    required this.snippet,
    required this.url,
    required this.archiveUrl,
    required this.confidenceScore,
    this.faceSimilarity,
    required this.matchedFields,
    required this.fallbackLayer,
    required this.timestamp,
    this.isLiveVerified = false,
    this.isFavorite = false,
    this.telemetry = const {},
  });

  OsintFinding copyWith({
    bool? isFavorite,
    int? confidenceScore,
    double? faceSimilarity,
    String? archiveUrl,
    bool? isLiveVerified,
  }) {
    return OsintFinding(
      id: id,
      category: category,
      sourceName: sourceName,
      title: title,
      subtitle: subtitle,
      snippet: snippet,
      url: url,
      archiveUrl: archiveUrl ?? this.archiveUrl,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      faceSimilarity: faceSimilarity ?? this.faceSimilarity,
      matchedFields: matchedFields,
      fallbackLayer: fallbackLayer,
      timestamp: timestamp,
      isLiveVerified: isLiveVerified ?? this.isLiveVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      telemetry: telemetry,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'sourceName': sourceName,
        'title': title,
        'subtitle': subtitle,
        'snippet': snippet,
        'url': url,
        'archiveUrl': archiveUrl,
        'confidenceScore': confidenceScore,
        'faceSimilarity': faceSimilarity,
        'matchedFields': matchedFields,
        'fallbackLayer': fallbackLayer,
        'timestamp': timestamp.toIso8601String(),
        'isLiveVerified': isLiveVerified,
        'isFavorite': isFavorite,
        'telemetry': telemetry,
      };

  factory OsintFinding.fromJson(Map<String, dynamic> json) => OsintFinding(
        id: (json['id'] as String?) ?? '',
        category: OsintCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => OsintCategory.socialUsername,
        ),
        sourceName: (json['sourceName'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        snippet: (json['snippet'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        archiveUrl: (json['archiveUrl'] as String?) ?? '',
        confidenceScore: (json['confidenceScore'] as int?) ?? 50,
        faceSimilarity: (json['faceSimilarity'] as num?)?.toDouble(),
        matchedFields: List<String>.from((json['matchedFields'] as List?) ?? const []),
        fallbackLayer: (json['fallbackLayer'] as String?) ?? 'Birincil',
        timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ?? DateTime.now(),
        isLiveVerified: (json['isLiveVerified'] as bool?) ?? false,
        isFavorite: (json['isFavorite'] as bool?) ?? false,
        telemetry: Map<String, String>.from((json['telemetry'] as Map?) ?? const {}),
      );
}

class DiscoveredPivot {
  final String id;
  final PivotType type;
  final String value;
  final String reason;
  final int confidence;
  final int depth;

  const DiscoveredPivot({
    required this.id,
    required this.type,
    required this.value,
    required this.reason,
    required this.confidence,
    required this.depth,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'value': value,
        'reason': reason,
        'confidence': confidence,
        'depth': depth,
      };

  factory DiscoveredPivot.fromJson(Map<String, dynamic> json) => DiscoveredPivot(
        id: (json['id'] as String?) ?? '',
        type: PivotType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PivotType.alias,
        ),
        value: (json['value'] as String?) ?? '',
        reason: (json['reason'] as String?) ?? '',
        confidence: (json['confidence'] as int?) ?? 75,
        depth: (json['depth'] as int?) ?? 1,
      );
}

class TimelineEvent {
  final String dateLabel;
  final String title;
  final String source;
  final String detail;
  final String? url;
  final int confidence;

  const TimelineEvent({
    required this.dateLabel,
    required this.title,
    required this.source,
    required this.detail,
    this.url,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'dateLabel': dateLabel,
        'title': title,
        'source': source,
        'detail': detail,
        'url': url,
        'confidence': confidence,
      };

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        dateLabel: (json['dateLabel'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        source: (json['source'] as String?) ?? '',
        detail: (json['detail'] as String?) ?? '',
        url: json['url'] as String?,
        confidence: (json['confidence'] as int?) ?? 70,
      );
}

class GraphNode {
  final String id;
  final String label;
  final String type; // 'target' | 'face' | 'username' | 'email' | 'phone' | 'turkey' | 'corporate' | 'forum'
  final int confidence;
  final String? url;

  const GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.confidence,
    this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'confidence': confidence,
        'url': url,
      };

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
        id: (json['id'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'node',
        confidence: (json['confidence'] as int?) ?? 80,
        url: json['url'] as String?,
      );
}

class GraphEdge {
  final String fromId;
  final String toId;
  final String relation;
  final int weight;

  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'toId': toId,
        'relation': relation,
        'weight': weight,
      };

  factory GraphEdge.fromJson(Map<String, dynamic> json) => GraphEdge(
        fromId: (json['fromId'] as String?) ?? '',
        toId: (json['toId'] as String?) ?? '',
        relation: (json['relation'] as String?) ?? '',
        weight: (json['weight'] as int?) ?? 75,
      );
}

class InvestigationSession {
  final String id;
  final DateTime createdAt;
  final TargetProfile target;
  final FaceAnalysisResult? faceAnalysis;
  final ExifForensicReport? exifReport;
  final List<OsintFinding> findings;
  final List<DiscoveredPivot> pivots;
  final List<TimelineEvent> timeline;
  final List<GraphNode> graphNodes;
  final List<GraphEdge> graphEdges;
  final List<String> executionLogs;
  final bool offlineModeUsed;

  const InvestigationSession({
    required this.id,
    required this.createdAt,
    required this.target,
    this.faceAnalysis,
    this.exifReport,
    required this.findings,
    required this.pivots,
    required this.timeline,
    required this.graphNodes,
    required this.graphEdges,
    required this.executionLogs,
    this.offlineModeUsed = false,
  });

  int get averageConfidence {
    if (findings.isEmpty) return 0;
    final total = findings.fold<int>(0, (sum, f) => sum + f.confidenceScore);
    return (total / findings.length).round();
  }

  int get highConfidenceCount => findings.where((f) => f.confidenceScore >= 80).length;

  InvestigationSession copyWith({
    List<OsintFinding>? findings,
    List<DiscoveredPivot>? pivots,
    List<TimelineEvent>? timeline,
    List<GraphNode>? graphNodes,
    List<GraphEdge>? graphEdges,
    FaceAnalysisResult? faceAnalysis,
    ExifForensicReport? exifReport,
  }) {
    return InvestigationSession(
      id: id,
      createdAt: createdAt,
      target: target,
      faceAnalysis: faceAnalysis ?? this.faceAnalysis,
      exifReport: exifReport ?? this.exifReport,
      findings: findings ?? this.findings,
      pivots: pivots ?? this.pivots,
      timeline: timeline ?? this.timeline,
      graphNodes: graphNodes ?? this.graphNodes,
      graphEdges: graphEdges ?? this.graphEdges,
      executionLogs: executionLogs,
      offlineModeUsed: offlineModeUsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'target': target.toJson(),
        'faceAnalysis': faceAnalysis?.toJson(),
        'exifReport': exifReport?.toJson(),
        'findings': findings.map((e) => e.toJson()).toList(),
        'pivots': pivots.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'graphNodes': graphNodes.map((e) => e.toJson()).toList(),
        'graphEdges': graphEdges.map((e) => e.toJson()).toList(),
        'executionLogs': executionLogs,
        'offlineModeUsed': offlineModeUsed,
      };

  factory InvestigationSession.fromJson(Map<String, dynamic> json) => InvestigationSession(
        id: (json['id'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
        target: TargetProfile.fromJson((json['target'] as Map<String, dynamic>?) ?? const {}),
        faceAnalysis: json['faceAnalysis'] != null
            ? FaceAnalysisResult.fromJson(json['faceAnalysis'] as Map<String, dynamic>)
            : null,
        exifReport: json['exifReport'] != null
            ? ExifForensicReport.fromJson(json['exifReport'] as Map<String, dynamic>)
            : null,
        findings: ((json['findings'] as List?) ?? const [])
            .map((e) => OsintFinding.fromJson(e as Map<String, dynamic>))
            .toList(),
        pivots: ((json['pivots'] as List?) ?? const [])
            .map((e) => DiscoveredPivot.fromJson(e as Map<String, dynamic>))
            .toList(),
        timeline: ((json['timeline'] as List?) ?? const [])
            .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        graphNodes: ((json['graphNodes'] as List?) ?? const [])
            .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        graphEdges: ((json['graphEdges'] as List?) ?? const [])
            .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        executionLogs: List<String>.from((json['executionLogs'] as List?) ?? const []),
        offlineModeUsed: (json['offlineModeUsed'] as bool?) ?? false,
      );
}

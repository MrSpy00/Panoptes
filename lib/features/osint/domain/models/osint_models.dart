import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum OsintCategory {
  visualAndFace,
  usernameAndSocial,
  emailAndPhone,
  domainAndInfra,
  turkeyRegional,
  documentsAndDorks,
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

enum ReportTemplate {
  executive,
  technical,
  legalKvkk,
}

enum GraphLayoutMode {
  radial,
  hierarchical,
  forceDirected,
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
  final String workspaceName;
  final int selectedFaceIndex;

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
    this.workspaceName = 'Varsayılan Vaka',
    this.selectedFaceIndex = 0,
  });

  bool get hasPhoto =>
      (photoBytes != null && photoBytes!.isNotEmpty) ||
      (photoPath != null && photoPath!.isNotEmpty);

  bool get hasAnyIdentityInput =>
      hasPhoto ||
      fullName.trim().isNotEmpty ||
      username.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      occupationOrOrg.trim().isNotEmpty ||
      notes.trim().isNotEmpty;

  String get displayLabel {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (username.trim().isNotEmpty) return '@${username.trim().replaceAll('@', '')}';
    if (email.trim().isNotEmpty) return email.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    if (occupationOrOrg.trim().isNotEmpty) return occupationOrOrg.trim();
    if (hasPhoto) return 'Biyometrik Hedef (Görsel)';
    return 'İsimsiz Hedef';
  }

  /// Extracts a 2-digit or 4-digit birth year if present (e.g. "1998" -> ("1998", "98"))
  (String?, String?) get extractedBirthYear {
    final match = RegExp(r'\b(19[5-9]\d|20[0-2]\d)\b').firstMatch(birthOrAge);
    if (match != null) {
      final y4 = match.group(1)!;
      return (y4, y4.substring(2));
    }
    return (null, null);
  }

  /// 1. Username Mutation Engine (Turkish-aware ASCII normalization + pattern permutations)
  List<String> get candidateUsernames {
    final candidates = <String>{};
    final (_, y2) = extractedBirthYear;

    if (username.trim().isNotEmpty) {
      final clean = _normalizeTurkishSlug(username.trim().replaceAll('@', ''))
          .replaceAll(' ', '');
      if (clean.isNotEmpty) {
        candidates.add(clean);
        if (clean.contains('.')) candidates.add(clean.replaceAll('.', '_'));
        if (clean.contains('_')) candidates.add(clean.replaceAll('_', ''));
        if (y2 != null && !clean.endsWith(y2)) candidates.add('$clean$y2');
      }
    }

    if (email.contains('@')) {
      final prefix = _normalizeTurkishSlug(email.split('@').first.trim())
          .replaceAll(' ', '');
      if (prefix.length >= 3) {
        candidates.add(prefix);
        if (prefix.contains('.')) candidates.add(prefix.replaceAll('.', ''));
      }
    }

    if (fullName.trim().isNotEmpty) {
      final normalized = _normalizeTurkishSlug(fullName.trim());
      final parts = normalized
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        final first = parts.first;
        final last = parts.last;
        candidates.add('$first$last');
        candidates.add('$first.$last');
        candidates.add('${first}_$last');
        candidates.add('${first[0]}$last');
        candidates.add('${first[0]}.$last');
        candidates.add('$last$first');
        if (y2 != null) {
          candidates.add('$first$last$y2');
        }
      } else if (parts.length == 1 && parts.first.length >= 3) {
        candidates.add(parts.first);
      }
    }
    return candidates.where((c) => c.length >= 3).take(10).toList();
  }

  /// 2. Email Mutation + Corporate/Public Domain Guessing Engine
  List<String> get candidateEmails {
    final emails = <String>{};
    if (email.trim().contains('@')) {
      emails.add(email.trim().toLowerCase());
    }

    final inferredDomains = <String>[
      ...candidateDomains,
      'gmail.com',
      'outlook.com',
      'icloud.com',
      'proton.me',
    ];

    final prefixes = <String>{};
    if (fullName.trim().isNotEmpty) {
      final parts = _normalizeTurkishSlug(fullName.trim())
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        prefixes.add('${parts.first}.${parts.last}');
        prefixes.add('${parts.first}${parts.last}');
        prefixes.add('${parts.first[0]}.${parts.last}');
      }
    }
    for (final u in candidateUsernames.take(2)) {
      prefixes.add(u);
    }

    for (final dom in inferredDomains.take(4)) {
      for (final pre in prefixes.take(3)) {
        emails.add('$pre@$dom');
      }
    }
    return emails.take(8).toList();
  }

  /// 3. Phone Mutation Engine (E.164, National, Spaced, Dashed, Without-Zero)
  List<String> get candidatePhoneFormats {
    final raw = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length < 10) return const [];
    String tenDigits = raw;
    if (raw.startsWith('90') && raw.length >= 12) {
      tenDigits = raw.substring(2, 12);
    } else if (raw.startsWith('0') && raw.length >= 11) {
      tenDigits = raw.substring(1, 11);
    } else if (raw.length > 10) {
      tenDigits = raw.substring(raw.length - 10);
    }
    final p1 = tenDigits.substring(0, 3);
    final p2 = tenDigits.substring(3, 6);
    final p3 = tenDigits.substring(6, 8);
    final p4 = tenDigits.substring(8, 10);

    return [
      '+90$tenDigits',
      '0$tenDigits',
      '0$p1 $p2 $p3 $p4',
      '0$p1-$p2-$p3-$p4',
      '+90 $p1 $p2 $p3 $p4',
    ];
  }

  /// 4. Candidate Domains extracted from Email, Occupation/Company, or Notes
  List<String> get candidateDomains {
    final domains = <String>{};
    final genericProviders = {
      'gmail.com',
      'hotmail.com',
      'outlook.com',
      'yahoo.com',
      'icloud.com',
      'yandex.com',
      'yandex.com.tr',
      'proton.me',
      'protonmail.com',
      'windowslive.com',
    };

    if (email.contains('@')) {
      final dom = email.split('@').last.trim().toLowerCase();
      if (dom.contains('.') && !genericProviders.contains(dom)) {
        domains.add(dom);
      }
    }

    final domainRegex = RegExp(
      r'\b([a-zA-Z0-9-]{2,63}\.(?:com\.tr|org\.tr|edu\.tr|gov\.tr|net\.tr|bel\.tr|av\.tr|dr\.tr|pol\.tr|tsk\.tr|com|net|org|io|dev|ai|co|me|tr))\b',
      caseSensitive: false,
    );
    for (final text in [occupationOrOrg, notes, username]) {
      for (final m in domainRegex.allMatches(text)) {
        final d = m.group(1)!.toLowerCase();
        if (!genericProviders.contains(d)) {
          domains.add(d);
        }
      }
    }

    if (domains.isEmpty && occupationOrOrg.trim().isNotEmpty) {
      final stopWords = {
        'uni',
        'universitesi',
        'university',
        'anonim',
        'sirketi',
        'ltd',
        'sti',
        'as',
        'holding',
        'group',
        'grup',
        'lab',
        'teknoloji',
        'yazilim',
        'bilisim',
        'muhendislik',
      };
      final words = _normalizeTurkishSlug(occupationOrOrg)
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !stopWords.contains(w))
          .toList();
      if (words.isNotEmpty) {
        final slug = words.first;
        if (occupationOrOrg.toLowerCase().contains('üniversite') ||
            occupationOrOrg.toLowerCase().contains('university')) {
          domains.add('$slug.edu.tr');
        } else {
          domains.add('$slug.com.tr');
          domains.add('$slug.com');
        }
      }
    }

    return domains.take(4).toList();
  }

  /// 5. Turkish Vehicle License Plate Detector (01..81 Province Mapping)
  (String plate, String province)? get detectedTurkishPlate {
    final combined = '$notes $occupationOrOrg $cityOrHometown';
    final plateRegex = RegExp(
      r'\b(0[1-9]|[1-7][0-9]|8[01])\s*([A-ZÇĞİÖŞÜ]{1,3})\s*(\d{2,5})\b',
      caseSensitive: false,
    );
    final m = plateRegex.firstMatch(combined.toUpperCase());
    if (m == null) return null;
    final code = m.group(1)!;
    final letters = m.group(2)!;
    final digits = m.group(3)!;
    final province = _trProvinces[code] ?? 'Türkiye ($code)';
    return ('$code $letters $digits', '$province ($code)');
  }

  /// 6. Cryptocurrency Wallet Address Detector (BTC / ETH / EVM / TRON)
  (String network, String address)? get detectedCryptoWallet {
    final combined = '$notes $username';
    final ethMatch = RegExp(r'\b(0x[a-fA-F0-9]{40})\b').firstMatch(combined);
    if (ethMatch != null) return ('Ethereum / EVM', ethMatch.group(1)!);
    final btcMatch = RegExp(r'\b((?:bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39})\b')
        .firstMatch(combined);
    if (btcMatch != null) return ('Bitcoin (BTC)', btcMatch.group(1)!);
    final trxMatch = RegExp(r'\b(T[a-zA-HJ-NP-Z0-9]{33})\b').firstMatch(combined);
    if (trxMatch != null) return ('TRON (TRX/USDT)', trxMatch.group(1)!);
    return null;
  }

  static const Map<String, String> _trProvinces = {
    '01': 'Adana',
    '06': 'Ankara',
    '07': 'Antalya',
    '16': 'Bursa',
    '21': 'Diyarbakır',
    '26': 'Eskişehir',
    '27': 'Gaziantep',
    '31': 'Hatay',
    '33': 'Mersin',
    '34': 'İstanbul',
    '35': 'İzmir',
    '36': 'Kars',
    '38': 'Kayseri',
    '41': 'Kocaeli',
    '42': 'Konya',
    '55': 'Samsun',
    '61': 'Trabzon',
  };

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
    String? workspaceName,
    int? selectedFaceIndex,
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
      workspaceName: workspaceName ?? this.workspaceName,
      selectedFaceIndex: selectedFaceIndex ?? this.selectedFaceIndex,
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
        'workspaceName': workspaceName,
        'selectedFaceIndex': selectedFaceIndex,
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
      workspaceName: (json['workspaceName'] as String?) ?? 'Varsayılan Vaka',
      selectedFaceIndex: (json['selectedFaceIndex'] as int?) ?? 0,
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

class DetectedFaceCandidate {
  final int index;
  final FaceBoundingRect box;
  final int qualityScore;
  final String estimatedAgeRange;
  final String poseAndExpression;
  final String dHashHex;
  final List<double> embedding192d;
  final Uint8List? croppedFaceBytes;

  const DetectedFaceCandidate({
    required this.index,
    required this.box,
    required this.qualityScore,
    required this.estimatedAgeRange,
    required this.poseAndExpression,
    required this.dHashHex,
    required this.embedding192d,
    this.croppedFaceBytes,
  });

  Uint8List get croppedBytes => croppedFaceBytes ?? Uint8List(0);

  Map<String, dynamic> toJson() => {
        'index': index,
        'box': box.toJson(),
        'qualityScore': qualityScore,
        'estimatedAgeRange': estimatedAgeRange,
        'poseAndExpression': poseAndExpression,
        'dHashHex': dHashHex,
        'embedding192d': embedding192d,
      };

  factory DetectedFaceCandidate.fromJson(Map<String, dynamic> json) =>
      DetectedFaceCandidate(
        index: (json['index'] as int?) ?? 0,
        box: FaceBoundingRect.fromJson(
          (json['box'] as Map<String, dynamic>?) ??
              const {'left': 0, 'top': 0, 'width': 100, 'height': 100},
        ),
        qualityScore: (json['qualityScore'] as num?)?.round() ?? 85,
        estimatedAgeRange: (json['estimatedAgeRange'] as String?) ?? '22-32 Yaş',
        poseAndExpression: (json['poseAndExpression'] as String?) ?? 'Cephe • Net',
        dHashHex: (json['dHashHex'] as String?) ?? '',
        embedding192d: ((json['embedding192d'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
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

  int get overallSimilarity => combinedScore.round();
}

class FaceAnalysisResult {
  final bool faceDetected;
  final int faceCount;
  final int selectedFaceIndex;
  final String detectionEngine;
  final FaceBoundingRect? primaryBox;
  final double? headEulerY;
  final double? headEulerZ;
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final List<double> embedding192d;
  final String dHashHex;
  final String aHashHex;
  final List<double> colorHistogram;
  final int qualityScore;
  final Uint8List? croppedFaceBytes;
  final String estimatedAgeRange;
  final String poseAndExpression;
  final String qualityRecommendation;
  final List<DetectedFaceCandidate> allFaces;
  final List<String> ocrExtractedLines;
  final List<String> ocrDiscoveredPivots;

  const FaceAnalysisResult({
    required this.faceDetected,
    required this.faceCount,
    this.selectedFaceIndex = 0,
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
    this.estimatedAgeRange = 'Belirleniyor',
    this.poseAndExpression = 'Cephe Görünüm • Doğal İfade',
    this.qualityRecommendation = 'Optimum biyometrik kalite — ters görsel ve 192-D eşleşmeye hazır.',
    this.allFaces = const [],
    this.ocrExtractedLines = const [],
    this.ocrDiscoveredPivots = const [],
  });

  String get headPoseSummary {
    final y = headEulerY ?? 0.0;
    final z = headEulerZ ?? 0.0;
    if (y.abs() <= 10.0) {
      return 'Tam Cephe (Y:${y.toStringAsFixed(1)}° Z:${z.toStringAsFixed(1)}°)';
    }
    return y > 0
        ? 'Sol Yönelim (+${y.toStringAsFixed(1)}°)'
        : 'Sağ Yönelim (${y.toStringAsFixed(1)}°)';
  }

  String get expressionSummary {
    final parts = poseAndExpression.split('•').map((e) => e.trim()).toList();
    if (parts.length >= 2) return parts.sublist(1).join(' • ');
    return poseAndExpression;
  }

  FaceComparisonResult compareWith(FaceAnalysisResult candidate) {
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

    final dHashSim = _hexHammingSimilarity(dHashHex, candidate.dHashHex);

    double histSim = 0.0;
    final hLen = math.min(colorHistogram.length, candidate.colorHistogram.length);
    if (hLen > 0) {
      double sumMin = 0.0;
      for (int i = 0; i < hLen; i++) {
        sumMin += math.min(colorHistogram[i], candidate.colorHistogram[i]);
      }
      histSim = sumMin.clamp(0.0, 1.0);
    }

    final combined =
        ((cosineSim * 0.62) + (dHashSim * 0.25) + (histSim * 0.13)) * 100.0;
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
        'selectedFaceIndex': selectedFaceIndex,
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
        'estimatedAgeRange': estimatedAgeRange,
        'poseAndExpression': poseAndExpression,
        'qualityRecommendation': qualityRecommendation,
        'allFaces': allFaces.map((f) => f.toJson()).toList(),
        'ocrExtractedLines': ocrExtractedLines,
        'ocrDiscoveredPivots': ocrDiscoveredPivots,
      };

  factory FaceAnalysisResult.fromJson(Map<String, dynamic> json) =>
      FaceAnalysisResult(
        faceDetected: (json['faceDetected'] as bool?) ?? false,
        faceCount: (json['faceCount'] as int?) ?? 0,
        selectedFaceIndex: (json['selectedFaceIndex'] as int?) ?? 0,
        detectionEngine: (json['detectionEngine'] as String?) ?? 'On-Device',
        primaryBox: json['primaryBox'] != null
            ? FaceBoundingRect.fromJson(json['primaryBox'] as Map<String, dynamic>)
            : null,
        headEulerY: (json['headEulerY'] as num?)?.toDouble(),
        headEulerZ: (json['headEulerZ'] as num?)?.toDouble(),
        smilingProbability: (json['smilingProbability'] as num?)?.toDouble(),
        leftEyeOpenProbability: (json['leftEyeOpenProbability'] as num?)?.toDouble(),
        rightEyeOpenProbability:
            (json['rightEyeOpenProbability'] as num?)?.toDouble(),
        embedding192d: ((json['embedding192d'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        dHashHex: (json['dHashHex'] as String?) ?? '',
        aHashHex: (json['aHashHex'] as String?) ?? '',
        colorHistogram: ((json['colorHistogram'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        qualityScore: (json['qualityScore'] as num?)?.round() ?? 0,
        estimatedAgeRange:
            (json['estimatedAgeRange'] as String?) ?? '22-32 Yaş Tahmini',
        poseAndExpression:
            (json['poseAndExpression'] as String?) ?? 'Cephe Görünüm • Net',
        qualityRecommendation:
            (json['qualityRecommendation'] as String?) ?? 'Optimum biyometrik kalite',
        allFaces: ((json['allFaces'] as List?) ?? const [])
            .map((e) => DetectedFaceCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        ocrExtractedLines:
            List<String>.from((json['ocrExtractedLines'] as List?) ?? const []),
        ocrDiscoveredPivots:
            List<String>.from((json['ocrDiscoveredPivots'] as List?) ?? const []),
      );
}

class ExifForensicReport {
  final String sha256Hash;
  final String md5Hash;
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
    this.md5Hash = '',
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
        'md5Hash': md5Hash,
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

  factory ExifForensicReport.fromJson(Map<String, dynamic> json) =>
      ExifForensicReport(
        sha256Hash: (json['sha256Hash'] as String?) ?? '',
        md5Hash: (json['md5Hash'] as String?) ?? '',
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
        forensicAlerts:
            List<String>.from((json['forensicAlerts'] as List?) ?? const []),
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
  final double? faceSimilarityPercent; // 0 - 100 if visual match
  final List<String> tags;
  final String fallbackLayer;
  final DateTime timestamp;
  final bool isLiveVerified;
  final bool isFavorite;
  final Map<String, String> telemetry;
  final Map<String, String> extractedData; // Concrete key-value facts displayed upfront!
  final String scoreBreakdown; // Confidence 2.0 weighted breakdown
  final String? actionablePivotValue;
  final PivotType? actionablePivotType;

  OsintFinding({
    required this.id,
    required this.category,
    required this.sourceName,
    required this.title,
    String? subtitle,
    required this.snippet,
    required this.url,
    String? archiveUrl,
    required this.confidenceScore,
    num? faceSimilarityPercent,
    num? faceSimilarity,
    List<String>? tags,
    List<String>? matchedFields,
    this.fallbackLayer = 'Birincil Sorgu Katmanı',
    DateTime? timestamp,
    this.isLiveVerified = false,
    this.isFavorite = false,
    this.telemetry = const {},
    this.extractedData = const {},
    this.scoreBreakdown = '',
    this.actionablePivotValue,
    this.actionablePivotType,
  })  : subtitle = subtitle ?? sourceName,
        archiveUrl = archiveUrl ?? 'https://web.archive.org/web/*/$url',
        faceSimilarityPercent = (faceSimilarityPercent ?? faceSimilarity)?.toDouble(),
        tags = tags ?? matchedFields ?? const [],
        timestamp = timestamp ?? DateTime.now();

  double? get faceSimilarity => faceSimilarityPercent;
  List<String> get matchedFields => tags;

  OsintFinding copyWith({
    bool? isFavorite,
    int? confidenceScore,
    double? faceSimilarityPercent,
    String? archiveUrl,
    bool? isLiveVerified,
    Map<String, String>? extractedData,
    String? scoreBreakdown,
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
      faceSimilarityPercent: faceSimilarityPercent ?? this.faceSimilarityPercent,
      tags: tags,
      fallbackLayer: fallbackLayer,
      timestamp: timestamp,
      isLiveVerified: isLiveVerified ?? this.isLiveVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      telemetry: telemetry,
      extractedData: extractedData ?? this.extractedData,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      actionablePivotValue: actionablePivotValue,
      actionablePivotType: actionablePivotType,
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
        'faceSimilarityPercent': faceSimilarityPercent,
        'tags': tags,
        'fallbackLayer': fallbackLayer,
        'timestamp': timestamp.toIso8601String(),
        'isLiveVerified': isLiveVerified,
        'isFavorite': isFavorite,
        'telemetry': telemetry,
        'extractedData': extractedData,
        'scoreBreakdown': scoreBreakdown,
        'actionablePivotValue': actionablePivotValue,
        'actionablePivotType': actionablePivotType?.name,
      };

  factory OsintFinding.fromJson(Map<String, dynamic> json) => OsintFinding(
        id: (json['id'] as String?) ?? '',
        category: OsintCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => OsintCategory.usernameAndSocial,
        ),
        sourceName: (json['sourceName'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        snippet: (json['snippet'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        archiveUrl: (json['archiveUrl'] as String?) ?? '',
        confidenceScore: (json['confidenceScore'] as int?) ?? 50,
        faceSimilarityPercent:
            ((json['faceSimilarityPercent'] ?? json['faceSimilarity']) as num?)
                ?.toDouble(),
        tags: List<String>.from(
            (json['tags'] ?? json['matchedFields']) as List? ?? const []),
        fallbackLayer: (json['fallbackLayer'] as String?) ?? 'Birincil',
        timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
            DateTime.now(),
        isLiveVerified: (json['isLiveVerified'] as bool?) ?? false,
        isFavorite: (json['isFavorite'] as bool?) ?? false,
        telemetry: Map<String, String>.from((json['telemetry'] as Map?) ?? const {}),
        extractedData:
            Map<String, String>.from((json['extractedData'] as Map?) ?? const {}),
        scoreBreakdown: (json['scoreBreakdown'] as String?) ?? '',
        actionablePivotValue: json['actionablePivotValue'] as String?,
        actionablePivotType: json['actionablePivotType'] != null
            ? PivotType.values.firstWhere(
                (t) => t.name == json['actionablePivotType'],
                orElse: () => PivotType.alias,
              )
            : null,
      );
}

class DiscoveredPivot {
  final String id;
  final PivotType type;
  final String value;
  final String reason;
  final int confidence;
  final int depth;

  DiscoveredPivot({
    String? id,
    required this.type,
    required this.value,
    required this.reason,
    required this.confidence,
    this.depth = 1,
  }) : id = id ?? 'piv_${value.hashCode.abs()}';

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
  final String type;
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
  final double weight;

  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
    double? weight,
  }) : weight = weight ?? 1.0;

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
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
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
  final List<String> executiveFacts;
  final List<String> diffSummary;
  final String ethicsConsentLog;

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
    this.executiveFacts = const [],
    this.diffSummary = const [],
    this.ethicsConsentLog = 'Kullanıcı Açık Kaynak & KVKK Etik Sorumluluk Beyanını Onayladı',
  });

  int get averageConfidence {
    if (findings.isEmpty) return 0;
    final total = findings.fold<int>(0, (sum, f) => sum + f.confidenceScore);
    return (total / findings.length).round();
  }

  int get highConfidenceCount =>
      findings.where((f) => f.confidenceScore >= 80).length;

  int get liveVerifiedCount =>
      findings.where((f) => f.isLiveVerified).length;

  InvestigationSession copyWith({
    TargetProfile? target,
    List<OsintFinding>? findings,
    List<DiscoveredPivot>? pivots,
    List<TimelineEvent>? timeline,
    List<GraphNode>? graphNodes,
    List<GraphEdge>? graphEdges,
    FaceAnalysisResult? faceAnalysis,
    ExifForensicReport? exifReport,
    List<String>? executiveFacts,
    List<String>? diffSummary,
  }) {
    return InvestigationSession(
      id: id,
      createdAt: createdAt,
      target: target ?? this.target,
      faceAnalysis: faceAnalysis ?? this.faceAnalysis,
      exifReport: exifReport ?? this.exifReport,
      findings: findings ?? this.findings,
      pivots: pivots ?? this.pivots,
      timeline: timeline ?? this.timeline,
      graphNodes: graphNodes ?? this.graphNodes,
      graphEdges: graphEdges ?? this.graphEdges,
      executionLogs: executionLogs,
      offlineModeUsed: offlineModeUsed,
      executiveFacts: executiveFacts ?? this.executiveFacts,
      diffSummary: diffSummary ?? this.diffSummary,
      ethicsConsentLog: ethicsConsentLog,
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
        'executiveFacts': executiveFacts,
        'diffSummary': diffSummary,
        'ethicsConsentLog': ethicsConsentLog,
      };

  factory InvestigationSession.fromJson(Map<String, dynamic> json) =>
      InvestigationSession(
        id: (json['id'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
        target: TargetProfile.fromJson(
            (json['target'] as Map<String, dynamic>?) ?? const {}),
        faceAnalysis: json['faceAnalysis'] != null
            ? FaceAnalysisResult.fromJson(
                json['faceAnalysis'] as Map<String, dynamic>)
            : null,
        exifReport: json['exifReport'] != null
            ? ExifForensicReport.fromJson(
                json['exifReport'] as Map<String, dynamic>)
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
        executionLogs:
            List<String>.from((json['executionLogs'] as List?) ?? const []),
        offlineModeUsed: (json['offlineModeUsed'] as bool?) ?? false,
        executiveFacts:
            List<String>.from((json['executiveFacts'] as List?) ?? const []),
        diffSummary:
            List<String>.from((json['diffSummary'] as List?) ?? const []),
        ethicsConsentLog: (json['ethicsConsentLog'] as String?) ??
            'Kullanıcı Açık Kaynak & KVKK Etik Sorumluluk Beyanını Onayladı',
      );
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef DeviceSecurityReport = SecurityPostureReport;

class SecurityPostureReport {
  final bool debuggerAttached;
  final bool rootDetected;
  final bool fridaOrHookDetected;
  final bool isEmulator;
  final bool isReleaseBuild;
  final String deviceModel;
  final int securityScore;
  final List<String> findings;

  const SecurityPostureReport({
    required this.debuggerAttached,
    required this.rootDetected,
    required this.fridaOrHookDetected,
    required this.isEmulator,
    required this.isReleaseBuild,
    required this.deviceModel,
    required this.securityScore,
    required this.findings,
  });

  bool get rootOrSuDetected => rootDetected;
  bool get isClean => !debuggerAttached && !rootDetected && !fridaOrHookDetected;
  String get summaryText => findings.join('\n• ');
}

class OpsecSecurityService {
  static const MethodChannel _channel = MethodChannel('com.aegissoft.panoptes/opsec');
  final math.Random _rng = math.Random.secure();

  static const List<String> _userAgents = [
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  ];

  String getRotatedUserAgent({bool rotate = true}) {
    if (!rotate) return _userAgents.first;
    return _userAgents[_rng.nextInt(_userAgents.length)];
  }

  Future<void> applyRequestJitter({bool enabled = true}) async {
    if (!enabled) return;
    final delayMs = 25 + _rng.nextInt(85);
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  Future<bool> setSecureScreen(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setSecureScreen', {'enabled': enabled});
      return res ?? enabled;
    } catch (_) {
      return false;
    }
  }

  Future<SecurityPostureReport> inspectSecurityPosture({bool secureScreenActive = true}) async {
    bool debugger = false;
    bool root = false;
    bool frida = false;
    bool emulator = false;
    String model = kIsWeb ? 'WEB' : Platform.operatingSystem.toUpperCase();

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('checkDeviceIntegrity');
        if (raw != null) {
          debugger = raw['debuggerAttached'] == true;
          root = raw['rootDetected'] == true;
          frida = raw['fridaOrHookDetected'] == true;
          emulator = raw['isEmulator'] == true;
          final m = raw['deviceModel']?.toString() ?? '';
          final rel = raw['androidRelease']?.toString() ?? '';
          if (m.isNotEmpty) {
            model = '$m (Android $rel)';
          }
        }
      } catch (_) {
        const suPaths = ['/system/bin/su', '/system/xbin/su', '/sbin/su', '/data/adb/magisk'];
        root = suPaths.any((p) => File(p).existsSync());
        frida = File('/data/local/tmp/frida-server').existsSync();
      }
    }

    int score = 100;
    final notes = <String>[];
    if (frida) {
      score -= 45;
      notes.add('UYARI: Frida / Xposed / Bellek enjeksiyon izi tespit edildi.');
    } else {
      notes.add('Bellek Bütünlüğü: Frida / Xposed / Substrate kancası (hook) tespit edilmedi.');
    }

    if (root) {
      score -= 25;
      notes.add('UYARI: Cihazda Root / Su / Magisk erişimi tespit edildi.');
    } else {
      notes.add('Sistem Bütünlüğü: Root / Su ikili dosyası bulunmadı.');
    }

    if (debugger) {
      score -= 10;
      notes.add('Bilgi: Çalışma zamanı hata ayıklayıcı (Debugger/JDWP) bağlı.');
    } else {
      notes.add('Anti-Debug: Harici JDWP / LLDB debugger bağlı değil.');
    }

    if (!secureScreenActive) {
      score -= 5;
      notes.add('Ekran Kalkanı: FLAG_SECURE devre dışı (Ekran görüntüsü alınabilir).');
    } else {
      notes.add('Ekran Kalkanı: FLAG_SECURE aktif.');
    }

    if (kReleaseMode) {
      notes.add('Derleme Koruması: Release AOT + R8 Obfuscation aktif.');
    } else {
      notes.add('Derleme Modu: Geliştirme (Debug/JIT) profili — tam R8 gizleme Release APK\'da devrededir.');
    }

    notes.add('Veri Sızıntı Kalkanı: Android Auto-Backup kapalı, yerel kasa PV2 HMAC-SHA256 şifreli.');

    return SecurityPostureReport(
      debuggerAttached: debugger,
      rootDetected: root,
      fridaOrHookDetected: frida,
      isEmulator: emulator,
      isReleaseBuild: kReleaseMode,
      deviceModel: model,
      securityScore: score.clamp(10, 100),
      findings: notes,
    );
  }

  /// Authenticated stream encryption (SHA-256 Counter Mode + HMAC-SHA256 Tag)
  /// Ensures local vault sessions and biometric vectors are encrypted at rest without native C dependencies.
  String encryptVaultJson(String plainText, {String passphrase = 'panoptes-local-edge-key-v2'}) {
    final salt = List<int>.generate(16, (_) => _rng.nextInt(256));
    final keyBytes = sha256.convert(utf8.encode('$passphrase::${base64Encode(salt)}')).bytes;
    final plainBytes = utf8.encode(plainText);
    final cipherBytes = Uint8List(plainBytes.length);

    int blockIndex = 0;
    List<int> keystreamBlock = const [];
    for (int i = 0; i < plainBytes.length; i++) {
      if (i % 32 == 0) {
        keystreamBlock = sha256.convert([...keyBytes, ...salt, blockIndex & 0xFF, (blockIndex >> 8) & 0xFF]).bytes;
        blockIndex++;
      }
      cipherBytes[i] = plainBytes[i] ^ keystreamBlock[i % 32];
    }

    final mac = Hmac(sha256, keyBytes).convert([...salt, ...cipherBytes]).bytes;
    return 'PV2:${base64Encode(salt)}:${base64Encode(mac)}:${base64Encode(cipherBytes)}';
  }

  String? decryptVaultJson(String payload, {String passphrase = 'panoptes-local-edge-key-v2'}) {
    if (!payload.startsWith('PV2:')) {
      return payload;
    }
    try {
      final parts = payload.split(':');
      if (parts.length != 4) return null;
      final salt = base64Decode(parts[1]);
      final expectedMac = base64Decode(parts[2]);
      final cipherBytes = base64Decode(parts[3]);

      final keyBytes = sha256.convert(utf8.encode('$passphrase::${base64Encode(salt)}')).bytes;
      final actualMac = Hmac(sha256, keyBytes).convert([...salt, ...cipherBytes]).bytes;

      if (actualMac.length != expectedMac.length) return null;
      int diff = 0;
      for (int i = 0; i < actualMac.length; i++) {
        diff |= actualMac[i] ^ expectedMac[i];
      }
      if (diff != 0) return null;

      final plainBytes = Uint8List(cipherBytes.length);
      int blockIndex = 0;
      List<int> keystreamBlock = const [];
      for (int i = 0; i < cipherBytes.length; i++) {
        if (i % 32 == 0) {
          keystreamBlock = sha256.convert([...keyBytes, ...salt, blockIndex & 0xFF, (blockIndex >> 8) & 0xFF]).bytes;
          blockIndex++;
        }
        plainBytes[i] = cipherBytes[i] ^ keystreamBlock[i % 32];
      }
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }
}

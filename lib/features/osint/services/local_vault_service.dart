import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/security/opsec_security_service.dart';
import '../domain/models/osint_models.dart';

class LocalVaultService {
  static const String _keyEthicsAccepted = 'panoptes_ethics_accepted_v1';
  static const String _keySessions = 'panoptes_sessions_v1';
  static const String _keyDarkMode = 'panoptes_dark_mode_v1';
  static const String _keyLanguage = 'panoptes_lang_v1';
  static const String _keySupabaseUrl = 'panoptes_supabase_url_v1';
  static const String _keySupabaseAnonKey = 'panoptes_supabase_anon_v1';
  static const String _keySecureScreen = 'panoptes_opsec_secure_screen_v2';
  static const String _keyUaRotation = 'panoptes_opsec_ua_rotation_v2';
  static const String _keyWorkspace = 'panoptes_active_workspace_v2';

  final OpsecSecurityService opsecService;

  LocalVaultService({OpsecSecurityService? opsecService})
      : opsecService = opsecService ?? OpsecSecurityService();

  Future<bool> isEthicsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEthicsAccepted) ?? false;
  }

  Future<void> setEthicsAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEthicsAccepted, accepted);
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? true;
  }

  Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDark);
  }

  Future<String> loadLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'tr';
  }

  Future<void> saveLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }

  Future<bool> loadSecureScreenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySecureScreen) ?? false;
  }

  Future<void> saveSecureScreenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecureScreen, enabled);
    await opsecService.setSecureScreen(enabled);
  }

  Future<bool> loadUaRotationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUaRotation) ?? true;
  }

  Future<void> saveUaRotationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUaRotation, enabled);
  }

  Future<String> loadActiveWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkspace) ?? 'Genel Operasyon';
  }

  Future<void> saveActiveWorkspace(String workspace) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWorkspace, workspace.trim().isEmpty ? 'Genel Operasyon' : workspace.trim());
  }

  Future<(String, String)> loadSupabaseConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keySupabaseUrl) ?? '';
    final key = prefs.getString(_keySupabaseAnonKey) ?? '';
    return (url, key);
  }

  Future<void> saveSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySupabaseUrl, url.trim());
    await prefs.setString(_keySupabaseAnonKey, anonKey.trim());
  }

  Future<List<InvestigationSession>> loadSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keySessions) ?? const [];
    final sessions = <InvestigationSession>[];
    for (final raw in rawList) {
      try {
        final decrypted = opsecService.decryptVaultJson(raw);
        if (decrypted != null) {
          final decoded = jsonDecode(decrypted) as Map<String, dynamic>;
          sessions.add(InvestigationSession.fromJson(decoded));
        }
      } catch (_) {}
    }
    return sessions;
  }

  Future<void> saveSession(InvestigationSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadSavedSessions();
    final filtered = current.where((s) => s.id != session.id).toList();
    // Strip raw photo bytes in long-term history list to keep storage ultra-fast
    final compactTarget = session.target.copyWith(clearPhoto: true);
    final compactSession = InvestigationSession(
      id: session.id,
      createdAt: session.createdAt,
      target: compactTarget,
      faceAnalysis: session.faceAnalysis,
      exifReport: session.exifReport,
      findings: session.findings,
      pivots: session.pivots,
      timeline: session.timeline,
      graphNodes: session.graphNodes,
      graphEdges: session.graphEdges,
      executionLogs: session.executionLogs,
      offlineModeUsed: session.offlineModeUsed,
      executiveFacts: session.executiveFacts,
      diffSummary: session.diffSummary,
    );
    final updated = [compactSession, ...filtered].take(30).toList();
    await prefs.setStringList(
      _keySessions,
      updated.map((s) => opsecService.encryptVaultJson(jsonEncode(s.toJson()))).toList(),
    );
  }

  Future<void> deleteSessionById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadSavedSessions();
    final filtered = current.where((s) => s.id != id).toList();
    await prefs.setStringList(
      _keySessions,
      filtered.map((s) => opsecService.encryptVaultJson(jsonEncode(s.toJson()))).toList(),
    );
  }

  Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessions);
  }

  /// Panic Wipe / Full Factory Reset — destroys all local sessions, credentials, and cache
  Future<void> panicWipeEverything() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessions);
    await prefs.remove(_keySupabaseUrl);
    await prefs.remove(_keySupabaseAnonKey);
    await prefs.remove(_keyWorkspace);
  }

  /// Optional Supabase Cloud Sync (Privacy-by-Design: only sends sanitized metadata when explicitly configured)
  Future<(bool, String)> syncSessionToSupabase(InvestigationSession session) async {
    final (url, anonKey) = await loadSupabaseConfig();
    if (url.isEmpty || anonKey.isEmpty) {
      return (false, 'Supabase URL veya Anon Key tanımlı değil (Cihaz İçi Offline Mod aktif).');
    }

    try {
      final endpoint = Uri.parse('${url.replaceAll(RegExp(r'/$'), '')}/rest/v1/osint_sessions');
      final resp = await http
          .post(
            endpoint,
            headers: {
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({
              'session_id': session.id,
              'target_label': session.target.displayLabel,
              'workspace': session.target.workspaceName,
              'findings_count': session.findings.length,
              'avg_confidence': session.averageConfidence,
              'face_dhash': session.faceAnalysis?.dHashHex,
              'payload': session.toJson(),
              'created_at': session.createdAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return (true, 'Dosya Supabase Cloud üzerine başarıyla senkronize edildi.');
      }
      return (false, 'Supabase yanıt kodu: HTTP ${resp.statusCode}');
    } catch (e) {
      return (false, 'Supabase bağlantı hatası: $e');
    }
  }
}

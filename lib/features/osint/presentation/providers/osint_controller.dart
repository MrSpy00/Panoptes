import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/models/osint_models.dart';
import '../../services/export_service.dart';
import '../../services/face_forensics_service.dart';
import '../../services/local_vault_service.dart';
import '../../services/osint_recon_engine.dart';

class PanoptesState {
  final bool ethicsAccepted;
  final bool isDarkMode;
  final AppLanguage language;
  final int activeTabIndex;
  final TargetProfile draftTarget;
  final bool isScanning;
  final String scanStage;
  final double scanProgress;
  final InvestigationSession? currentSession;
  final List<InvestigationSession> savedSessions;
  final OsintCategory? selectedCategory;
  final int minConfidenceFilter;
  final bool favoritesOnly;
  final FaceAnalysisResult? candidateFaceResult;
  final FaceComparisonResult? faceComparisonResult;
  final bool isComparingFace;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const PanoptesState({
    this.ethicsAccepted = false,
    this.isDarkMode = true,
    this.language = AppLanguage.tr,
    this.activeTabIndex = 0,
    this.draftTarget = const TargetProfile(),
    this.isScanning = false,
    this.scanStage = '',
    this.scanProgress = 0.0,
    this.currentSession,
    this.savedSessions = const [],
    this.selectedCategory,
    this.minConfidenceFilter = 0,
    this.favoritesOnly = false,
    this.candidateFaceResult,
    this.faceComparisonResult,
    this.isComparingFace = false,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  AppStrings get strings => AppStrings(language);

  List<OsintFinding> get filteredFindings {
    final session = currentSession;
    if (session == null) return const [];
    return session.findings.where((f) {
      if (selectedCategory != null && f.category != selectedCategory) return false;
      if (f.confidenceScore < minConfidenceFilter) return false;
      if (favoritesOnly && !f.isFavorite) return false;
      return true;
    }).toList();
  }

  PanoptesState copyWith({
    bool? ethicsAccepted,
    bool? isDarkMode,
    AppLanguage? language,
    int? activeTabIndex,
    TargetProfile? draftTarget,
    bool? isScanning,
    String? scanStage,
    double? scanProgress,
    InvestigationSession? currentSession,
    List<InvestigationSession>? savedSessions,
    OsintCategory? selectedCategory,
    bool clearCategory = false,
    int? minConfidenceFilter,
    bool? favoritesOnly,
    FaceAnalysisResult? candidateFaceResult,
    FaceComparisonResult? faceComparisonResult,
    bool clearFaceComparison = false,
    bool? isComparingFace,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    return PanoptesState(
      ethicsAccepted: ethicsAccepted ?? this.ethicsAccepted,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      draftTarget: draftTarget ?? this.draftTarget,
      isScanning: isScanning ?? this.isScanning,
      scanStage: scanStage ?? this.scanStage,
      scanProgress: scanProgress ?? this.scanProgress,
      currentSession: currentSession ?? this.currentSession,
      savedSessions: savedSessions ?? this.savedSessions,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      minConfidenceFilter: minConfidenceFilter ?? this.minConfidenceFilter,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      candidateFaceResult:
          clearFaceComparison ? null : (candidateFaceResult ?? this.candidateFaceResult),
      faceComparisonResult:
          clearFaceComparison ? null : (faceComparisonResult ?? this.faceComparisonResult),
      isComparingFace: isComparingFace ?? this.isComparingFace,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    );
  }
}

class PanoptesNotifier extends StateNotifier<PanoptesState> {
  final FaceForensicsService faceService;
  final OsintReconEngine reconEngine;
  final LocalVaultService vaultService;
  final ExportService exportService;

  PanoptesNotifier({
    required this.faceService,
    required this.reconEngine,
    required this.vaultService,
    required this.exportService,
  }) : super(const PanoptesState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final accepted = await vaultService.isEthicsAccepted();
    final isDark = await vaultService.loadDarkMode();
    final langCode = await vaultService.loadLanguageCode();
    final sessions = await vaultService.loadSavedSessions();
    final (sbUrl, sbKey) = await vaultService.loadSupabaseConfig();

    state = state.copyWith(
      ethicsAccepted: accepted,
      isDarkMode: isDark,
      language: langCode == 'en' ? AppLanguage.en : AppLanguage.tr,
      savedSessions: sessions,
      currentSession: sessions.isNotEmpty ? sessions.first : null,
      supabaseUrl: sbUrl,
      supabaseAnonKey: sbKey,
    );
  }

  Future<void> acceptEthics() async {
    await vaultService.setEthicsAccepted(true);
    state = state.copyWith(ethicsAccepted: true);
  }

  Future<void> toggleTheme() async {
    final next = !state.isDarkMode;
    await vaultService.saveDarkMode(next);
    state = state.copyWith(isDarkMode: next);
  }

  Future<void> toggleLanguage() async {
    final next = state.language == AppLanguage.tr ? AppLanguage.en : AppLanguage.tr;
    await vaultService.saveLanguageCode(next.name);
    state = state.copyWith(language: next);
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  void updateDraftTarget(TargetProfile updated) {
    state = state.copyWith(draftTarget: updated);
  }

  void setCategoryFilter(OsintCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void setMinConfidenceFilter(int value) {
    state = state.copyWith(minConfidenceFilter: value);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
  }

  void loadSampleScenario() {
    final demoPhoto = faceService.generateDemoPortraitBytes(variant: 0);
    final sample = TargetProfile(
      photoBytes: demoPhoto,
      fullName: 'MrSpy Aegis',
      birthOrAge: '1998 (26-30)',
      cityOrHometown: 'İstanbul / Kars',
      username: 'MrSpy00',
      email: 'security@aegissoft.com.tr',
      phone: '+90 532 410 00 00',
      occupationOrOrg: 'aegisSoft Offensive Security & OSINT Lab',
      notes: 'Red Team, OSINT, Rust/Flutter/TypeScript, Türkiye Siber Güvenlik Araştırmaları',
      pivotDepth: 0,
    );
    state = state.copyWith(draftTarget: sample);
  }

  void clearDraft() {
    state = state.copyWith(
      draftTarget: const TargetProfile(),
      clearFaceComparison: true,
    );
  }

  Future<void> runInvestigation({TargetProfile? overrideTarget}) async {
    final target = overrideTarget ?? state.draftTarget;
    if (!target.hasAnyIdentityInput) return;

    state = state.copyWith(
      draftTarget: target,
      isScanning: true,
      scanStage: 'Cihaz İçi OSINT Motoru Hazırlanıyor...',
      scanProgress: 0.05,
      clearCategory: true,
    );

    final session = await reconEngine.executeFullScan(
      target: target,
      optionalSupabaseEdgeUrl: state.supabaseUrl.isNotEmpty ? state.supabaseUrl : null,
      onProgress: (stage, progress) {
        if (mounted) {
          state = state.copyWith(scanStage: stage, scanProgress: progress);
        }
      },
    );

    await vaultService.saveSession(session);
    final updatedSessions = await vaultService.loadSavedSessions();

    state = state.copyWith(
      isScanning: false,
      scanStage: 'Tamamlandı',
      scanProgress: 1.0,
      currentSession: session,
      savedSessions: updatedSessions,
      activeTabIndex: 1, // Switch to Dossier Results tab automatically
    );
  }

  /// Recursive Pivot Execution (with depth limit <= 3)
  Future<void> deepenWithPivot(DiscoveredPivot pivot) async {
    if (pivot.depth > 3) return;
    TargetProfile next = state.draftTarget.copyWith(pivotDepth: pivot.depth);
    switch (pivot.type) {
      case PivotType.username:
      case PivotType.alias:
        next = next.copyWith(username: pivot.value.replaceAll('@', ''));
        break;
      case PivotType.email:
        next = next.copyWith(email: pivot.value);
        break;
      case PivotType.phone:
        next = next.copyWith(phone: pivot.value);
        break;
      case PivotType.city:
        next = next.copyWith(cityOrHometown: pivot.value);
        break;
      case PivotType.organization:
      case PivotType.domain:
        next = next.copyWith(
          occupationOrOrg:
              '${next.occupationOrOrg} ${pivot.value}'.trim(),
        );
        break;
    }
    await runInvestigation(overrideTarget: next);
  }

  Future<void> toggleFindingFavorite(String findingId) async {
    final session = state.currentSession;
    if (session == null) return;
    final updatedFindings = session.findings.map((f) {
      if (f.id == findingId) {
        return f.copyWith(isFavorite: !f.isFavorite);
      }
      return f;
    }).toList();
    final updatedSession = session.copyWith(findings: updatedFindings);
    await vaultService.saveSession(updatedSession);
    final saved = await vaultService.loadSavedSessions();
    state = state.copyWith(currentSession: updatedSession, savedSessions: saved);
  }

  void selectSavedSession(InvestigationSession session) {
    state = state.copyWith(
      currentSession: session,
      draftTarget: session.target,
      activeTabIndex: 1,
    );
  }

  Future<void> clearVaultHistory() async {
    await vaultService.clearAllHistory();
    state = state.copyWith(savedSessions: const []);
  }

  /// On-Device Candidate Face Comparison (compare any image bytes against target face)
  Future<void> compareCandidateFaceBytes(Uint8List candidateBytes, {String? filePath}) async {
    FaceAnalysisResult? targetFace = state.currentSession?.faceAnalysis;
    if (targetFace == null && state.draftTarget.photoBytes != null) {
      targetFace = await faceService.analyzeFace(
        imageBytes: state.draftTarget.photoBytes!,
        filePath: state.draftTarget.photoPath,
      );
    }
    if (targetFace == null) return;

    state = state.copyWith(isComparingFace: true);
    final candidateFace = await faceService.analyzeFace(
      imageBytes: candidateBytes,
      filePath: filePath,
    );
    final comparison = targetFace.compareWith(candidateFace);
    state = state.copyWith(
      isComparingFace: false,
      candidateFaceResult: candidateFace,
      faceComparisonResult: comparison,
    );
  }

  /// On-Device Candidate Face Comparison via remote Image URL
  Future<bool> compareCandidateFaceUrl(String imageUrl) async {
    FaceAnalysisResult? targetFace = state.currentSession?.faceAnalysis;
    if (targetFace == null && state.draftTarget.photoBytes != null) {
      targetFace = await faceService.analyzeFace(
        imageBytes: state.draftTarget.photoBytes!,
        filePath: state.draftTarget.photoPath,
      );
    }
    if (targetFace == null) return false;

    state = state.copyWith(isComparingFace: true);
    final res = await reconEngine.verifyCandidateImageUrl(
      imageUrl: imageUrl.trim(),
      targetFace: targetFace,
    );
    if (res == null) {
      state = state.copyWith(isComparingFace: false);
      return false;
    }
    state = state.copyWith(
      isComparingFace: false,
      candidateFaceResult: res.$1,
      faceComparisonResult: res.$2,
    );
    return true;
  }

  Future<void> saveSupabaseSettings(String url, String anonKey) async {
    await vaultService.saveSupabaseConfig(url: url, anonKey: anonKey);
    state = state.copyWith(supabaseUrl: url.trim(), supabaseAnonKey: anonKey.trim());
  }

  Future<(bool, String)> syncActiveSessionToCloud() async {
    final session = state.currentSession;
    if (session == null) {
      return (false, 'Senkronize edilecek aktif dosya yok.');
    }
    return vaultService.syncSessionToSupabase(session);
  }
}

final panoptesProvider = StateNotifierProvider<PanoptesNotifier, PanoptesState>((ref) {
  final faceService = FaceForensicsService();
  return PanoptesNotifier(
    faceService: faceService,
    reconEngine: OsintReconEngine(faceService: faceService),
    vaultService: LocalVaultService(),
    exportService: ExportService(),
  );
});

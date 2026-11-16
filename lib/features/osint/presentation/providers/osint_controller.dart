import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/security/opsec_security_service.dart';
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
  final FaceAnalysisResult? draftFacePreview;
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
  final SecurityPostureReport? securityPosture;
  final bool secureScreenEnabled;
  final bool uaRotationEnabled;
  final String activeWorkspace;
  final ReportTemplate selectedReportTemplate;
  final GraphLayoutMode graphLayoutMode;

  const PanoptesState({
    this.ethicsAccepted = false,
    this.isDarkMode = true,
    this.language = AppLanguage.tr,
    this.activeTabIndex = 0,
    this.draftTarget = const TargetProfile(),
    this.draftFacePreview,
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
    this.securityPosture,
    this.secureScreenEnabled = false,
    this.uaRotationEnabled = true,
    this.activeWorkspace = 'Genel Operasyon',
    this.selectedReportTemplate = ReportTemplate.technical,
    this.graphLayoutMode = GraphLayoutMode.radial,
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
    FaceAnalysisResult? draftFacePreview,
    bool clearDraftFacePreview = false,
    bool? isScanning,
    String? scanStage,
    double? scanProgress,
    InvestigationSession? currentSession,
    bool clearCurrentSession = false,
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
    SecurityPostureReport? securityPosture,
    bool? secureScreenEnabled,
    bool? uaRotationEnabled,
    String? activeWorkspace,
    ReportTemplate? selectedReportTemplate,
    GraphLayoutMode? graphLayoutMode,
  }) {
    return PanoptesState(
      ethicsAccepted: ethicsAccepted ?? this.ethicsAccepted,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      draftTarget: draftTarget ?? this.draftTarget,
      draftFacePreview:
          clearDraftFacePreview ? null : (draftFacePreview ?? this.draftFacePreview),
      isScanning: isScanning ?? this.isScanning,
      scanStage: scanStage ?? this.scanStage,
      scanProgress: scanProgress ?? this.scanProgress,
      currentSession:
          clearCurrentSession ? null : (currentSession ?? this.currentSession),
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
      securityPosture: securityPosture ?? this.securityPosture,
      secureScreenEnabled: secureScreenEnabled ?? this.secureScreenEnabled,
      uaRotationEnabled: uaRotationEnabled ?? this.uaRotationEnabled,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      selectedReportTemplate: selectedReportTemplate ?? this.selectedReportTemplate,
      graphLayoutMode: graphLayoutMode ?? this.graphLayoutMode,
    );
  }
}

class PanoptesNotifier extends StateNotifier<PanoptesState> {
  final FaceForensicsService faceService;
  final OsintReconEngine reconEngine;
  final LocalVaultService vaultService;
  final ExportService exportService;
  final OpsecSecurityService opsecService;

  PanoptesNotifier({
    required this.faceService,
    required this.reconEngine,
    required this.vaultService,
    required this.exportService,
    required this.opsecService,
  }) : super(const PanoptesState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final accepted = await vaultService.isEthicsAccepted();
    final isDark = await vaultService.loadDarkMode();
    final langCode = await vaultService.loadLanguageCode();
    final sessions = await vaultService.loadSavedSessions();
    final (sbUrl, sbKey) = await vaultService.loadSupabaseConfig();
    final secureScreen = await vaultService.loadSecureScreenEnabled();
    final uaRotation = await vaultService.loadUaRotationEnabled();
    final workspace = await vaultService.loadActiveWorkspace();
    final posture = await opsecService.inspectSecurityPosture(
      secureScreenActive: secureScreen,
    );

    state = state.copyWith(
      ethicsAccepted: accepted,
      isDarkMode: isDark,
      language: langCode == 'en' ? AppLanguage.en : AppLanguage.tr,
      savedSessions: sessions,
      currentSession: sessions.isNotEmpty ? sessions.first : null,
      supabaseUrl: sbUrl,
      supabaseAnonKey: sbKey,
      secureScreenEnabled: secureScreen,
      uaRotationEnabled: uaRotation,
      activeWorkspace: workspace,
      draftTarget: state.draftTarget.copyWith(workspaceName: workspace),
      securityPosture: posture,
    );
  }

  Future<void> refreshSecurityPosture() async {
    final posture = await opsecService.inspectSecurityPosture(
      secureScreenActive: state.secureScreenEnabled,
    );
    state = state.copyWith(securityPosture: posture);
  }

  Future<void> toggleSecureScreen() async {
    final next = !state.secureScreenEnabled;
    await vaultService.saveSecureScreenEnabled(next);
    final posture = await opsecService.inspectSecurityPosture(
      secureScreenActive: next,
    );
    state = state.copyWith(secureScreenEnabled: next, securityPosture: posture);
  }

  Future<void> toggleUaRotation() async {
    final next = !state.uaRotationEnabled;
    await vaultService.saveUaRotationEnabled(next);
    state = state.copyWith(uaRotationEnabled: next);
  }

  Future<void> setWorkspace(String workspaceName) async {
    final clean = workspaceName.trim().isEmpty ? 'Genel Operasyon' : workspaceName.trim();
    await vaultService.saveActiveWorkspace(clean);
    state = state.copyWith(
      activeWorkspace: clean,
      draftTarget: state.draftTarget.copyWith(workspaceName: clean),
    );
  }

  void setReportTemplate(ReportTemplate template) {
    state = state.copyWith(selectedReportTemplate: template);
  }

  void setGraphLayoutMode(GraphLayoutMode mode) {
    state = state.copyWith(graphLayoutMode: mode);
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

  Future<void> updateDraftTarget(TargetProfile updated) async {
    final photoChanged = updated.photoBytes != state.draftTarget.photoBytes ||
        updated.selectedFaceIndex != state.draftTarget.selectedFaceIndex;
    state = state.copyWith(
      draftTarget: updated,
      clearDraftFacePreview: updated.photoBytes == null,
    );
    if (photoChanged && updated.photoBytes != null) {
      final preview = await faceService.analyzeFace(
        imageBytes: updated.photoBytes!,
        filePath: updated.photoPath,
        selectedFaceIndex: updated.selectedFaceIndex,
      );
      if (mounted) {
        state = state.copyWith(draftFacePreview: preview);
      }
    }
  }

  Future<void> selectTargetFace(int faceIndex) async {
    final nextDraft = state.draftTarget.copyWith(selectedFaceIndex: faceIndex);
    await updateDraftTarget(nextDraft);
    // Also update currentSession faceAnalysis if it uses the same photo
    if (state.currentSession != null && state.draftTarget.photoBytes != null) {
      final reanalyzed = await faceService.analyzeFace(
        imageBytes: state.draftTarget.photoBytes!,
        filePath: state.draftTarget.photoPath,
        selectedFaceIndex: faceIndex,
      );
      state = state.copyWith(
        currentSession: state.currentSession!.copyWith(
          target: nextDraft,
          faceAnalysis: reanalyzed,
        ),
      );
    }
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

  Future<void> loadSampleScenario() async {
    final demoPhoto = faceService.generateDemoPortraitBytes(variant: 0);
    final sample = TargetProfile(
      photoBytes: demoPhoto,
      fullName: 'MrSpy Aegis',
      birthOrAge: '1998 (26-30)',
      cityOrHometown: 'İstanbul / Kars',
      username: 'MrSpy00',
      email: 'aegissoft0@gmail.com',
      phone: '+90 532 410 00 00',
      occupationOrOrg: 'aegisSoft Offensive Security & OSINT Lab',
      notes: 'Red Team, OSINT, Rust/Flutter/TypeScript, Türkiye Siber Güvenlik Araştırmaları',
      pivotDepth: 0,
      workspaceName: state.activeWorkspace,
    );
    await updateDraftTarget(sample);
  }

  /// Clears ONLY the input form fields
  void clearDraft() {
    state = state.copyWith(
      draftTarget: TargetProfile(workspaceName: state.activeWorkspace),
      clearDraftFacePreview: true,
      clearFaceComparison: true,
    );
  }

  /// Closes the active dossier (`currentSession`) AND clears the form so no old findings remain visible
  void clearDraftAndActiveSession() {
    state = state.copyWith(
      draftTarget: TargetProfile(workspaceName: state.activeWorkspace),
      clearDraftFacePreview: true,
      clearCurrentSession: true,
      clearFaceComparison: true,
      clearCategory: true,
    );
  }

  /// Closes only the active dossier
  void closeActiveSession() {
    state = state.copyWith(
      clearCurrentSession: true,
      clearFaceComparison: true,
      clearCategory: true,
    );
  }

  Future<void> deleteSavedSession(String sessionId) async {
    await vaultService.deleteSessionById(sessionId);
    final updated = await vaultService.loadSavedSessions();
    final clearCurrent = state.currentSession?.id == sessionId;
    state = state.copyWith(
      savedSessions: updated,
      clearCurrentSession: clearCurrent,
    );
  }

  /// Panic Wipe / Factory Reset — wipes all history, active dossier, form, and cloud keys
  Future<void> panicWipeAll() async {
    await vaultService.panicWipeEverything();
    state = state.copyWith(
      draftTarget: const TargetProfile(),
      clearDraftFacePreview: true,
      clearCurrentSession: true,
      savedSessions: const [],
      clearFaceComparison: true,
      clearCategory: true,
      supabaseUrl: '',
      supabaseAnonKey: '',
      activeWorkspace: 'Genel Operasyon',
      activeTabIndex: 0,
    );
  }

  Future<void> runInvestigation({TargetProfile? overrideTarget}) async {
    final target = (overrideTarget ?? state.draftTarget).copyWith(
      workspaceName: state.activeWorkspace,
    );
    if (!target.hasAnyIdentityInput) return;

    // Find previous session for the same target to compute Diff Summary
    InvestigationSession? previousForSameTarget;
    for (final s in state.savedSessions) {
      if (s.target.displayLabel.toLowerCase() == target.displayLabel.toLowerCase()) {
        previousForSameTarget = s;
        break;
      }
    }

    state = state.copyWith(
      draftTarget: target,
      isScanning: true,
      scanStage: 'Cihaz İçi Çoklu-Kaynak OSINT Motoru Hazırlanıyor...',
      scanProgress: 0.05,
      clearCategory: true,
    );

    final session = await reconEngine.executeFullScan(
      target: target,
      optionalSupabaseEdgeUrl: state.supabaseUrl.isNotEmpty ? state.supabaseUrl : null,
      rotateUserAgent: state.uaRotationEnabled,
      previousSessionForDiff: previousForSameTarget,
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
          occupationOrOrg: '${next.occupationOrOrg} ${pivot.value}'.trim(),
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
      activeWorkspace: session.target.workspaceName,
      activeTabIndex: 1,
    );
  }

  Future<void> clearVaultHistory() async {
    await vaultService.clearAllHistory();
    state = state.copyWith(
      savedSessions: const [],
      clearCurrentSession: true,
    );
  }

  /// On-Device Candidate Face Comparison (compare any image bytes against target face)
  Future<void> compareCandidateFaceBytes(Uint8List candidateBytes, {String? filePath}) async {
    FaceAnalysisResult? targetFace =
        state.currentSession?.faceAnalysis ?? state.draftFacePreview;
    if (targetFace == null && state.draftTarget.photoBytes != null) {
      targetFace = await faceService.analyzeFace(
        imageBytes: state.draftTarget.photoBytes!,
        filePath: state.draftTarget.photoPath,
        selectedFaceIndex: state.draftTarget.selectedFaceIndex,
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
    FaceAnalysisResult? targetFace =
        state.currentSession?.faceAnalysis ?? state.draftFacePreview;
    if (targetFace == null && state.draftTarget.photoBytes != null) {
      targetFace = await faceService.analyzeFace(
        imageBytes: state.draftTarget.photoBytes!,
        filePath: state.draftTarget.photoPath,
        selectedFaceIndex: state.draftTarget.selectedFaceIndex,
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
  final opsecService = OpsecSecurityService();
  return PanoptesNotifier(
    faceService: faceService,
    reconEngine: OsintReconEngine(
      faceService: faceService,
      opsecService: opsecService,
    ),
    vaultService: LocalVaultService(opsecService: opsecService),
    exportService: ExportService(),
    opsecService: opsecService,
  );
});

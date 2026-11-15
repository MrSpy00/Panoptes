import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../../../../core/widgets/panoptes_logo.dart';
import '../../domain/models/osint_models.dart';
import '../providers/osint_controller.dart';

class TargetInputTab extends ConsumerStatefulWidget {
  const TargetInputTab({super.key});

  @override
  ConsumerState<TargetInputTab> createState() => _TargetInputTabState();
}

class _TargetInputTabState extends ConsumerState<TargetInputTab> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _orgCtrl;
  late final TextEditingController _notesCtrl;

  static const List<String> _quickTurkishCities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Kocaeli',
    'Konya',
    'Adana',
    'Gaziantep',
    'Kars',
    'Eskişehir',
    'Trabzon',
  ];

  static const List<String> _workspaces = [
    'Genel Operasyon',
    'Red Team / OSINT',
    'Kurumsal İnceleme',
    'Biyometrik Doğrulama',
  ];

  @override
  void initState() {
    super.initState();
    final t = ref.read(panoptesProvider).draftTarget;
    _nameCtrl = TextEditingController(text: t.fullName);
    _ageCtrl = TextEditingController(text: t.birthOrAge);
    _cityCtrl = TextEditingController(text: t.cityOrHometown);
    _userCtrl = TextEditingController(text: t.username);
    _emailCtrl = TextEditingController(text: t.email);
    _phoneCtrl = TextEditingController(text: t.phone);
    _orgCtrl = TextEditingController(text: t.occupationOrOrg);
    _notesCtrl = TextEditingController(text: t.notes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _orgCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyTargetToControllers(TargetProfile t) {
    if (_nameCtrl.text != t.fullName) _nameCtrl.text = t.fullName;
    if (_ageCtrl.text != t.birthOrAge) _ageCtrl.text = t.birthOrAge;
    if (_cityCtrl.text != t.cityOrHometown) _cityCtrl.text = t.cityOrHometown;
    if (_userCtrl.text != t.username) _userCtrl.text = t.username;
    if (_emailCtrl.text != t.email) _emailCtrl.text = t.email;
    if (_phoneCtrl.text != t.phone) _phoneCtrl.text = t.phone;
    if (_orgCtrl.text != t.occupationOrOrg) _orgCtrl.text = t.occupationOrOrg;
    if (_notesCtrl.text != t.notes) _notesCtrl.text = t.notes;
  }

  void _pushDraft() {
    final notifier = ref.read(panoptesProvider.notifier);
    final current = ref.read(panoptesProvider).draftTarget;
    notifier.updateDraftTarget(
      current.copyWith(
        fullName: _nameCtrl.text,
        birthOrAge: _ageCtrl.text,
        cityOrHometown: _cityCtrl.text,
        username: _userCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        occupationOrOrg: _orgCtrl.text,
        notes: _notesCtrl.text,
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final current = ref.read(panoptesProvider).draftTarget;
      await ref.read(panoptesProvider.notifier).updateDraftTarget(
            current.copyWith(
              photoPath: picked.path,
              photoBytes: bytes,
              selectedFaceIndex: 0,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  void _clearControllers() {
    _nameCtrl.clear();
    _ageCtrl.clear();
    _cityCtrl.clear();
    _userCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _orgCtrl.clear();
    _notesCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TargetProfile>(
      panoptesProvider.select((s) => s.draftTarget),
      (prev, next) {
        _applyTargetToControllers(next);
      },
    );

    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final strings = state.strings;
    final target = state.draftTarget;
    final facePreview = state.draftFacePreview;
    final p = PanoptesPalette.of(context);

    final usernameCandidates = target.candidateUsernames;
    final emailCandidates = target.candidateEmails;
    final plateDetected = target.detectedTurkishPlate;
    final cryptoDetected = target.detectedCryptoWallet;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
      children: [
        // 1. Tactical Hero Banner with Animated Argos Panoptes Emblem
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderCrimson, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AnimatedPanoptesLogo(size: 54, showReticle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.appSubtitle,
                          style: TextStyle(
                            color: p.crimsonText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.isTr
                              ? 'Fotoğraf + kimlik pivotları ile cihaz içi çoklu yüz & OCR analizi, mutasyon motoru, çoklu kaynak WHOIS/DoH/crt.sh ve Türkiye sicil/kamu taraması.'
                              : 'On-device multi-face & OCR forensics, username/email mutation engine, multi-source WHOIS/DoH/crt.sh, and Turkish OSINT recon.',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Investigation Workspace Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _workspaces.map((ws) {
                    final active = state.activeWorkspace == ws;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => notifier.setWorkspace(ws),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? p.crimson : p.surfaceBase,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active ? p.crimson : p.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspaces_outline,
                                size: 12,
                                color: active ? Colors.white : p.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ws,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Quick Action Row: Load Sample Scenario / Clear Form / Reset Active Session
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onPressed: () async {
                  await notifier.loadSampleScenario();
                  final loaded = ref.read(panoptesProvider).draftTarget;
                  _applyTargetToControllers(loaded);
                  if (mounted) setState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_fix_high, size: 15, color: p.crimson),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        strings.isTr ? 'Örnek Senaryo' : 'Demo Target',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onPressed: () {
                  notifier.clearDraft();
                  _clearControllers();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isTr
                            ? 'Girdi formu temizlendi.'
                            : 'Input form cleared.',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cleaning_services_outlined, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        strings.clearAll,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.currentSession != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    side: BorderSide(color: p.crimson),
                  ),
                  onPressed: () {
                    notifier.clearDraftAndActiveSession();
                    _clearControllers();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          strings.isTr
                              ? 'Form ve aktif bulgu dosyası sıfırlandı.'
                              : 'Form and active dossier reset.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restart_alt, size: 15, color: p.crimsonText),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          strings.isTr ? 'Dosyayı Sıfırla' : 'Reset Dossier',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: p.crimsonText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // 2. Photo Acquisition, Multi-Face Target Selector & OCR Preview Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.center_focus_strong, color: p.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.sectionPhoto,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (target.hasPhoto)
                    InkWell(
                      onTap: () => notifier.updateDraftTarget(target.copyWith(clearPhoto: true)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          strings.isTr ? 'Kaldır' : 'Remove',
                          style: TextStyle(
                            color: p.crimsonText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: p.surfaceBase,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: target.hasPhoto ? p.crimson : p.borderStrong,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: target.photoBytes != null
                        ? Image.memory(
                            facePreview?.croppedFaceBytes ?? target.photoBytes!,
                            fit: BoxFit.cover,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 28, color: p.textMuted),
                              const SizedBox(height: 4),
                              Text(
                                'YÜZ / OCR',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _pickPhoto(ImageSource.camera),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 17, color: p.crimson),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    strings.pickCamera,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_library_outlined, size: 17),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    strings.pickGallery,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Live Biometric Preview & Multi-Face Selector
              if (facePreview != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniTag(
                            label: 'Yüz Sayısı: ${facePreview.faceCount}',
                            color: p.crimson,
                          ),
                          _MiniTag(
                            label: 'Kalite: %${facePreview.qualityScore}',
                            color: facePreview.qualityScore >= 75
                                ? PanoptesColors.statusHigh
                                : PanoptesColors.statusMedium,
                          ),
                          _MiniTag(
                            label: 'Tahmini Yaş: ${facePreview.estimatedAgeRange}',
                            color: p.crimson,
                          ),
                          _MiniTag(
                            label: facePreview.headPoseSummary,
                            color: p.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        facePreview.qualityRecommendation,
                        style: TextStyle(fontSize: 11, color: p.textSecondary),
                      ),
                      if (facePreview.allFaces.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Fotoğrafta Birden Fazla Yüz Tespit Edildi — Hedef Yüzü Seçin:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.crimsonText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: facePreview.allFaces.map((fc) {
                              final selected = fc.index == facePreview.selectedFaceIndex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => notifier.selectTargetFace(fc.index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: selected ? p.crimsonTintBg : p.surfaceCard,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: selected ? p.crimson : p.borderSubtle,
                                        width: selected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.memory(
                                            fc.croppedBytes,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Yüz #${fc.index + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: p.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Kalite %${fc.qualityScore}',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: p.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (facePreview.ocrDiscoveredPivots.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'OCR / Görsel Metinden Keşfedilen Pivotlar (Forma Aktarmak İçin Dokunun):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.crimsonText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: facePreview.ocrDiscoveredPivots.map((piv) {
                            return ActionChip(
                              label: Text(piv, style: const TextStyle(fontSize: 10.5)),
                              onPressed: () {
                                if (piv.startsWith('E-Posta:')) {
                                  _emailCtrl.text = piv.replaceFirst('E-Posta:', '').trim();
                                } else if (piv.startsWith('Kullanıcı Adı:')) {
                                  _userCtrl.text = piv
                                      .replaceFirst('Kullanıcı Adı:', '')
                                      .replaceAll('@', '')
                                      .trim();
                                } else if (piv.startsWith('Alan Adı:')) {
                                  _orgCtrl.text = piv.replaceFirst('Alan Adı:', '').trim();
                                } else if (piv.startsWith('Telefon:')) {
                                  _phoneCtrl.text = piv.replaceFirst('Telefon:', '').trim();
                                }
                                _pushDraft();
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Identity Pivot Input Form (Full-width responsive inputs with zero label clipping)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, color: p.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.isTr
                          ? 'KİMLİK, KONUM VE DİJİTAL İZ PİVOTLARI'
                          : 'IDENTITY, LOCATION & DIGITAL PIVOTS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldFullName,
                  hintText: 'Örn: Ahmet Yılmaz',
                  prefixIcon: const Icon(Icons.person_outline, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userCtrl,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldUsername,
                  hintText: 'Örn: mrspy00 (GitHub, Keybase, Telegram, Forum)',
                  prefixIcon: const Icon(Icons.alternate_email, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cityCtrl,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldCity,
                  hintText: 'İstanbul / Ankara / Kars',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickTurkishCities.map((city) {
                    final selected = _cityCtrl.text.toLowerCase().contains(city.toLowerCase());
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          _cityCtrl.text = city;
                          _pushDraft();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? p.crimson : p.surfaceBase,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? p.crimson : p.borderSubtle,
                            ),
                          ),
                          child: Text(
                            city,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : p.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ageCtrl,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldBirthAge,
                  hintText: 'Örn: 1996 / 26-30',
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldEmail,
                  hintText: 'isim@alanadi.com',
                  prefixIcon: const Icon(Icons.mail_outline, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldPhone,
                  hintText: '+90 5xx xxx xx xx',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgCtrl,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldOccupation,
                  hintText: 'Şirket / Üniversite / Domain (aegissoft.com.tr)',
                  prefixIcon: const Icon(Icons.business_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                onChanged: (_) {
                  _pushDraft();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: strings.fieldNotes,
                  hintText: 'Anahtar kelimeler, 34 ABC 123 plaka veya BTC/ETH cüzdan adresi',
                  prefixIcon: const Icon(Icons.notes_outlined, size: 19),
                ),
              ),

              // Live Mutation & Detector Preview Chips
              if (usernameCandidates.isNotEmpty ||
                  emailCandidates.isNotEmpty ||
                  plateDetected != null ||
                  cryptoDetected != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OTOMATİK TÜRETİLEN ÇAPRAZ SORGU ADAYLARI:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: p.crimsonText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (usernameCandidates.isNotEmpty)
                        Text(
                          '• Nick Mutasyonları (${usernameCandidates.length}): ${usernameCandidates.take(6).map((u) => "@$u").join(", ")}',
                          style: TextStyle(fontSize: 11, color: p.textSecondary),
                        ),
                      if (emailCandidates.isNotEmpty)
                        Text(
                          '• E-Posta Tahminleri (${emailCandidates.length}): ${emailCandidates.take(3).join(", ")}',
                          style: TextStyle(fontSize: 11, color: p.textSecondary),
                        ),
                      if (target.candidateDomains.isNotEmpty)
                        Text(
                          '• Çoklu-Kaynak WHOIS / RDAP / DoH / crt.sh Hedefi: ${target.candidateDomains.join(", ")}',
                          style: TextStyle(fontSize: 11, color: p.textSecondary),
                        ),
                      if (plateDetected != null)
                        Text(
                          '• Araç Plakası Algılandı: ${plateDetected.$1} (${plateDetected.$2})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PanoptesColors.statusHigh,
                          ),
                        ),
                      if (cryptoDetected != null)
                        Text(
                          '• Kripto Cüzdan Algılandı: [${cryptoDetected.$1}] ${cryptoDetected.$2}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PanoptesColors.statusHigh,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Primary Scan Trigger & Live Progress Telemetry
        if (state.isScanning)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.crimson, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: p.crimson,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.scanningActive,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: p.crimsonText,
                        ),
                      ),
                    ),
                    Text(
                      '%${(state.scanProgress * 100).round()}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: state.scanProgress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  color: p.crimson,
                  backgroundColor: p.surfaceBase,
                ),
                const SizedBox(height: 8),
                Text(
                  state.scanStage,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
              onPressed: () {
                _pushDraft();
                if (!ref.read(panoptesProvider).draftTarget.hasAnyIdentityInput) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isTr
                            ? 'Lütfen en az bir fotoğraf veya kimlik bilgisi girin ya da "Örnek Senaryo" butonuna dokunun.'
                            : 'Please provide at least one photo or identity field, or tap "Demo Target".',
                      ),
                    ),
                  );
                  return;
                }
                notifier.runInvestigation();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      strings.launchScan,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

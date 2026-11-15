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
      ref.read(panoptesProvider.notifier).updateDraftTarget(
            current.copyWith(
              photoPath: picked.path,
              photoBytes: bytes,
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

  @override
  Widget build(BuildContext context) {
    // Safely listen to external draftTarget changes outside build mutation
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
    final p = PanoptesPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
      children: [
        // 1. Tactical Hero Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderCrimson, width: 1),
          ),
          child: Row(
            children: [
              const PanoptesLogo(size: 54, showReticle: true),
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
                        letterSpacing: 0.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.isTr
                          ? 'Fotoğraf + kimlik pivotları ile cihaz içi 192-D yüz doğrulama, Türkiye sicil/forum/akademik taraması ve çok katmanlı ters görsel istihbarat.'
                          : 'On-device 192-D biometric face verification, Turkish & global OSINT recon, and multi-engine reverse visual pipeline.',
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
        ),
        const SizedBox(height: 10),

        // Quick Action Row: Load Sample Scenario / Clear
        Row(
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton(
                onPressed: () {
                  notifier.loadSampleScenario();
                  final loaded = ref.read(panoptesProvider).draftTarget;
                  _applyTargetToControllers(loaded);
                  setState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_fix_high, size: 16, color: p.crimson),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        strings.loadSampleTarget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: () {
                  notifier.clearDraft();
                  _nameCtrl.clear();
                  _ageCtrl.clear();
                  _cityCtrl.clear();
                  _userCtrl.clear();
                  _emailCtrl.clear();
                  _phoneCtrl.clear();
                  _orgCtrl.clear();
                  _notesCtrl.clear();
                  setState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restart_alt, size: 16),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        strings.clearAll,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Photo Acquisition & Biometric Preview Card
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
                        letterSpacing: 0.5,
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
                        ? Image.memory(target.photoBytes!, fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 28, color: p.textMuted),
                              const SizedBox(height: 4),
                              Text(
                                'YÜZ / EXIF',
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Identity Pivot Input Form (Full-width responsive inputs so labels never clip)
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
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldFullName,
                  hintText: 'Örn: Ahmet Yılmaz',
                  prefixIcon: const Icon(Icons.person_outline, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userCtrl,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldUsername,
                  hintText: 'Örn: mrspy00 (Maigret / Sherlock / Forum)',
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
              // Overflow-proof Horizontal Turkish City Selector
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
                onChanged: (_) => _pushDraft(),
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
                onChanged: (_) => _pushDraft(),
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
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldPhone,
                  hintText: '+90 5xx xxx xx xx',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgCtrl,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldOccupation,
                  hintText: 'Şirket / Üniversite / Meslek (Ticaret Sicili & YÖK)',
                  prefixIcon: const Icon(Icons.business_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldNotes,
                  hintText: 'Ek anahtar kelimeler, eski nickler veya bağlam notları',
                  prefixIcon: const Icon(Icons.notes_outlined, size: 19),
                ),
              ),
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
                            ? 'Lütfen en az bir fotoğraf veya kimlik bilgisi girin ya da "Örnek Senaryo Yükle" butonuna dokunun.'
                            : 'Please provide at least one photo or identity field, or tap "Load Demo Target".',
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

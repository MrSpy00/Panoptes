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

  void _syncControllersFromTarget(TargetProfile t) {
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
    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final strings = state.strings;
    final target = state.draftTarget;

    _syncControllersFromTarget(target);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        // 1. Tactical Hero Banner + Quick Demo Loader
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderCrimson, width: 1),
          ),
          child: Row(
            children: [
              const PanoptesLogo(size: 56, showReticle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.appSubtitle,
                      style: const TextStyle(
                        color: PanoptesColors.crimsonBright,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.isTr
                          ? 'Fotoğraf + kimlik pivotları ile cihaz içi yüz doğrulama, Türkiye sicil/forum/akademik taraması ve çok katmanlı ters görsel istihbarat.'
                          : 'On-device biometric face verification, Turkish & global OSINT recon, and multi-engine reverse visual pipeline.',
                      style: const TextStyle(
                        color: PanoptesColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Action Row: Load Sample Scenario / Clear
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  notifier.loadSampleScenario();
                },
                icon: const Icon(Icons.auto_fix_high, size: 17, color: PanoptesColors.crimson),
                label: Text(strings.loadSampleTarget),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
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
              },
              icon: const Icon(Icons.restart_alt, size: 17),
              label: Text(strings.clearAll),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Photo Acquisition & Biometric Preview Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.center_focus_strong, color: PanoptesColors.crimson, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        strings.sectionPhoto,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  if (target.hasPhoto)
                    InkWell(
                      onTap: () => notifier.updateDraftTarget(target.copyWith(clearPhoto: true)),
                      child: const Text(
                        'Görseli Kaldır',
                        style: TextStyle(color: PanoptesColors.crimsonBright, fontSize: 11.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: PanoptesColors.surfaceBase,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: target.hasPhoto ? PanoptesColors.crimson : PanoptesColors.borderStrong,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: target.photoBytes != null
                        ? Image.memory(target.photoBytes!, fit: BoxFit.cover)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 30, color: PanoptesColors.textMuted),
                              SizedBox(height: 4),
                              Text(
                                'YÜZ / EXIF',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontFamily: 'monospace',
                                  color: PanoptesColors.textMuted,
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
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined, size: 18, color: PanoptesColors.crimson),
                            label: Text(strings.pickCamera),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: Text(strings.pickGallery),
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
        const SizedBox(height: 14),

        // 3. Identity Pivot Input Form
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.badge_outlined, color: PanoptesColors.crimson, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'KİMLİK, KONUM VE DİJİTAL İZ PİVOTLARI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      onChanged: (_) => _pushDraft(),
                      decoration: InputDecoration(
                        labelText: strings.fieldBirthAge,
                        hintText: '1994 / 28-32',
                        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      onChanged: (_) => _pushDraft(),
                      decoration: InputDecoration(
                        labelText: strings.fieldCity,
                        hintText: 'İstanbul / Kars',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 19),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick Turkish City Selector
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickTurkishCities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final city = _quickTurkishCities[index];
                    final selected = _cityCtrl.text.toLowerCase().contains(city.toLowerCase());
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        _cityCtrl.text = city;
                        _pushDraft();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? PanoptesColors.burgundyDeep : PanoptesColors.surfaceBase,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? PanoptesColors.crimson : PanoptesColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          city,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : PanoptesColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userCtrl,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldUsername,
                  hintText: 'Örn: mrspy00 (Maigret / Sherlock / Forum taraması)',
                  prefixIcon: const Icon(Icons.alternate_email, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _pushDraft(),
                      decoration: InputDecoration(
                        labelText: strings.fieldEmail,
                        hintText: 'isim@alanadi.com',
                        prefixIcon: const Icon(Icons.mail_outline, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => _pushDraft(),
                      decoration: InputDecoration(
                        labelText: strings.fieldPhone,
                        hintText: '+90 5xx xxx xx xx',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgCtrl,
                onChanged: (_) => _pushDraft(),
                decoration: InputDecoration(
                  labelText: strings.fieldOccupation,
                  hintText: 'Şirket / Üniversite / Meslek (Ticaret Sicili & YÖK Akademik)',
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
                  hintText: 'Ek anahtar kelimeler, eski nickler, plaka kodu veya bağlam notları',
                  prefixIcon: const Icon(Icons.notes_outlined, size: 19),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Primary Scan Trigger & Live Progress Telemetry
        if (state.isScanning)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PanoptesColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PanoptesColors.crimson, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: PanoptesColors.crimson,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.scanningActive,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: PanoptesColors.crimsonBright,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      '%${(state.scanProgress * 100).round()}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: state.scanProgress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  color: PanoptesColors.crimson,
                  backgroundColor: PanoptesColors.surfaceBase,
                ),
                const SizedBox(height: 8),
                Text(
                  state.scanStage,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: PanoptesColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                _pushDraft();
                if (!ref.read(panoptesProvider).draftTarget.hasAnyIdentityInput) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Lütfen en az bir fotoğraf veya kimlik bilgisi girin ya da "Örnek Senaryo Yükle" butonuna dokunun.',
                      ),
                    ),
                  );
                  return;
                }
                notifier.runInvestigation();
              },
              icon: const Icon(Icons.radar, size: 22),
              label: Text(strings.launchScan),
            ),
          ),
      ],
    );
  }
}

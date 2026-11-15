import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../providers/osint_controller.dart';

class FaceLabTab extends ConsumerStatefulWidget {
  const FaceLabTab({super.key});

  @override
  ConsumerState<FaceLabTab> createState() => _FaceLabTabState();
}

class _FaceLabTabState extends ConsumerState<FaceLabTab> {
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickCandidateFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(panoptesProvider.notifier)
        .compareCandidateFaceBytes(bytes, filePath: file.path);
  }

  Future<void> _pickCandidateFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(panoptesProvider.notifier)
        .compareCandidateFaceBytes(bytes, filePath: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final targetFace = state.currentSession?.faceAnalysis;
    final exif = state.currentSession?.exifReport;
    final comp = state.faceComparisonResult;
    final candFace = state.candidateFaceResult;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // 1. Target Biometric Profile Card
        Container(
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderCrimson, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.face_retouching_natural, color: PanoptesColors.crimson, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'ON-DEVICE BİYOMETRİK YÜZ MOTORU',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PanoptesColors.burgundyAbyss,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: PanoptesColors.crimson, width: 0.8),
                    ),
                    child: const Text(
                      '192-D COSINE + dHASH64',
                      style: TextStyle(
                        color: PanoptesColors.crimsonBright,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (targetFace == null) ...[
                const Text(
                  'Henüz biyometrik hedef fotoğrafı analiz edilmedi. Hedef sekmesinden fotoğraf seçin veya aşağıdaki butonla örnek biyometrik profili yükleyin.',
                  style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    notifier.loadSampleScenario();
                    await notifier.runInvestigation();
                  },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Örnek Biyometrik Hedef Yükle & Analiz Et'),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetFace.croppedFaceBytes != null)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PanoptesColors.crimson, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          targetFace.croppedFaceBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetFace.detectionEngine,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: PanoptesColors.crimsonBright,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Yüz Sayısı: ${targetFace.faceCount} • Kalite: %${targetFace.qualityScore}\n'
                            'dHash: ${targetFace.dHashHex}\n'
                            'aHash: ${targetFace.aHashHex}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: PanoptesColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PanoptesColors.surfaceBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PanoptesColors.borderSubtle),
                  ),
                  child: Text(
                    '192-D Vektör [0..11]: [${targetFace.embedding192d.take(12).map((v) => v.toStringAsFixed(3)).join(", ")} ...]',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: PanoptesColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. On-Device Candidate Face Comparison Studio
        Container(
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.compare_arrows, color: PanoptesColors.crimson, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'ADAY GÖRSEL YÜZ DOĞRULAMA (LOCAL FACE VERIFICATION)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Yandex / Google Lens / TinEye ters görsel aramasından bulduğunuz bir fotoğrafı galeriden seçin veya görsel URL adresini yapıştırarak hedef yüz embedding vektörüyle cihaz içinde karşılaştırın.',
                style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCandidateFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Aday Fotoğraf Seç'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCandidateFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Kameradan Çek'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final demoCandidate = notifier.faceService.generateDemoPortraitBytes(variant: 1);
                    await notifier.compareCandidateFaceBytes(demoCandidate);
                  },
                  icon: const Icon(Icons.science_outlined, size: 17, color: PanoptesColors.crimson),
                  label: const Text('Sentetik Aday Portre ile Cihaz İçi Eşleşme Testi Çalıştır'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Aday Görsel URL (https://...)',
                        hintText: 'Ters görsel aramadan bulunan fotoğraf URL\'si',
                        prefixIcon: Icon(Icons.link, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: state.isComparingFace
                        ? null
                        : () async {
                            if (_urlController.text.trim().isEmpty) return;
                            final ok = await notifier.compareCandidateFaceUrl(_urlController.text);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Görsel indirilemedi veya hedef fotoğraf tanımlı değil.'),
                                ),
                              );
                            }
                          },
                    child: state.isComparingFace
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Doğrula'),
                  ),
                ],
              ),

              if (comp != null && candFace != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PanoptesColors.surfaceBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: comp.combinedScore >= 75
                          ? PanoptesColors.statusHigh
                          : PanoptesColors.crimson,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (candFace.croppedFaceBytes != null)
                            Container(
                              width: 58,
                              height: 58,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: PanoptesColors.borderStrong),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.memory(
                                candFace.croppedFaceBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BİYOMETRİK SKOR: %${comp.combinedScore}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: comp.combinedScore >= 75
                                        ? PanoptesColors.statusHigh
                                        : PanoptesColors.crimsonBright,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  comp.verdict,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MetricRow(
                        label: '192-D Cosine Benzerliği',
                        value: '%${(comp.cosineSimilarity * 100).toStringAsFixed(1)}',
                      ),
                      _MetricRow(
                        label: '64-bit dHash Yapısal Benzerlik',
                        value: '%${(comp.dHashSimilarity * 100).toStringAsFixed(1)}',
                      ),
                      _MetricRow(
                        label: '24-Bin Histogram Kesişimi',
                        value: '%${(comp.histogramSimilarity * 100).toStringAsFixed(1)}',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. EXIF & Binary Forensics Inspector
        if (exif != null)
          Container(
            decoration: BoxDecoration(
              color: PanoptesColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PanoptesColors.borderSubtle, width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fingerprint, color: PanoptesColors.crimson, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'EXIF / JFIF ADLİ BİLİŞİM DENETÇİSİ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetricRow(label: 'SHA-256 Özeti', value: '${exif.sha256Hash.substring(0, 24)}...'),
                _MetricRow(label: 'Çözünürlük', value: '${exif.width} x ${exif.height} px'),
                _MetricRow(
                  label: 'Dosya Boyutu',
                  value: '${(exif.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                ),
                if (exif.cameraMake != null || exif.cameraModel != null)
                  _MetricRow(
                    label: 'Kamera / Cihaz',
                    value: [exif.cameraMake, exif.cameraModel].whereType<String>().join(' '),
                  ),
                if (exif.dateTimeOriginal != null)
                  _MetricRow(label: 'Orijinal Tarih', value: exif.dateTimeOriginal!),
                if (exif.hasGps)
                  _MetricRow(
                    label: 'GPS Koordinatları',
                    value: '${exif.gpsLatitude!.toStringAsFixed(5)}, ${exif.gpsLongitude!.toStringAsFixed(5)}',
                  ),
                const SizedBox(height: 8),
                ...exif.forensicAlerts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $a',
                      style: const TextStyle(
                        color: PanoptesColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: PanoptesColors.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

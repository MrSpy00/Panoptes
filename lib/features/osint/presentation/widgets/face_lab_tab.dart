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
    final targetFace = state.currentSession?.faceAnalysis ?? state.draftFacePreview;
    final exif = state.currentSession?.exifReport;
    final comp = state.faceComparisonResult;
    final candFace = state.candidateFaceResult;
    final p = PanoptesPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        // 1. Target Biometric Profile, Multi-Face & OCR Card
        Container(
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderCrimson, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.face_retouching_natural, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ON-DEVICE BİYOMETRİK YÜZ, YAŞ & OCR MOTORU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.crimsonTintBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: PanoptesColors.crimson, width: 0.8),
                    ),
                    child: Text(
                      '192-D + OCR',
                      style: TextStyle(
                        color: p.crimsonText,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (targetFace == null) ...[
                Text(
                  'Henüz biyometrik hedef fotoğrafı analiz edilmedi. Hedef sekmesinden fotoğraf seçin veya aşağıdaki butonla örnek biyometrik profili yükleyin.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!state.draftTarget.hasPhoto) {
                        await notifier.loadSampleScenario();
                      }
                      await notifier.runInvestigation();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            state.draftTarget.hasPhoto
                                ? 'Seçili Fotoğrafı Şimdi Analiz Et'
                                : 'Örnek Biyometrik Hedef Yükle & Analiz Et',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetFace.croppedFaceBytes != null)
                      Container(
                        width: 84,
                        height: 84,
                        margin: const EdgeInsets.only(right: 12),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetFace.detectionEngine,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: p.crimsonText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tespit Edilen Yüz: ${targetFace.faceCount} (Aktif: #${targetFace.selectedFaceIndex + 1})\n'
                            'Kalite: %${targetFace.qualityScore} • Yaş: ${targetFace.estimatedAgeRange}\n'
                            'Poz: ${targetFace.headPoseSummary} • İfade: ${targetFace.expressionSummary}\n'
                            'dHash: ${targetFace.dHashHex} • aHash: ${targetFace.aHashHex}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: p.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: Text(
                    'Kalite & Auto Re-Crop Önerisi: ${targetFace.qualityRecommendation}',
                    style: TextStyle(fontSize: 11.5, color: p.textPrimary),
                  ),
                ),
                // Multi-Face Target Selector (if >1 face detected)
                if (targetFace.allFaces.length > 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'ÇOKLU YÜZ SEÇİMİ (HANGİ YÜZ HEDEF?):',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: p.crimsonText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: targetFace.allFaces.map((fc) {
                        final selected = fc.index == targetFace.selectedFaceIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => notifier.selectTargetFace(fc.index),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: selected ? p.crimsonTintBg : p.surfaceBase,
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
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Yüz #${fc.index + 1}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Kalite %${fc.qualityScore} • ${fc.estimatedAgeRange}',
                                        style: TextStyle(
                                          fontSize: 10,
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
                // OCR & Screenshot Text Extraction
                if (targetFace.ocrExtractedLines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surfaceBase,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.borderStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÖRSEL / EKRAN GÖRÜNTÜSÜ OCR METİN ÇIKARIMI:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: p.crimsonText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...targetFace.ocrExtractedLines.take(6).map(
                              (line) => Text(
                                '• $line',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                        if (targetFace.ocrDiscoveredPivots.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Keşfedilen OCR Pivotları: ${targetFace.ocrDiscoveredPivots.join(" | ")}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PanoptesColors.statusHigh,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: SelectableText(
                    '192-D Vektör (İlk 8 Boyut): [${targetFace.embedding192d.take(8).map((v) => v.toStringAsFixed(3)).join(", ")}]',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. On-Device Candidate Face Comparison Studio
        Container(
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ADAY GÖRSEL YÜZ & pHASH KÜMELEME DOĞRULAMASI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Yandex / Google Lens / TinEye ters görsel aramasından bulduğunuz fotoğrafı galeriden seçin veya URL adresini yapıştırarak hedef yüz embedding vektörü ve algısal hash (dHash/aHash) ile cihaz içinde karşılaştırın.',
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: _pickCandidateFromGallery,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 17),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Aday Seç',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: _pickCandidateFromCamera,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 17),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Kamera',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onPressed: () async {
                    final demoCandidate = notifier.faceService.generateDemoPortraitBytes(variant: 1);
                    await notifier.compareCandidateFaceBytes(demoCandidate);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.science_outlined, size: 17, color: PanoptesColors.crimson),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Sentetik Aday Portre ile Cihaz İçi Eşleşme Testi',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: TextStyle(fontSize: 13, color: p.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Aday Görsel URL Adresi',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.link, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
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
                        : const Text('Doğrula', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              if (comp != null && candFace != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
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
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: p.borderStrong),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: comp.combinedScore >= 75
                                        ? PanoptesColors.statusHigh
                                        : PanoptesColors.crimson,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  comp.verdict,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.textPrimary,
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
                        label: '64-bit dHash Benzerliği',
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
        const SizedBox(height: 14),

        // 3. EXIF & Binary Forensics Inspector (Full SHA-256 without truncation)
        if (exif != null)
          Container(
            decoration: BoxDecoration(
              color: p.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.borderSubtle, width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fingerprint, color: PanoptesColors.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EXIF / JFIF ADLİ BİLİŞİM DENETÇİSİ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetricRow(label: 'SHA-256 Özeti', value: exif.sha256Hash),
                _MetricRow(label: 'MD5 Özeti', value: exif.md5Hash),
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
                    value:
                        '${exif.gpsLatitude!.toStringAsFixed(5)}, ${exif.gpsLongitude!.toStringAsFixed(5)}',
                  ),
                const SizedBox(height: 8),
                ...exif.forensicAlerts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $a',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11.5,
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
    final p = PanoptesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: p.textSecondary, fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

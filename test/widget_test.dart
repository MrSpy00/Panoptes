import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panoptes/features/osint/domain/models/osint_models.dart';
import 'package:panoptes/features/osint/services/export_service.dart';
import 'package:panoptes/features/osint/services/face_forensics_service.dart';
import 'package:panoptes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'panoptes_ethics_accepted_v1': true,
    });
  });

  test('On-device FaceForensicsService extracts 192-D embedding, dHash64, and verifies similarity', () async {
    final service = FaceForensicsService();
    final bytesA = service.generateDemoPortraitBytes(variant: 0);
    final bytesB = service.generateDemoPortraitBytes(variant: 1);

    final faceA = await service.analyzeFace(imageBytes: bytesA);
    final faceB = await service.analyzeFace(imageBytes: bytesB);

    expect(faceA.faceDetected, isTrue);
    expect(faceA.embedding192d.length, equals(192));
    expect(faceA.dHashHex.length, equals(16));
    expect(faceA.aHashHex.length, equals(16));

    final comparison = faceA.compareWith(faceB);
    expect(comparison.combinedScore, greaterThan(80.0));

    final exif = await service.extractExifForensics(bytesA);
    expect(exif.sha256Hash.length, equals(64));
    expect(exif.width, equals(240));
    expect(exif.height, equals(240));
  });

  test('TargetProfile normalizes Turkish characters into candidate usernames', () {
    const profile = TargetProfile(
      fullName: 'Çağrı Şahin',
      username: '@MrSpy00',
      email: 'cagri.sahin@aegissoft.com.tr',
    );
    final candidates = profile.candidateUsernames;
    expect(candidates, contains('mrspy00'));
    expect(candidates, contains('cagri.sahin'));
    expect(candidates, contains('cagrisahin'));
  });

  test('ExportService generates valid Markdown, JSON, and PDF dossiers', () async {
    final export = ExportService();
    final session = InvestigationSession(
      id: 'panoptes_test_1',
      createdAt: DateTime(2026, 11, 15, 18, 0),
      target: const TargetProfile(
        fullName: 'MrSpy Aegis',
        cityOrHometown: 'İstanbul',
        username: 'MrSpy00',
      ),
      findings: [
        OsintFinding(
          id: 'f1',
          category: OsintCategory.socialUsername,
          sourceName: 'GitHub',
          title: 'GitHub Profile @MrSpy00',
          subtitle: 'https://github.com/MrSpy00',
          snippet: 'Verified active GitHub profile.',
          url: 'https://github.com/MrSpy00',
          archiveUrl: 'https://web.archive.org/web/*/https://github.com/MrSpy00',
          confidenceScore: 95,
          matchedFields: const ['Username'],
          fallbackLayer: 'Birincil',
          timestamp: DateTime(2026, 11, 15),
          isLiveVerified: true,
        ),
      ],
      pivots: const [],
      timeline: const [],
      graphNodes: const [],
      graphEdges: const [],
      executionLogs: const ['[18:00:00] Test log'],
    );

    final md = export.generateMarkdownReport(session);
    expect(md, contains('PANOPTES'));
    expect(md, contains('MrSpy Aegis'));

    final jsonStr = export.generateJsonReport(session);
    expect(jsonStr, contains('"id": "panoptes_test_1"'));

    final pdfBytes = await export.generatePdfBytes(session);
    expect(pdfBytes.length, greaterThan(500));
  });

  testWidgets('PanoptesApp renders shell, loads demo target, and navigates tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PanoptesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PANOPTES'), findsOneWidget);
    expect(find.text('Örnek Senaryo Yükle'), findsOneWidget);

    await tester.tap(find.text('Örnek Senaryo Yükle'));
    await tester.pumpAndSettle();

    expect(find.text('MrSpy Aegis'), findsOneWidget);
  });
}

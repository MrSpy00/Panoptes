import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panoptes/features/osint/domain/models/osint_models.dart';
import 'package:panoptes/features/osint/presentation/providers/osint_controller.dart';
import 'package:panoptes/features/osint/services/export_service.dart';
import 'package:panoptes/features/osint/services/face_forensics_service.dart';
import 'package:panoptes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  testWidgets(
    'PanoptesApp renders ethics modal, all 5 tabs, Dark/Light theme & TR/EN flags on narrow 360x780 screen with zero overflow',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'panoptes_ethics_accepted_v1': false,
      });

      // Set narrow mobile viewport (360dp x 780dp) with 1.15x text scaling
      tester.view.physicalSize = const Size(360 * 3.0, 780 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.15),
            ),
            child: PanoptesApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Ethics Consent overlay renders cleanly without overflow and accepts
      expect(find.text('Şartları Okudum ve Kabul Ediyorum'), findsOneWidget);
      await tester.tap(find.text('Şartları Okudum ve Kabul Ediyorum'));
      await tester.pumpAndSettle();

      // 2. Load Sample Scenario on Target Tab
      expect(find.text('PANOPTES'), findsOneWidget);
      await tester.tap(find.text('Örnek Senaryo Yükle'));
      await tester.pumpAndSettle();
      expect(find.text('MrSpy Aegis'), findsOneWidget);

      // 3. Populate a full investigation session and verify all 5 tabs in Dark & Light mode
      final notifier = container.read(panoptesProvider.notifier);
      await notifier.runInvestigation();
      await tester.pumpAndSettle();

      for (int tab = 0; tab < 5; tab++) {
        notifier.setActiveTab(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Toggle to Light Theme on this tab
        await notifier.toggleTheme();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Toggle Language TR -> EN on this tab
        await notifier.toggleLanguage();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Toggle back to Dark Theme and TR
        await notifier.toggleTheme();
        await notifier.toggleLanguage();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}

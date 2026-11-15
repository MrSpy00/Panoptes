import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panoptes/core/security/opsec_security_service.dart';
import 'package:panoptes/features/osint/domain/models/osint_models.dart';
import 'package:panoptes/features/osint/presentation/providers/osint_controller.dart';
import 'package:panoptes/features/osint/services/export_service.dart';
import 'package:panoptes/features/osint/services/face_forensics_service.dart';
import 'package:panoptes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('On-device FaceForensicsService extracts 192-D embedding, dHash64, age range, and verifies similarity', () async {
    final service = FaceForensicsService();
    final bytesA = service.generateDemoPortraitBytes(variant: 0);
    final bytesB = service.generateDemoPortraitBytes(variant: 1);

    final faceA = await service.analyzeFace(imageBytes: bytesA);
    final faceB = await service.analyzeFace(imageBytes: bytesB);

    expect(faceA.faceDetected, isTrue);
    expect(faceA.embedding192d.length, equals(192));
    expect(faceA.dHashHex.length, equals(16));
    expect(faceA.aHashHex.length, equals(16));
    expect(faceA.estimatedAgeRange, isNotEmpty);
    expect(faceA.qualityRecommendation, isNotEmpty);

    final comparison = faceA.compareWith(faceB);
    expect(comparison.combinedScore, greaterThan(80.0));

    final exif = await service.extractExifForensics(bytesA);
    expect(exif.sha256Hash.length, equals(64));
    expect(exif.width, equals(240));
    expect(exif.height, equals(240));
  });

  test('TargetProfile Mutation Engines generate username, email, phone, plate, and crypto candidates', () {
    const profile = TargetProfile(
      fullName: 'Çağrı Şahin',
      birthOrAge: '1998',
      username: '@MrSpy00',
      email: 'cagri.sahin@aegissoft.com.tr',
      phone: '+90 532 410 00 00',
      notes: 'Araç: 34 ABC 123, Cüzdan: 0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
    );
    final usernames = profile.candidateUsernames;
    expect(usernames, contains('mrspy00'));
    expect(usernames, contains('cagri.sahin'));
    expect(usernames, contains('cagrisahin'));
    expect(usernames, contains('cagrisahin98'));

    final emails = profile.candidateEmails;
    expect(emails, contains('cagri.sahin@aegissoft.com.tr'));
    expect(emails, contains('cagrisahin@gmail.com'));

    final phones = profile.candidatePhoneFormats;
    expect(phones, contains('05324100000'));
    expect(phones, contains('+905324100000'));

    final plate = profile.detectedTurkishPlate;
    expect(plate, isNotNull);
    expect(plate!.$1, equals('34 ABC 123'));
    expect(plate.$2, contains('İstanbul'));

    final wallet = profile.detectedCryptoWallet;
    expect(wallet, isNotNull);
    expect(wallet!.$1, contains('Ethereum'));
  });

  test('OpsecSecurityService encrypts and authenticates local vault JSON payloads', () {
    final opsec = OpsecSecurityService();
    const rawJson = '{"id":"PAN-123","target":"MrSpy"}';
    final encrypted = opsec.encryptVaultJson(rawJson);
    expect(encrypted.startsWith('PV2:'), isTrue);
    expect(encrypted, isNot(contains('MrSpy')));

    final decrypted = opsec.decryptVaultJson(encrypted);
    expect(decrypted, equals(rawJson));
  });

  test('ExportService generates valid Markdown, HTML, JSON, and PDF dossiers across templates', () async {
    final export = ExportService();
    final session = InvestigationSession(
      id: 'panoptes_test_1',
      createdAt: DateTime(2026, 11, 15, 18, 0),
      target: const TargetProfile(
        fullName: 'MrSpy Aegis',
        cityOrHometown: 'İstanbul',
        username: 'MrSpy00',
      ),
      executiveFacts: const ['DOĞRULANMIŞ GITHUB HESABI: @MrSpy00'],
      findings: [
        OsintFinding(
          id: 'f1',
          category: OsintCategory.usernameAndSocial,
          sourceName: 'GitHub REST API (Canlı)',
          title: 'GitHub Profile @MrSpy00',
          snippet: 'Verified active GitHub profile.',
          extractedData: const {'Kullanıcı Adı': '@MrSpy00', 'Konum': 'Türkiye'},
          url: 'https://github.com/MrSpy00',
          confidenceScore: 95,
          scoreBreakdown: 'İsim %42 • Kaynak %25',
          fallbackLayer: 'Birincil',
          isLiveVerified: true,
        ),
      ],
      pivots: const [],
      timeline: const [],
      graphNodes: const [],
      graphEdges: const [],
      executionLogs: const ['[18:00:00] Test log'],
    );

    final md = export.generateMarkdownReport(session, template: ReportTemplate.legalKvkk);
    expect(md, contains('PANOPTES v2.0'));
    expect(md, contains('KVKK'));
    expect(md, contains('MrSpy Aegis'));

    final html = export.generateHtmlReport(session);
    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('@MrSpy00'));

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
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Verify Ethics Consent overlay renders cleanly without overflow and accepts
      final ethicsBtn = find.text('Şartları Okudum ve Kabul Ediyorum');
      expect(ethicsBtn, findsOneWidget);
      await tester.ensureVisible(ethicsBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(ethicsBtn);
      await tester.pump(const Duration(milliseconds: 400));

      // 2. Load Sample Scenario on Target Tab
      expect(find.text('PANOPTES'), findsOneWidget);
      final notifier = container.read(panoptesProvider.notifier);
      await notifier.loadSampleScenario();
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(panoptesProvider).draftTarget.fullName, 'MrSpy Aegis');
      await tester.drag(find.byType(ListView).first, const Offset(0, -360));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('MrSpy Aegis'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 3. Populate a full investigation session and verify all 5 tabs in Dark & Light mode
      await notifier.runInvestigation();
      await tester.pump(const Duration(milliseconds: 400));

      for (int tab = 0; tab < 5; tab++) {
        notifier.setActiveTab(tab);
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // Toggle to Light Theme on this tab
        await notifier.toggleTheme();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // Toggle Language TR -> EN on this tab
        await notifier.toggleLanguage();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // Toggle back to Dark Theme and TR
        await notifier.toggleTheme();
        await notifier.toggleLanguage();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

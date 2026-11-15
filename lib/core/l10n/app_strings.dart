enum AppLanguage { tr, en }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isTr => lang == AppLanguage.tr;

  String get appTitle => 'PANOPTES';
  String get appSubtitle => isTr
      ? 'BİYOMETRİK & KİMLİK OSINT'
      : 'BIOMETRIC & IDENTITY OSINT';

  // Concise Navigation Tabs (Fits 360dp screens without ellipsis)
  String get navAcquire => isTr ? 'Hedef' : 'Target';
  String get navDossier => isTr ? 'Bulgular' : 'Findings';
  String get navFaceLab => isTr ? 'Yüz Lab' : 'Face Lab';
  String get navGraph => isTr ? 'Grafik' : 'Graph';
  String get navVault => isTr ? 'Kasa' : 'Vault';

  // Ethics & Legal Gate
  String get ethicsTitle => isTr
      ? 'ETİK KULLANIM, KVKK VE YASAL SORUMLULUK BİLDİRİMİ'
      : 'ETHICAL USE, KVKK & LEGAL RESPONSIBILITY NOTICE';
  String get ethicsBody => isTr
      ? '1. Sadece Herkese Açık Kaynaklar (OSINT): Panoptes yalnızca halka açık web sayfaları, arama motoru indeksleri, açık ticaret sicil/akademik kayıtlar ve cihaz içi görsel analiz yöntemlerini kullanır.\n\n'
          '2. Cihaz İçi Gizlilik (Privacy-by-Design): Yüz embedding vektörleri (192-D), EXIF verileri ve sorgu geçmişi varsayılan olarak yalnızca telefonunuzda yerel olarak işlenir ve şifreli saklanır.\n\n'
          '3. Yasal Sorumluluk (KVKK / GDPR): 6698 sayılı KVKK ve ilgili mevzuat uyarınca kişisel verilerin işlenmesi, saklanması ve kullanım amacı tamamen kullanıcının kendi hukuki sorumluluğundadır.'
      : '1. Public Sources Only (OSINT): Panoptes strictly queries publicly accessible web indexes, public registries, and on-device visual analysis pipelines.\n\n'
          '2. Privacy-by-Design: Biometric 192-D face embeddings, EXIF metadata, and query logs remain encrypted on your device unless you explicitly configure a remote sync server.\n\n'
          '3. Legal Liability (KVKK / GDPR): Processing of personal data is the sole legal responsibility of the operator. Use only for authorized security research and OSINT investigations.';
  String get ethicsAccept => isTr
      ? 'Şartları Okudum ve Kabul Ediyorum'
      : 'I Have Read & Accept the Terms';

  // Input Screen
  String get sectionPhoto => isTr
      ? 'HEDEF FOTOĞRAF, ÇOKLU YÜZ & OCR HATTI'
      : 'TARGET PHOTO, MULTI-FACE & OCR PIPELINE';
  String get pickCamera => isTr ? 'Kamera ile Çek' : 'Capture Camera';
  String get pickGallery => isTr ? 'Galeriden Seç' : 'Select Gallery';
  String get loadSampleTarget => isTr ? 'Örnek Senaryo Yükle' : 'Load Demo Target';
  String get clearAll => isTr ? 'Formu Temizle' : 'Clear Form';

  String get fieldFullName => isTr ? 'Ad ve Soyad' : 'Full Name';
  String get fieldBirthAge => isTr ? 'Doğum Tarihi / Yaş Aralığı' : 'Birth Year / Age Range';
  String get fieldCity => isTr ? 'Şehir / İl / Memleket' : 'City / Province / Hometown';
  String get fieldUsername => isTr ? 'Kullanıcı Adı / Nick' : 'Username / Handle';
  String get fieldEmail => isTr ? 'E-Posta Adresi' : 'Email Address';
  String get fieldPhone => isTr ? 'Telefon Numarası' : 'Phone Number';
  String get fieldOccupation => isTr ? 'Meslek / Kurum / Domain' : 'Profession / Org / Domain';
  String get fieldNotes => isTr ? 'Ek İstihbarat Notları' : 'Additional Intel Notes';

  String get launchScan => isTr ? 'ÇOKLU KAYNAK OSINT TARAMASINI BAŞLAT' : 'LAUNCH MULTI-SOURCE OSINT SCAN';
  String get scanningActive => isTr ? 'ÇAPRAZ KAYNAK TARAMASI YÜRÜTÜLÜYOR...' : 'EXECUTING CROSS-SOURCE RECON...';

  // Categories
  String get catAll => isTr ? 'Tümü' : 'All';
  String get catFace => isTr ? 'Yüz & Görsel' : 'Face & Visual';
  String get catSocial => isTr ? 'Sosyal & Nick' : 'Social & Handle';
  String get catTurkey => isTr ? 'Türkiye Özel' : 'Turkey OSINT';
  String get catEmailPhone => isTr ? 'E-Posta & Tel' : 'Email & Phone';
  String get catDomainInfra => isTr ? 'Domain & Altyapı' : 'Domain & Infra';
  String get catDocuments => isTr ? 'Belge & Dork' : 'Docs & Dorks';

  // Export & Actions
  String get exportMarkdown => isTr ? 'Markdown Rapor' : 'Markdown Report';
  String get exportPdf => isTr ? 'PDF Dosyası Üret' : 'Generate PDF Dossier';
  String get exportJson => isTr ? 'JSON Dışa Aktar' : 'Export JSON';
  String get pivotDetected => isTr ? 'YENİ PİVOT KEŞFEDİLDİ' : 'NEW PIVOT DISCOVERED';
  String get runPivotScan => isTr ? 'Derinleştir' : 'Deepen Scan';
}

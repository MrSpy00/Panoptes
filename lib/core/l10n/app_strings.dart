enum AppLanguage { tr, en }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isTr => lang == AppLanguage.tr;

  String get appTitle => 'PANOPTES';
  String get appSubtitle => isTr
      ? 'ON-DEVICE BİYOMETRİK & KİMLİK OSINT'
      : 'ON-DEVICE BIOMETRIC & IDENTITY OSINT';

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
          '2. Cihaz İçi Gizlilik (Privacy-by-Design): Yüz embedding vektörleri (192-D), EXIF verileri ve sorgu geçmişi varsayılan olarak yalnızca telefonunuzda yerel olarak işlenir ve saklanır.\n\n'
          '3. Yasal Sorumluluk (KVKK / GDPR): 6698 sayılı KVKK ve ilgili mevzuat uyarınca kişisel verilerin işlenmesi, saklanması ve kullanım amacı tamamen kullanıcının kendi hukuki sorumluluğundadır.'
      : '1. Public Sources Only (OSINT): Panoptes strictly queries publicly accessible web indexes, public registries, and on-device visual analysis pipelines.\n\n'
          '2. Privacy-by-Design: Biometric 192-D face embeddings, EXIF metadata, and query logs remain strictly on your device unless you explicitly configure a remote sync server.\n\n'
          '3. Legal Liability (KVKK / GDPR): Processing of personal data is the sole legal responsibility of the operator. Use only for authorized security research and OSINT investigations.';
  String get ethicsAccept => isTr
      ? 'Şartları Okudum ve Kabul Ediyorum'
      : 'I Have Read & Accept the Terms';

  // Input Screen
  String get sectionPhoto => isTr
      ? 'HEDEF FOTOĞRAF & YÜZ PİPELINE'
      : 'TARGET PHOTO & FACE PIPELINE';
  String get pickCamera => isTr ? 'Kamera ile Çek' : 'Capture Camera';
  String get pickGallery => isTr ? 'Galeriden Seç' : 'Select Gallery';
  String get loadSampleTarget => isTr ? 'Örnek Senaryo Yükle' : 'Load Demo Target';
  String get clearAll => isTr ? 'Temizle' : 'Clear';

  String get fieldFullName => isTr ? 'Ad ve Soyad' : 'Full Name';
  String get fieldBirthAge => isTr ? 'Doğum Tarihi / Yaş Aralığı' : 'Birth Year / Age Range';
  String get fieldCity => isTr ? 'Şehir / İl / Memleket' : 'City / Province / Hometown';
  String get fieldUsername => isTr ? 'Kullanıcı Adı / Nick' : 'Username / Handle';
  String get fieldEmail => isTr ? 'E-Posta Adresi' : 'Email Address';
  String get fieldPhone => isTr ? 'Telefon Numarası' : 'Phone Number';
  String get fieldOccupation => isTr ? 'Meslek / Üniversite / Şirket' : 'Profession / University / Company';
  String get fieldNotes => isTr ? 'Ek İstihbarat Notları / Anahtar Kelimeler' : 'Additional Notes / Keywords';

  String get launchScan => isTr ? 'DERİN OSINT TARAMASINI BAŞLAT' : 'LAUNCH DEEP OSINT SCAN';
  String get scanningActive => isTr ? 'ÇOK KATMANLI TARAMA YÜRÜTÜLÜYOR...' : 'EXECUTING MULTI-LAYER RECON...';

  // Categories
  String get catAll => isTr ? 'Tümü' : 'All';
  String get catFace => isTr ? 'Yüz & Görsel' : 'Face & Visual';
  String get catSocial => isTr ? 'Sosyal & Nick' : 'Social & Handle';
  String get catTurkey => isTr ? 'Türkiye Özel' : 'Turkey OSINT';
  String get catCorporate => isTr ? 'Şirket & Akademik' : 'Corp & Academic';
  String get catForums => isTr ? 'Forum & Sözlük' : 'Forums & Dicts';
  String get catNews => isTr ? 'Haber & Arşiv' : 'News & Archive';
  String get catEmailPhone => isTr ? 'E-Posta & Tel' : 'Email & Phone';

  // Export & Actions
  String get exportMarkdown => isTr ? 'Markdown Rapor' : 'Markdown Report';
  String get exportPdf => isTr ? 'PDF Dosyası Üret' : 'Generate PDF Dossier';
  String get exportJson => isTr ? 'JSON Dışa Aktar' : 'Export JSON';
  String get pivotDetected => isTr ? 'YENİ PİVOT KEŞFEDİLDİ' : 'NEW PIVOT DISCOVERED';
  String get runPivotScan => isTr ? 'Derinleştir' : 'Deepen Scan';
}

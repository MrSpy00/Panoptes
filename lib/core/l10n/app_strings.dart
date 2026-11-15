enum AppLanguage { tr, en }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isTr => lang == AppLanguage.tr;

  String get appTitle => 'PANOPTES';
  String get appSubtitle => isTr
      ? 'ON-DEVICE BİYOMETRİK & KİMLİK OSINT PLATFORMU'
      : 'ON-DEVICE BIOMETRIC & IDENTITY OSINT PLATFORM';

  // Navigation Tabs
  String get navAcquire => isTr ? 'Hedef & Tarama' : 'Target & Scan';
  String get navDossier => isTr ? 'Sonuç Dosyası' : 'Intel Dossier';
  String get navFaceLab => isTr ? 'Yüz Laboratuvarı' : 'Face Lab';
  String get navGraph => isTr ? 'İlişki & Zaman' : 'Graph & Timeline';
  String get navVault => isTr ? 'Geçmiş & Ayarlar' : 'Vault & Config';

  // Ethics & Legal Gate
  String get ethicsTitle => isTr
      ? 'ETİK KULLANIM, KVKK VE YASAL SORUMLULUK BİLDİRİMİ'
      : 'ETHICAL USE, KVKK & LEGAL RESPONSIBILITY NOTICE';
  String get ethicsBody => isTr
      ? '1. Sadece Herkese Açık Kaynaklar (OSINT): Panoptes yalnızca halka açık web sayfaları, arama motoru indeksleri, açık ticaret sicil/akademik kayıtlar ve cihaz içi görsel analiz yöntemlerini kullanır.\n\n'
          '2. Cihaz İçi Gizlilik (Privacy-by-Design): Yüz embedding vektörleri (192-D), EXIF verileri ve sorgu geçmişi varsayılan olarak yalnızca telefonunuzda yerel olarak işlenir ve saklanır.\n\n'
          '3. Yasal Sorumluluk (KVKK / GDPR): 6698 sayılı KVKK ve ilgili mevzuat uyarınca kişisel verilerin işlenmesi, saklanması ve kullanım amacı tamamen kullanıcının kendi hukuki sorumluluğundadır. Yetkisiz takip, taciz veya hukuka aykırı amaçlarla kullanılamaz.'
      : '1. Public Sources Only (OSINT): Panoptes strictly queries publicly accessible web indexes, public registries, and on-device visual analysis pipelines.\n\n'
          '2. Privacy-by-Design: Biometric 192-D face embeddings, EXIF metadata, and query logs remain strictly on your device unless you explicitly configure a remote sync server.\n\n'
          '3. Legal Liability (KVKK / GDPR): Processing of personal data is the sole legal responsibility of the operator. Use only for authorized security research, OSINT investigations, and self-auditing.';
  String get ethicsAccept => isTr
      ? 'Şartları Okudum, Kabul Ediyorum'
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
  String get catSocial => isTr ? 'Sosyal & Nick' : 'Social & Username';
  String get catTurkey => isTr ? 'Türkiye Özel' : 'Turkey OSINT';
  String get catCorporate => isTr ? 'Şirket & Akademik' : 'Corporate & Academic';
  String get catForums => isTr ? 'Forum & Sözlük' : 'Forums & Dictionaries';
  String get catNews => isTr ? 'Haber & Arşiv' : 'News & Archives';
  String get catEmailPhone => isTr ? 'E-Posta & Tel & Dork' : 'Email, Phone & Dorks';

  // Export & Actions
  String get exportMarkdown => isTr ? 'Markdown Rapor' : 'Markdown Report';
  String get exportPdf => isTr ? 'PDF Dosyası Üret' : 'Generate PDF Dossier';
  String get exportJson => isTr ? 'JSON Dışa Aktar' : 'Export JSON';
  String get pivotDetected => isTr ? 'YENİ PİVOT KEŞFEDİLDİ' : 'NEW PIVOT DISCOVERED';
  String get runPivotScan => isTr ? 'Bu Pivot ile Derinleştir' : 'Deepen with Pivot';
}

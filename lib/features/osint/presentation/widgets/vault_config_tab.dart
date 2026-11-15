import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../../../../core/widgets/panoptes_logo.dart';
import '../providers/osint_controller.dart';

class VaultConfigTab extends ConsumerStatefulWidget {
  const VaultConfigTab({super.key});

  @override
  ConsumerState<VaultConfigTab> createState() => _VaultConfigTabState();
}

class _VaultConfigTabState extends ConsumerState<VaultConfigTab> {
  late final TextEditingController _sbUrlCtrl;
  late final TextEditingController _sbKeyCtrl;

  @override
  void initState() {
    super.initState();
    final state = ref.read(panoptesProvider);
    _sbUrlCtrl = TextEditingController(text: state.supabaseUrl);
    _sbKeyCtrl = TextEditingController(text: state.supabaseAnonKey);
  }

  @override
  void dispose() {
    _sbUrlCtrl.dispose();
    _sbKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final strings = state.strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        // 1. Argos Panoptes SVG Emblem & Multi-Scale Icon Showcase
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.borderCrimson, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.remove_red_eye_outlined, color: PanoptesColors.crimson, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'ARGOS PANOPTES — GEOMETRİK ÇOK GÖZLÜ SVG EMBLEM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
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
                      color: PanoptesColors.obsidian,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PanoptesColors.borderStrong),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/branding/panoptes_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '9-Gözlü Tam Amblem + 48px/24px Sade İkon',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Simsiyah (#000000) zemin, keskin geometrik merkez göz, bordo-kırmızı (#E11D48 / #9F1239) iris ve farklı açılarda bakan 8 uydu göz.',
                          style: TextStyle(
                            color: PanoptesColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const PanoptesLogo(size: 48, simplified: true),
                            const SizedBox(width: 10),
                            const PanoptesLogo(size: 24, simplified: true),
                            const SizedBox(width: 10),
                            SvgPicture.asset(
                              'assets/branding/panoptes_icon.svg',
                              width: 32,
                              height: 32,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Local Investigation History Vault
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
                      const Icon(Icons.history, color: PanoptesColors.crimson, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'YEREL SORGU GEÇMİŞİ (${state.savedSessions.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  if (state.savedSessions.isNotEmpty)
                    TextButton(
                      onPressed: notifier.clearVaultHistory,
                      child: const Text(
                        'Tümünü Sil',
                        style: TextStyle(color: PanoptesColors.crimsonBright, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.savedSessions.isEmpty)
                const Text(
                  'Henüz yerel kasada kayıtlı sorgu geçmişi yok.',
                  style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 12.5),
                )
              else
                ...state.savedSessions.take(8).map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => notifier.selectSavedSession(s),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: PanoptesColors.surfaceBase,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: state.currentSession?.id == s.id
                                    ? PanoptesColors.crimson
                                    : PanoptesColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_special_outlined,
                                    size: 18, color: PanoptesColors.crimson),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.target.displayLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${s.createdAt.toIso8601String().substring(0, 16).replaceAll("T", " ")} • ${s.findings.length} Bulgu • Ort. %${s.averageConfidence}',
                                        style: const TextStyle(
                                          color: PanoptesColors.textSecondary,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18, color: PanoptesColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Optional Supabase Cloud & Edge Queue Module
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
                  Icon(Icons.cloud_sync_outlined, color: PanoptesColors.crimson, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'OPSİYONEL SUPABASE CLOUD & EDGE WORKER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Panoptes varsayılan olarak %100 telefon üzerinde bağımsız çalışır. İsteğe bağlı olarak sonuç senkronizasyonu ve ağır job kuyruğu için kendi Supabase projenizi bağlayabilirsiniz.',
                style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sbUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supabase Project URL (Opsiyonel)',
                  hintText: 'https://xyzcompany.supabase.co',
                  prefixIcon: Icon(Icons.dns_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sbKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Supabase Anon / Public Key (Opsiyonel)',
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                  prefixIcon: Icon(Icons.key_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await notifier.saveSupabaseSettings(_sbUrlCtrl.text, _sbKeyCtrl.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supabase yapılandırması yerel kasaya kaydedildi.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_outlined, size: 17),
                      label: const Text('Kaydet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await notifier.saveSupabaseSettings(_sbUrlCtrl.text, _sbKeyCtrl.text);
                        final (ok, msg) = await notifier.syncActiveSessionToCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: ok ? PanoptesColors.statusHigh : PanoptesColors.burgundyDeep,
                              content: Text(msg),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                      label: const Text('Dosyayı Eşitle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. App Preferences (Theme, Language, Ethics Notice & Execution Telemetry)
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
              const Text(
                'SİSTEM AYARLARI, TEMA & ETİK BİLDİRİM',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.7),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: notifier.toggleTheme,
                      icon: Icon(
                        state.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        size: 18,
                        color: PanoptesColors.crimson,
                      ),
                      label: Text(state.isDarkMode ? 'Obsidian Koyu' : 'Açık Tema'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: notifier.toggleLanguage,
                      icon: const Icon(Icons.translate, size: 18, color: PanoptesColors.crimson),
                      label: Text(state.language.name == 'tr' ? 'Dil: Türkçe (TR)' : 'Lang: English (EN)'),
                    ),
                  ),
                ],
              ),
              if (state.currentSession != null && state.currentSession!.executionLogs.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'MOTOR TELEMETRİ KAYITLARI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: PanoptesColors.crimsonBright,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PanoptesColors.obsidian,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PanoptesColors.borderSubtle),
                  ),
                  child: Text(
                    state.currentSession!.executionLogs.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: PanoptesColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                strings.ethicsBody,
                style: const TextStyle(color: PanoptesColors.textMuted, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

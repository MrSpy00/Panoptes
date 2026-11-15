import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/l10n/app_strings.dart';
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
    final p = PanoptesPalette.of(context);
    final isTr = state.language == AppLanguage.tr;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        // 1. Argos Panoptes SVG Emblem & Multi-Scale Icon Showcase
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderCrimson, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ARGOS PANOPTES — GEOMETRİK ÇOK GÖZLÜ SVG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: PanoptesColors.obsidian,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.borderStrong),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/branding/panoptes_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '9-Gözlü Tam Amblem + 48px/24px Sade İkon',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Simsiyah (#000000) zemin, keskin geometrik merkez göz, bordo-kırmızı (#E11D48 / #9F1239) iris ve farklı açılarda bakan 8 uydu göz.',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const PanoptesLogo(size: 42, simplified: true),
                            const PanoptesLogo(size: 24, simplified: true),
                            SvgPicture.asset(
                              'assets/branding/panoptes_icon.svg',
                              width: 30,
                              height: 30,
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
        const SizedBox(height: 14),

        // 2. Local Investigation History Vault
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YEREL SORGU GEÇMİŞİ (${state.savedSessions.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (state.savedSessions.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: notifier.clearVaultHistory,
                      child: Text(
                        'Tümünü Sil',
                        style: TextStyle(
                          color: p.isDark
                              ? PanoptesColors.crimsonBright
                              : PanoptesColors.crimsonDeep,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.savedSessions.isEmpty)
                Text(
                  'Henüz yerel kasada kayıtlı sorgu geçmişi yok.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
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
                              color: p.surfaceBase,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: state.currentSession?.id == s.id
                                    ? PanoptesColors.crimson
                                    : p.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_special_outlined,
                                  size: 18,
                                  color: PanoptesColors.crimson,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.target.displayLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${s.createdAt.toIso8601String().substring(0, 16).replaceAll("T", " ")} • ${s.findings.length} Bulgu • Ort. %${s.averageConfidence}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: p.textSecondary,
                                          fontSize: 10.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 18, color: p.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Optional Supabase Cloud & Edge Queue Module
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_sync_outlined, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OPSİYONEL SUPABASE CLOUD & EDGE WORKER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Panoptes varsayılan olarak %100 telefon üzerinde bağımsız çalışır. İsteğe bağlı olarak sonuç senkronizasyonu ve ağır job kuyruğu için kendi Supabase projenizi bağlayabilirsiniz.',
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sbUrlCtrl,
                style: TextStyle(fontSize: 13, color: p.textPrimary),
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
                style: TextStyle(fontSize: 13, color: p.textPrimary),
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
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: () async {
                        await notifier.saveSupabaseSettings(_sbUrlCtrl.text, _sbKeyCtrl.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Supabase yapılandırması yerel kasaya kaydedildi.'),
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Kaydet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: () async {
                        await notifier.saveSupabaseSettings(_sbUrlCtrl.text, _sbKeyCtrl.text);
                        final (ok, msg) = await notifier.syncActiveSessionToCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor:
                                  ok ? PanoptesColors.statusHigh : PanoptesColors.burgundyDeep,
                              content: Text(msg),
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Dosyayı Eşitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. App Preferences (Theme, SVG Flag Language Switcher, Ethics Notice & Execution Telemetry)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SİSTEM AYARLARI, TEMA & DİL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onPressed: notifier.toggleTheme,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                            size: 17,
                            color: PanoptesColors.crimson,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              state.isDarkMode ? 'Obsidian Koyu' : 'Açık Tema',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
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
                      onPressed: notifier.toggleLanguage,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SvgPicture.asset(
                              isTr ? 'assets/branding/flag_tr.svg' : 'assets/branding/flag_en.svg',
                              width: 20,
                              height: 14,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              isTr ? 'Türkçe' : 'English',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (state.currentSession != null &&
                  state.currentSession!.executionLogs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'MOTOR TELEMETRİ KAYITLARI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: p.isDark
                        ? PanoptesColors.crimsonBright
                        : PanoptesColors.crimsonDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: Text(
                    state.currentSession!.executionLogs.join('\n'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: p.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                strings.ethicsBody,
                style: TextStyle(color: p.textMuted, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

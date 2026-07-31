import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:ahl_jannah/features/hadith/presentation/pages/hadith_page.dart';
import 'package:ahl_jannah/features/settings/presentation/cubit/settings_cubit.dart';

/// "More" tab page containing links to Hadith, Settings, and About.
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> with AutomaticKeepAliveClientMixin<MorePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final arabicFontSize = context.watch<SettingsCubit>().state.arabicFontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreTabTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _MoreTile(
            icon: Icons.library_books_rounded,
            title: l10n.hadithTileTitle,
            subtitle: l10n.hadithTileSubtitle,
            color: AppColors.primaryGreen,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HadithPage()),
              );
            },
          ),
          _MoreTile(
            icon: Icons.settings_rounded,
            title: l10n.settingsTileTitle,
            subtitle: l10n.settingsTileSubtitle,
            color: AppColors.teal,
            onTap: () => context.pushNamed('settings'),
          ),
          _MoreTile(
            icon: Icons.info_outline_rounded,
            title: l10n.aboutTileTitle,
            subtitle: l10n.aboutTileSubtitle,
            color: AppColors.accentGold,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Ahl Jannah',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Ahl Jannah',
              );
            },
          ),
          const Divider(indent: 72, endIndent: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l10n.basmala,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicBody(fontSize: arabicFontSize).copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.morePageMessage,
                  textAlign: TextAlign.justify,
                  style: AppTextStyles.arabicBody(fontSize: arabicFontSize).copyWith(
                    height: 1.8,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
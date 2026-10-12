import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/domain/entities/settings_entities.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../l10n/generated/app_localizations.dart';

/// Reusable slider for adjusting the Arabic reading font size (Quran, Hadith, Adhkar).
/// Updates local drag value visually without causing jank during drag,
/// persisting only when the user lifts their finger (`onChangeEnd`).
class ArabicFontSizeSlider extends StatefulWidget {
  final double currentSize;

  const ArabicFontSizeSlider({
    super.key,
    required this.currentSize,
  });

  @override
  State<ArabicFontSizeSlider> createState() => _ArabicFontSizeSliderState();
}

class _ArabicFontSizeSliderState extends State<ArabicFontSizeSlider> {
  late double _tempSize;

  @override
  void initState() {
    super.initState();
    _tempSize = widget.currentSize;
  }

  @override
  void didUpdateWidget(covariant ArabicFontSizeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSize != widget.currentSize) {
      _tempSize = widget.currentSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.contentFontSizeLabel(_tempSize.round()),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '${_tempSize.round()} px',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Slider(
          value: _tempSize.clamp(18.0, 48.0),
          min: 18.0,
          max: 48.0,
          divisions: 30,
          label: '${_tempSize.round()} px',
          onChanged: (val) {
            setState(() {
              _tempSize = val;
            });
          },
          onChangeEnd: (val) {
            context.read<SettingsCubit>().setArabicFontSize(val);
          },
        ),
      ],
    );
  }
}

/// Utility function to present the Arabic font size bottom sheet
/// in any section (Quran, Hadith, Adhkar).
Future<void> showArabicFontSizeBottomSheet(
  BuildContext context, {
  String? title,
}) {
  final l10n = AppLocalizations.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state is SettingsLoadSuccess
              ? state.settings
              : SettingsEntity.defaultSettings();
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title ?? l10n.arabicFontSizeSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.arabicFontSizeSectionDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ArabicFontSizeSlider(currentSize: settings.arabicFontSize),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../../../../core/widgets/clear_text_suffix.dart';

/// Compact search field with a search icon and a built-in "X" clear button
/// ([ClearTextSuffix]) that only appears once text has been entered.
class HadithSearchField extends StatelessWidget {
  const HadithSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
          suffixIcon: ClearTextSuffix(
            controller: controller,
            onClear: onClear,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withAlpha(70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

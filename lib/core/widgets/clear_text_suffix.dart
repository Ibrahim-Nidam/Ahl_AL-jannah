import 'package:flutter/material.dart';

/// Suffix "X" button shown inside a [TextField] whenever it contains text,
/// so the user can clear the field with a single tap. Hides automatically
/// once the field is empty (reactive via the controller).
class ClearTextSuffix extends StatelessWidget {
  const ClearTextSuffix({
    super.key,
    required this.controller,
    this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            controller.clear();
            onClear?.call();
          },
        );
      },
    );
  }
}

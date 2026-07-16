// lib/design_system/components/example_component.dart
//
// The EVERYDAY widget shape: a composite component that consumes design tokens
// ONLY through the context extension. NOTE what is absent — no `Color(0x...)`
// literal, no `Theme.of(context)`, no `AppColor`. Color, type, spacing, icon
// tint, and decoration all come from `context.*`. Optional params override a
// token default (`backgroundColor ?? context.colors...`) — the pattern for a
// caller-tunable component that still defaults to the system.
import 'package:flutter/material.dart';
import 'package:app/design_system/atoms/app_icon.dart';
import 'package:app/design_system/atoms/app_icons.dart';
import 'package:app/design_system/theme/app_context_extensions.dart';

class ExampleComponent extends StatelessWidget {
  const ExampleComponent({
    required this.label,
    required this.icon,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final AppIcons icon;

  /// Optional override of the token default.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.s.md, vertical: context.s.sm),
      decoration: context.decoration.card.copyWith(
        color: backgroundColor ?? context.colors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIcon(icon, sizeSquare: 16, color: context.icons.highlight),
          SizedBox(width: context.s.sm),
          Text(
            label,
            style: context.text.bodyMedium.copyWith(color: context.colors.neutral.shade100),
          ),
        ],
      ),
    );
  }
}

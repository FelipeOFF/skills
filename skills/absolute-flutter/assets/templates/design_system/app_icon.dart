// lib/design_system/atoms/app_icon.dart
//
// The thin renderer for the AppIcons atom registry. Takes an `AppIcons` value
// and paints it, defaulting size and tint from the ambient `IconTheme` so an
// icon inherits the surrounding icon styling unless explicitly overridden. This
// keeps every icon render consistent and removes per-call-site SvgPicture setup.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/design_system/atoms/app_icons.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.sizeSquare,
    this.color,
    this.iconWithoutColor = false,
    super.key,
  });

  final AppIcons icon;

  /// Square side; falls back to the ambient `IconTheme.size`.
  final double? sizeSquare;

  /// Tint; falls back to the ambient `IconTheme.color`. Prefer passing a token:
  /// `AppIcon(AppIcons.bell, color: context.icons.highlight)`.
  final Color? color;

  /// When true, render the SVG with its own embedded colors (no tint applied).
  final bool iconWithoutColor;

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final Color? resolvedColor = iconWithoutColor ? null : color ?? iconTheme.color;
    final double size = sizeSquare ?? iconTheme.size ?? 24;

    return SvgPicture.asset(
      icon.path,
      width: size,
      height: size,
      semanticsLabel: icon.semanticsLabel,
      colorFilter: resolvedColor != null ? ColorFilter.mode(resolvedColor, BlendMode.srcIn) : null,
    );
  }
}

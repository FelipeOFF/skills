// lib/design_system/atoms/app_icons.dart
//
// The ATOM registry: an enum whose values carry an asset path + an a11y label.
// WHY an enum: asset paths and semantics labels are centralized and
// compile-checked — a typo becomes a compile error, not a silent missing asset,
// and the renderer (app_icon.dart) applies consistent sizing/tinting. Reference
// icons as `AppIcons.home`, never as a raw `'assets/...'` string.
//
// Add a glyph = add an enum value. The leading `_svg` const keeps the asset root
// in one place.
const String _svg = 'assets/svg/';

enum AppIcons {
  home('${_svg}home.svg', semanticsLabel: 'Home'),
  profile('${_svg}profile.svg', semanticsLabel: 'Profile'),
  settings('${_svg}settings.svg', semanticsLabel: 'Settings'),
  bell('${_svg}bell.svg', semanticsLabel: 'Notifications');

  const AppIcons(this.path, {this.semanticsLabel});

  /// Asset path resolved by the renderer.
  final String path;

  /// Accessibility label announced by screen readers.
  final String? semanticsLabel;
}

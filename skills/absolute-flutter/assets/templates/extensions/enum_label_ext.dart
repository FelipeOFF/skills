// lib/model/extensions/item_type_extensions.dart
//
// Enum presentation lives in an extension, NOT on the enum and NOT in the
// widget — so the enum stays pure data and the View stays dumb. Each mapping is
// a Dart 3 exhaustive `switch` expression with NO `default`: when the enum
// gains a case, every mapping here fails to compile until it is handled. That
// compiler check is the whole point — do not add a catch-all.
//
// i18n in a context-free extension uses the STATIC `S.current` (there is no
// BuildContext in a `get`). Context-bearing methods elsewhere use
// `S.of(context)`. Mixing them wrong yields a stale/null locale.
import 'package:app/design_system/atoms/app_icons.dart';
import 'package:app/generated/l10n.dart';
import 'package:app/model/api/common/item_type.dart';

extension ItemTypeX on ItemType {
  /// Localized display label. `S.current` because there is no context in a
  /// getter; the active locale is read statically.
  String get label => switch (this) {
        ItemType.alpha => S.current.itemTypeAlpha,
        ItemType.beta => S.current.itemTypeBeta,
        ItemType.gamma => S.current.itemTypeGamma,
      };

  /// Icon token for this case, mapped to the design-system `AppIcons` registry.
  /// Keeps icon choice out of the widget and exhaustively checked.
  AppIcons get icon => switch (this) {
        ItemType.alpha => AppIcons.home,
        ItemType.beta => AppIcons.list,
        ItemType.gamma => AppIcons.bell,
      };
}

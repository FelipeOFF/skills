// lib/feature/item/model/item_dto_extensions.dart
//
// DTO mapper as an extension — keeps the transport DTO free of view concerns
// and makes the conversion chainable at the call site: `dto.toItemView()`.
// Co-located with the feature's model (or next to the DTO). The transport DTO
// fields are nullable (wire data is untrusted); the mapper computes derived
// values and guards every null itself.
import 'package:app/feature/item/model/item_dto.dart';
import 'package:app/feature/item/model/item_view_dto.dart';

extension ItemDtoExtensions on ItemDto {
  /// Maps this transport DTO into the view DTO consumed by widgets. All wire
  /// fields are nullable; derive safely and never force-unwrap.
  ItemViewDto toItemView() => ItemViewDto(
        id: id != null ? int.tryParse(id!) : null,
        name: title,
        imageRef: coverImage,
        // Derived value with a full null-guard before the division.
        average: total != null && count != null && count! > 0
            ? total! / count!
            : null,
      );
}

// All API path constants in one place. Private prefix consts group paths by API
// surface; public consts interpolate the prefix. Path parameters stay as literal
// `{id}` placeholders, substituted at the call site via String.replaceAll or
// interpolation. Keep this a const-only class with a private constructor so it is
// never instantiated.
//
// Rename anchors: `Feature` / `Item` / `Example` -> your real resources.

class Endpoints {
  Endpoints._();

  // --- API prefixes -------------------------------------------------------
  static const String _authApi = '/api/auth';
  static const String _userApi = '/api/user';
  static const String _featureApi = '/api/feature';

  // --- Auth ---------------------------------------------------------------
  static const String login = '$_authApi/v1/login';
  static const String register = '$_authApi/v1/register';
  static const String refreshToken = '$_authApi/v1/refresh';
  static const String logout = '$_authApi/v1/logout';

  // --- User / Profile -----------------------------------------------------
  static const String profile = '$_userApi/v1/profile';
  static const String settings = '$_userApi/v1/settings';

  // --- Feature ------------------------------------------------------------
  static const String featureList = '$_featureApi/v1/items';
  static const String itemDetail = '$_featureApi/v1/items/{itemId}';

  /// Helper for path-param substitution at the call site.
  static String fill(String path, Map<String, String> params) {
    String result = path;
    params.forEach((String key, String value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}

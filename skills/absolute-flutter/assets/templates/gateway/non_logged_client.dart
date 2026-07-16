// Public client family. No auth, no refresh — used for login, registration,
// password reset, and any endpoint reachable without a Bearer token. This is a
// marker subclass: it adds nothing on top of AbstractGateway except a name the
// repository layer can depend on.
//
// As with `logged_client.dart`, `NonLoggedClient` is usually declared in
// `abstract_gateway.dart`. This standalone copy target is for projects that keep
// the client families in `service/client/` separate from the base gateway.

import 'package:app/gateway/abstract_gateway.dart';

/// Marker family for endpoints that need no authentication.
abstract class NonLoggedClientBase extends NonLoggedClient {
  NonLoggedClientBase({super.isEnableEncrypt, super.apiKey});
}

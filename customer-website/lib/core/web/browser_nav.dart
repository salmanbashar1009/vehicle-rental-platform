import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'browser_nav_stub.dart' if (dart.library.js_interop) 'browser_nav_web.dart' as platform;

/// Navigates cleanly via [Router] when present, or browser location in SSR @client islands.
void navigateTo(BuildContext context, String path) {
  final router = Router.maybeOf(context);
  if (router != null) {
    router.push(path);
    return;
  }
  platform.assignWindowLocation(path);
}

/// Reads a string from browser sessionStorage (returns null on server/VM tests).
String? readSessionValue(String key) => platform.readSessionStorage(key);

/// Writes or clears a string in browser sessionStorage (no-op on server/VM tests).
void writeSessionValue(String key, String? value) => platform.writeSessionStorage(key, value);

import 'package:web/web.dart' as web;

/// Web implementation using package:web browser location and sessionStorage.
void assignWindowLocation(String path) {
  web.window.location.assign(path);
}

String? readSessionStorage(String key) => web.window.sessionStorage.getItem(key);

void writeSessionStorage(String key, String? value) {
  if (value == null) {
    web.window.sessionStorage.removeItem(key);
  } else {
    web.window.sessionStorage.setItem(key, value);
  }
}

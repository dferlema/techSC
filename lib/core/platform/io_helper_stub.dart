import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> getDocumentsPath() async {
  return null;
}

Future<String?> getTempPath() async {
  return null;
}

Future<String?> writeBytesToTempFile(Uint8List bytes, String fileName) async {
  return null;
}

Future<String?> writeBytesToDocumentsFile(
    Uint8List bytes, String fileName) async {
  return null;
}

Future<Uint8List?> readFileAsBytes(String path) async {
  return null;
}

bool isRetryableNetworkError(Object error) {
  return false;
}

Future<bool> hasInternetConnection() async {
  return html.window.navigator.onLine ?? true;
}

Future<void> shareBytes(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

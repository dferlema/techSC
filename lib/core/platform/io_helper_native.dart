import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> getDocumentsPath() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  } catch (e) {
    return null;
  }
}

Future<String?> getTempPath() async {
  try {
    final dir = await getTemporaryDirectory();
    return dir.path;
  } catch (e) {
    return null;
  }
}

Future<String?> writeBytesToTempFile(Uint8List bytes, String fileName) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    return null;
  }
}

Future<String?> writeBytesToDocumentsFile(
    Uint8List bytes, String fileName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    return null;
  }
}

Future<Uint8List?> readFileAsBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (e) {
    return null;
  }
}

bool isRetryableNetworkError(Object error) {
  return error is SocketException || error is HttpException;
}

Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

Future<void> shareBytes(Uint8List bytes, String fileName) async {
  final path = await writeBytesToTempFile(bytes, fileName);
  if (path != null) {
    await Share.shareXFiles([XFile(path)]);
  }
}

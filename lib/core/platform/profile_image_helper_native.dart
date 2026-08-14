import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveProfileImage(Uint8List bytes, String userId) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/profile_$userId.jpg');
  await file.writeAsBytes(bytes);
  return file.path;
}

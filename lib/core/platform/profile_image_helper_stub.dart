import 'dart:convert';
import 'dart:typed_data';

Future<String> saveProfileImage(Uint8List bytes, String userId) async {
  final base64Str = base64Encode(bytes);
  return 'data:image/jpeg;base64,$base64Str';
}

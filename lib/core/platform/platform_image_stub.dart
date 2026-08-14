import 'package:flutter/material.dart';

Widget buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
  if (path.startsWith('http') || path.startsWith('data:')) {
    return Image.network(path, fit: fit);
  }
  return const Icon(Icons.person, size: 48);
}

ImageProvider getLocalImageProvider(String path) {
  if (path.startsWith('http') || path.startsWith('data:')) {
    return NetworkImage(path);
  }
  return const AssetImage('assets/images/default_avatar.png');
}

Future<void> saveImageToFile(String sourcePath, String destPath) async {
  // No-op on web
}

String get platformFileSeparator => '/';

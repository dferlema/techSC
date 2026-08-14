import 'dart:io';
import 'package:flutter/material.dart';

Widget buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(File(path), fit: fit);
}

ImageProvider getLocalImageProvider(String path) {
  return FileImage(File(path));
}

Future<void> saveImageToFile(String sourcePath, String destPath) async {
  await File(sourcePath).copy(destPath);
}

String get platformFileSeparator => Platform.pathSeparator;

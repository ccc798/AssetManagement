import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  final ImagePicker _picker = ImagePicker();
  String? _imageDir;

  static const int compressQuality = 75;
  static const int maxWidth = 1080;
  static const int maxHeight = 1080;

  Future<void> init() async {
    if (_imageDir != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _imageDir = '${dir.path}/images';
    final imageDir = Directory(_imageDir!);
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
  }

  Future<List<String>> pickImages({int maxImages = 9}) async {
    await init();
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) return [];
    
    final savedPaths = <String>[];
    for (final file in pickedFiles) {
      if (savedPaths.length >= maxImages) break;
      final savedPath = await _compressAndSave(File(file.path));
      if (savedPath.isNotEmpty) savedPaths.add(savedPath);
    }
    return savedPaths;
  }

  Future<String> takePhoto() async {
    await init();
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile == null) return '';
    return await _compressAndSave(File(pickedFile.path));
  }

  Future<String> _compressAndSave(File sourceFile) async {
    await init();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_${sourceFile.path.split(Platform.pathSeparator).last}';
    final destPath = '$_imageDir/$fileName';
    
    try {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        destPath,
        quality: compressQuality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        keepExif: false,
      );
      
      if (compressedFile != null) {
        return compressedFile.path;
      } else {
        await sourceFile.copy(destPath);
        return destPath;
      }
    } catch (e) {
      await sourceFile.copy(destPath);
      return destPath;
    }
  }

  Future<void> deleteImage(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteImages(List<String> paths) async {
    for (final path in paths) {
      await deleteImage(path);
    }
  }

  File? getImageFile(String path) {
    if (path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Widget buildImageThumbnail(String path, {double size = 80}) {
    final file = getImageFile(path);
    if (file == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget buildImageGallery(List<String> paths, {double size = 80}) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paths.map((path) => buildImageThumbnail(path, size: size)).toList(),
    );
  }
}
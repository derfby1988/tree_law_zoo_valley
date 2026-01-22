import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB (Supabase limit)
  static const int maxImageWidth = 800;
  static const int maxImageHeight = 800;
  static const int imageQuality = 85;

  /// ตรวจสอบว่าเป็นรูปภาพที่รองรับหรือไม่ (Public)
  static bool isValidImageType(String? fileName, Uint8List? bytes) {
    return _isValidImageType(fileName, bytes);
  }

  /// ตรวจสอบขนาดไฟล์ (Public)
  static bool isValidFileSize(int fileSize) {
    return _isValidFileSize(fileSize);
  }

  /// ตรวจสอบว่าเป็นรูปภาพที่รองรับหรือไม่
  static bool _isValidImageType(String? fileName, Uint8List? bytes) {
    if (fileName == null && bytes == null) return false;
    
    // ตรวจสอบจากนามสกุลไฟล์
    if (fileName != null) {
      final extension = fileName.toLowerCase().split('.').last;
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
        return false;
      }
    }
    
    // ตรวจสอบจาก bytes (magic numbers)
    if (bytes != null && bytes.length > 4) {
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
      // GIF: 47 49 46 38
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
      // WebP: 52 49 46 46 ... 57 45 42 50
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
      // BMP: 42 4D
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    }
    
    return false;
  }

  /// ตรวจสอบขนาดไฟล์
  static bool _isValidFileSize(int fileSize) {
    return fileSize <= maxFileSize;
  }

  /// บีบอัดรูปภาพ
  static Future<Uint8List?> _compressImage(Uint8List imageBytes) async {
    try {
      // ถอดรหัสรูปภาพ
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // คำนวณขนาดใหม่ (maintain aspect ratio)
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > maxImageWidth || image.height > maxImageHeight) {
        final double aspectRatio = image.width / image.height;
        if (image.width > image.height) {
          newWidth = maxImageWidth;
          newHeight = (maxImageWidth / aspectRatio).round();
        } else {
          newHeight = maxImageHeight;
          newWidth = (maxImageHeight * aspectRatio).round();
        }
      }

      // ปรับขนาดรูปภาพ
      img.Image resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );

      // เข้ารหัสเป็น JPEG
      Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: imageQuality),
      );

      return compressedBytes;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// เลือกรูปภาพ (Cross-platform)
  static Future<ImageUploadResult?> pickImage({ImageSource? source}) async {
    try {
      Uint8List? imageBytes;
      String? fileName;

      if (kIsWeb) {
        // Web: ใช้ file_picker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.single.bytes != null) {
          imageBytes = result.files.single.bytes!;
          fileName = result.files.single.name;
        }
      } else {
        // Mobile: ใช้ image_picker
        if (source == null) return null;
        
        final ImagePicker picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(
          source: source,
          maxWidth: maxImageWidth * 2, // ให้พื้นที่มากกว่าเพื่อความคมชัด
          maxHeight: maxImageHeight * 2,
          imageQuality: 100, // คุณภาพสูงสุดก่อนบีบอัดเอง
        );

        if (pickedFile != null) {
          imageBytes = await pickedFile.readAsBytes();
          fileName = pickedFile.name;
        }
      }

      if (imageBytes == null) return null;

      return ImageUploadResult(
        bytes: imageBytes,
        fileName: fileName ?? 'image.jpg',
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// อัปโหลดรูปภาพไป Supabase Storage
  static Future<String?> uploadImageToSupabase(
    Uint8List imageBytes,
    String fileName,
    String userId, {
    Function(double)? onProgress,
  }) async {
    try {
      // 1. ตรวจสอบประเภทไฟล์
      if (!_isValidImageType(fileName, imageBytes)) {
        throw Exception('ไม่รองรับประเภทไฟล์นี้ กรุณาเลือกรูปภาพ (JPG, PNG, GIF, WebP, BMP)');
      }

      // 2. ตรวจสอบขนาดไฟล์
      if (!_isValidFileSize(imageBytes.length)) {
        final fileSizeMB = (imageBytes.length / (1024 * 1024)).toStringAsFixed(2);
        throw Exception('ขนาดไฟล์ใหญ่เกินไป ($fileSizeMB MB) กรุณาเลือกไฟล์ไม่เกิน 50MB');
      }

      // 3. บีบอัดรูปภาพ
      onProgress?.call(0.25); // 25% - เริ่มบีบอัด
      Uint8List? compressedBytes = await _compressImage(imageBytes);
      if (compressedBytes == null) {
        throw Exception('ไม่สามารถบีบอัดรูปภาพได้');
      }

      // 4. สร้างชื่อไฟล์ใหม่
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final newFileName = '${userId}_${timestamp}.$fileExtension';
      final filePath = 'avatars/$newFileName';

      // 5. อัปโหลดไป Supabase Storage
      onProgress?.call(0.5); // 50% - เริ่มอัปโหลด
      
      final uploadResponse = await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            compressedBytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      onProgress?.call(0.9); // 90% - อัปโหลดเสร็จ

      // 6. ดึง public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      onProgress?.call(1.0); // 100% - เสร็จสมบูรณ์

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw e;
    }
  }
}

/// Result จากการเลือกรูปภาพ
class ImageUploadResult {
  final Uint8List bytes;
  final String fileName;

  ImageUploadResult({
    required this.bytes,
    required this.fileName,
  });
}

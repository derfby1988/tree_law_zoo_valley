import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'progressive_image_service.dart';

/// Service สำหรับจัดการรูปโปรไฟล์
class ProfileImageService {
  static const String _bucketName = 'profile_images';
  static final ImagePicker _imagePicker = ImagePicker();

  /// ขอ permissions สำหรับการเข้าถึงรูปภาพ
  static Future<bool> _requestPermissions() async {
    // Web ไม่ต้องขอ permissions
    if (kIsWeb) {
      debugPrint('Web platform - no permissions needed for file picker');
      return true;
    }
    
    try {
      // Mobile จะ handle permissions อัตโนมัติโดย image_picker
      debugPrint('Mobile platform - permissions handled by image_picker');
      return true;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// เลือกรูปจากคลังรูป
  static Future<String?> pickImageFromGallery() async {
    try {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        debugPrint('No camera or photos permission');
        return null;
      }

      debugPrint('Picking image from gallery...');
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,  // ลดขนาดจาก 800 เป็น 400
        maxHeight: 400, // ลดขนาดจาก 800 เป็น 400
        imageQuality: 70, // ลดคุณภาพจาก 80 เป็น 70
      );

      if (image != null) {
        debugPrint('Image picked from gallery: ${image.path}');
        debugPrint('Image name: ${image.name}');
        
        // อ่าน bytes และคืนค่าเป็น base64 string แทน blob URL
        final bytes = await image.readAsBytes();
        final fileSize = bytes.length;
        debugPrint('Image size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
        
        // สำหรับ web ให้คืนค่าเป็น base64 data URL
        if (kIsWeb) {
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          debugPrint('Returning base64 data URL for web');
          return base64String;
        } else {
          // สำหรับ mobile คืนค่าเป็น path ตามเดิม
          return image.path;
        }
      } else {
        debugPrint('No image selected');
        return null;
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// ถ่ายรูปจากกล้อง
  static Future<String?> pickImageFromCamera() async {
    try {
      // Web ไม่ support camera
      if (kIsWeb) {
        debugPrint('Camera not supported on web platform');
        return null;
      }
      
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        debugPrint('No camera permission');
        return null;
      }

      debugPrint('Picking image from camera...');
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,  // ลดขนาดจาก 800 เป็น 400
        maxHeight: 400, // ลดขนาดจาก 800 เป็น 400
        imageQuality: 70, // ลดคุณภาพจาก 80 เป็น 70
      );

      if (image != null) {
        debugPrint('Image picked from camera: ${image.path}');
        debugPrint('Image name: ${image.name}');
        final fileSize = await image.length();
        debugPrint('Image size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
        return image.path;
      } else {
        debugPrint('No image captured');
        return null;
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// อัปโหลดรูปโปรไฟล์ไปยัง Supabase Storage
  static Future<String?> uploadProfileImage(
    dynamic imageData, // รับทั้ง String (path) หรือ Uint8List (bytes)
    String userId,
  ) async {
    try {
      debugPrint('Uploading profile image for user: $userId');
      debugPrint('Image data type: ${imageData.runtimeType}');
      
      Uint8List bytes;
      String fileName;
      
      if (imageData is String) {
        // กรณีเป็น file path (mobile) หรือ blob URL (web)
        if (imageData.startsWith('blob:')) {
          // Blob URL case - ไม่สามารถอัปโหลดตรงได้
          throw UnsupportedError('Cannot upload blob URL directly. Please convert to bytes first.');
        } else {
          // Regular file path (mobile)
          final file = File(imageData);
          if (!file.existsSync()) {
            debugPrint('Image file does not exist: $imageData');
            return null;
          }
          bytes = await file.readAsBytes();
          fileName = imageData.split('/').last;
        }
      } else if (imageData is Uint8List) {
        // กรณีเป็น bytes (web)
        bytes = imageData;
        fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        throw Exception('Invalid image data type: ${imageData.runtimeType}');
      }

      // สร้างชื่อไฟล์ที่ไม่ซ้ำกัน
      final fileExtension = fileName.split('.').last.toLowerCase();
      final uniqueFileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath = 'public/$uniqueFileName';

      debugPrint('Uploading file: $uniqueFileName');
      debugPrint('File size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');

      // บีบอัดข้อมูลเพิ่มเติม (ถ้าต้องการ)
      final compressedBytes = await _compressImage(bytes, fileExtension);
      debugPrint('Compressed file size: ${compressedBytes.length} bytes (${(compressedBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      // อัปโหลดไปยัง Supabase Storage
      final response = await Supabase.instance.client.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            compressedBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true,
            ),
          );

      debugPrint('Upload response: $response');

      // ดึง public URL
      final publicUrl = Supabase.instance.client.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      debugPrint('Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// บีบอัดรูปภาพ (เพิ่มเติม)
  static Future<Uint8List> _compressImage(Uint8List bytes, String extension) async {
    try {
      // สำหรับ Flutter web และ mobile สามารถใช้ image package เพิ่มเติมได้
      // แต่ในปัจจุบันเราจะใช้การบีบอัดพื้นฐานจาก image_picker ก่อนหน้านี้
      debugPrint('Using basic compression from image picker');
      return bytes; // ใช้ข้อมูลเดิมจาก image picker ที่ถูกบีบอัดแล้ว
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes; // ถ้าบีบอัดล้มเหลว ใช้ข้อมูลเดิม
    }
  }

  /// ลบรูปโปรไฟล์เก่า
  static Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      debugPrint('Deleting profile image: $imageUrl');
      
      // ดึง path จาก URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // หา index ของ 'public' และสร้าง path
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex == -1) {
        debugPrint('Invalid image URL format');
        return false;
      }
      
      final filePath = pathSegments.sublist(publicIndex).join('/');
      
      // ลบจาก Supabase Storage
      final response = await Supabase.instance.client.storage
          .from(_bucketName)
          .remove([filePath]);
      
      debugPrint('Delete response: $response');
      return true;
    } catch (e) {
      debugPrint('Error deleting profile image: $e');
      return false;
    }
  }

  /// แสดง dialog เลือกรูป
  static Future<String?> showImagePickerDialog(BuildContext context) async {
    String? selectedImagePath;
    
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกรูปโปรไฟล์'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('ถ่ายรูป'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (kIsWeb) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กล้องไม่รองรับบนเว็บ กรุณาเลือกรูปจากคลังรูป'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    selectedImagePath = await pickImageFromCamera();
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังรูป'),
                onTap: () async {
                  Navigator.of(context).pop();
                  selectedImagePath = await pickImageFromGallery();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
    
    return selectedImagePath;
  }

  /// สร้าง widget แสดงรูปโปรไฟล์พร้อม Progressive Loading
  static Widget buildProfileImage({
    required String? imageUrl,
    required double size,
    VoidCallback? onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: child ?? _buildProgressiveImage(imageUrl, size),
        ),
      ),
    );
  }

  /// สร้าง Progressive Image Widget
  static Widget _buildProgressiveImage(String? imageUrl, double size) {
    if (imageUrl == null || imageUrl.isEmpty) {
      // Default avatar
      return Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.grey[600],
      );
    }

    // ตรวจสอบว่าเป็น blob URL หรือไม่
    if (imageUrl.startsWith('blob:')) {
      // Blob URL - ใช้ Image.network ตรงๆ
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading blob image: $error');
          return Icon(
            Icons.error_outline,
            size: size * 0.6,
            color: Colors.grey[400],
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
              ),
            ),
          );
        },
      );
    }

    // Regular HTTP URL - ใช้ Progressive Loading
    return ProgressiveImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: Colors.grey[400],
        ),
      ),
      errorWidget: Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: Icon(
          Icons.error_outline,
          size: size * 0.6,
          color: Colors.grey[400],
        ),
      ),
      placeholderQuality: 15,
      finalQuality: 85,
      fadeInDuration: const Duration(milliseconds: 400),
    );
  }

  /// ล้าง cache ของรูปโปรไฟล์
  static Future<void> clearCache() async {
    try {
      await ProgressiveImageService.clearCache();
      debugPrint('Profile image cache cleared');
    } catch (e) {
      debugPrint('Error clearing profile image cache: $e');
    }
  }

  /// ตรวจสอบว่ารูปอยู่ใน cache หรือไม่
  static Future<bool> isImageCached(String imageUrl) async {
    try {
      return await ProgressiveImageService.isImageCached(imageUrl);
    } catch (e) {
      debugPrint('Error checking profile image cache: $e');
      return false;
    }
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarPicker extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(Uint8List?, String?) onImageSelected;
  final double radius;
  final bool enabled;
  final Function(String?)? onAvatarUploaded; // เพิ่ม callback สำหรับบอกว่า URL หลังอัปโหลด

  const AvatarPicker({
    super.key,
    this.currentAvatarUrl,
    required this.onImageSelected,
    this.onAvatarUploaded, // เพิ่มพารามิเตอร์
    this.radius = 50,
    this.enabled = true,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  String? _previewUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.currentAvatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar Stack
        GestureDetector(
          onTap: widget.enabled ? _showImageSourceDialog : null,
          child: Stack(
            children: [
              // Avatar Circle
              CircleAvatar(
                radius: widget.radius,
                backgroundColor: Colors.grey[300],
                backgroundImage: _previewUrl != null
                    ? _previewUrl!.startsWith('http')
                        ? NetworkImage(_previewUrl!)
                        : MemoryImage(_selectedImageBytes!)
                    : null,
                child: _previewUrl == null
                    ? Icon(
                        Icons.person,
                        size: widget.radius * 0.8,
                        color: Colors.grey[600],
                      )
                    : null,
              ),

              // Upload Progress Overlay
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'กำลังอัปโหลด...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Camera Icon
              if (widget.enabled && !_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: widget.radius * 0.6,
                    height: widget.radius * 0.6,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: widget.radius * 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Instructions
        Text(
          widget.enabled ? 'แตะเพื่อเลือกรูปโปรไฟล์ (ไม่จำเป็น)' : 'รูปโปรไฟล์',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),

        // Remove Button (if has selected image)
        if (_selectedImageBytes != null && widget.enabled && !_isUploading)
          TextButton(
            onPressed: _removeSelectedImage,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'เปลี่ยนรูป',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'เลือกรูปภาพ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Options
              if (!kIsWeb) ...[
                _buildOption(
                  icon: Icons.camera_alt,
                  title: 'ถ่ายรูป',
                  subtitle: 'ใช้กล้องถ่ายรูป',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildOption(
                  icon: Icons.photo_library,
                  title: 'เลือกจากคลังภาพ',
                  subtitle: 'เลือกรูปจากอุปกรณ์',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ] else ...[
                _buildOption(
                  icon: Icons.upload_file,
                  title: 'อัปโหลดรูปภาพ',
                  subtitle: 'เลือกไฟล์รูปภาพจากคอมพิวเตอร์',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(null); // Web uses null
                  },
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[50],
        child: Icon(icon, color: Colors.blue[600]),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Future<void> _pickImage(ImageSource? source) async {
    if (!mounted) return;

    try {
      // เลือกรูปภาพ
      final result = await ImageUploadService.pickImage(source: source);
      if (result == null) return;

      // ตรวจสอบว่าเป็นรูปภาพที่รองรับหรือไม่
      if (!ImageUploadService.isValidImageType(result.fileName, result.bytes)) {
        if (mounted) {
          final action = await _showValidationErrorDialog('ประเภทไฟล์ไม่รองรับ', 'ไม่รองรับประเภทไฟล์นี้ กรุณาเลือกรูปภาพ (JPG, PNG, GIF, WebP, BMP)');
          
          if (action == 'retry') {
            _showImageSourceDialog(); // เปิด dialog เลือกรูปใหม่
          }
        }
        return;
      }

      // ตรวจสอบขนาดไฟล์
      if (!ImageUploadService.isValidFileSize(result.bytes.length)) {
        final fileSizeMB = (result.bytes.length / (1024 * 1024)).toStringAsFixed(2);
        if (mounted) {
          final action = await _showValidationErrorDialog('ขนาดไฟล์ใหญ่เกินไป', 'ขนาดไฟล์ใหญ่เกินไป ($fileSizeMB MB) กรุณาเลือกไฟล์ไม่เกิน 50MB');
          
          if (action == 'retry') {
            _showImageSourceDialog(); // เปิด dialog เลือกรูปใหม่
          }
        }
        return;
      }

      // แสดง preview รูปที่เลือก
      if (mounted) {
        setState(() {
          _selectedImageBytes = result.bytes;
          _selectedFileName = result.fileName;
          _previewUrl = 'selected'; // ใช้ค่าพิเศษเพื่อบอกว่ามีการเลือกรูป
        });

        // แจ้ง parent widget
        widget.onImageSelected(_selectedImageBytes, _selectedFileName);

        // แจ้ง parent widget ว่าอัปโหลดเสร็จแล้ว
        widget.onAvatarUploaded?.call(_previewUrl);

        // แสดง success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เลือกรูปภาพแล้ว รูปจะถูกอัปโหลดพร้อมกับการสมัครสมาชิก'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// อัปโหลดรูปภาพไป Supabase พร้อม Progress
  Future<void> _uploadImageToSupabase() async {
    if (!mounted || _selectedImageBytes == null || _selectedFileName == null) return;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final avatarUrl = await ImageUploadService.uploadImageToSupabase(
        _selectedImageBytes!,
        _selectedFileName!,
        currentUser.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _previewUrl = avatarUrl;
        });

        widget.onImageSelected(_selectedImageBytes, _selectedFileName);

        // แจ้ง parent widget ว่าอัปโหลดเสร็จแล้ว
        widget.onAvatarUploaded?.call(avatarUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปโหลดรูปภาพสำเร็จแล้ว'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });

        // แสดง dialog ให้เลือก
        final action = await _showUploadErrorDialog(e.toString());
        
        if (action == 'retry') {
          _uploadImageToSupabase(); // ลองใหม่
        } else if (action == 'cancel') {
          _removeSelectedImage(); // ยกเลิก
        }
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedFileName = null;
      _previewUrl = widget.currentAvatarUrl; // กลับไปแสดงรูปเดิม (ถ้ามี)
    });

    widget.onImageSelected(null, null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ยกเลิกการเลือกรูปภาพ'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// แสดง dialog ให้เลือกเมื่อ validation ผิดพลาด
  Future<String?> _showValidationErrorDialog(String title, String message) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // ไม่ให้ปิดตรงขอบนอก
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              'คุณต้องการทำอย่างไร?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          // ยกเลิกการอัปโหลดรูป
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text('ยกเลิกรูป'),
          ),
          
          // เลือกรูปใหม่
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('เลือกรูปใหม่'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// แสดง dialog เมื่ออัปโหลดผิดพลาด
  Future<String?> _showUploadErrorDialog(String errorMessage) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            const Text('อัปโหลดรูปภาพไม่สำเร็จ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            Text(
              'คุณต้องการทำอย่างไร?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          // ยกเลิกการอัปโหลดรูป
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text('ยกเลิกรูป'),
          ),
          
          // เลือกรูปใหม่
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('เลือกรูปใหม่'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

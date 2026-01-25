import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Progressive Image Service สำหรับการโหลดรูปแบบ Progressive และ Caching
class ProgressiveImageService {
  static const String _cacheKey = 'progressive_images';
  static final _cacheManager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: _cacheKey),
      fileService: HttpFileService(),
    ),
  );

  /// โหลดรูปแบบ Progressive พร้อม Caching
  static Future<ProgressiveImageResult> loadProgressiveImage(
    String imageUrl, {
    int? placeholderQuality,
    int? finalQuality,
    Duration? timeout,
  }) async {
    try {
      debugPrint('Loading progressive image: $imageUrl');
      
      // ตรวจสอบว่าเป็น blob URL หรือไม่ (Web)
      if (imageUrl.startsWith('blob:')) {
        debugPrint('Blob URL detected, skipping network loading');
        // สำหรับ blob URL, ใช้ข้อมูลเดิมทั้งหมด
        // ในอนาคตสามารถเพิ่มการแปลง blob เป็น bytes ได้
        throw UnsupportedError('Blob URLs are not supported for progressive loading');
      }
      
      // ตรวจสอบ cache ก่อน
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        debugPrint('Image found in cache: ${fileInfo.file.path}');
        final bytes = await fileInfo.file.readAsBytes();
        return ProgressiveImageResult(
          placeholderBytes: bytes,
          finalBytes: bytes,
          isFromCache: true,
        );
      }

      // โหลดรูปจาก network
      final response = await http.get(
        Uri.parse(imageUrl),
      ).timeout(timeout ?? const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to load image: ${response.statusCode}');
      }

      final originalBytes = response.bodyBytes;
      debugPrint('Original image size: ${originalBytes.length} bytes');

      // สร้าง placeholder (คุณภาพต่ำ)
      final placeholderBytes = await _createPlaceholder(
        originalBytes,
        quality: placeholderQuality ?? 30,
      );

      // สร้าง final image (คุณภาพสูง)
      final finalBytes = await _createOptimizedImage(
        originalBytes,
        quality: finalQuality ?? 85,
      );

      // บันทึกลง cache
      await _cacheManager.putFile(
        imageUrl,
        finalBytes,
      );

      debugPrint('Progressive image loaded and cached');
      return ProgressiveImageResult(
        placeholderBytes: placeholderBytes,
        finalBytes: finalBytes,
        isFromCache: false,
      );
    } catch (e) {
      debugPrint('Error loading progressive image: $e');
      throw e;
    }
  }

  /// สร้าง placeholder รูปคุณภาพต่ำ
  static Future<Uint8List> _createPlaceholder(
    Uint8List originalBytes, {
    required int quality,
  }) async {
    try {
      // ใช้ Flutter's built-in image decoding
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // สร้างรูปขนาดเล็ก (1/4 ของขนาดเดิม)
      final targetWidth = (image.width * 0.25).round();
      final targetHeight = (image.height * 0.25).round();

      final resizedBytes = await _resizeImage(
        originalBytes,
        targetWidth,
        targetHeight,
        quality: quality,
      );

      image.dispose();
      codec.dispose();

      debugPrint('Placeholder created: ${resizedBytes.length} bytes');
      return resizedBytes;
    } catch (e) {
      debugPrint('Error creating placeholder: $e');
      return originalBytes; // Fallback to original
    }
  }

  /// สร้างรูปคุณภาพสูงที่ optimize แล้ว
  static Future<Uint8List> _createOptimizedImage(
    Uint8List originalBytes, {
    required int quality,
  }) async {
    try {
      // ตรวจสอบขนาดและปรับให้เหมาะสม
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // จำกัดขนาดสูงสุด 1200x1200
      int targetWidth = image.width;
      int targetHeight = image.height;

      if (image.width > 1200 || image.height > 1200) {
        final aspectRatio = image.width / image.height;
        if (image.width > image.height) {
          targetWidth = 1200;
          targetHeight = (1200 / aspectRatio).round();
        } else {
          targetHeight = 1200;
          targetWidth = (1200 * aspectRatio).round();
        }
      }

      final optimizedBytes = await _resizeImage(
        originalBytes,
        targetWidth,
        targetHeight,
        quality: quality,
      );

      image.dispose();
      codec.dispose();

      debugPrint('Optimized image created: ${optimizedBytes.length} bytes');
      return optimizedBytes;
    } catch (e) {
      debugPrint('Error creating optimized image: $e');
      return originalBytes; // Fallback to original
    }
  }

  /// ปรับขนาดรูปภาพ (ใช้วิธีง่ายๆ)
  static Future<Uint8List> _resizeImage(
    Uint8List originalBytes,
    int targetWidth,
    int targetHeight, {
    required int quality,
  }) async {
    // สำหรับตอนนี้ return original bytes ก่อน
    // ในอนาคตสามารถใช้ image package หรือ flutter_image_compress
    return originalBytes;
  }

  /// ล้าง cache
  static Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      debugPrint('Progressive image cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// ดูขนาด cache
  static Future<int> getCacheSize() async {
    try {
      // Flutter Cache Manager ไม่มี method ตรงๆ ในการดูขนาด
      // สามารถ implement เพิ่มเติมได้
      return 0;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// ตรวจสอบว่ามีรูปใน cache หรือไม่
  static Future<bool> isImageCached(String imageUrl) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      debugPrint('Error checking cache: $e');
      return false;
    }
  }

  /// ลบรูปที่ระบุออกจาก cache
  static Future<void> removeFromCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
      debugPrint('Image removed from cache: $imageUrl');
    } catch (e) {
      debugPrint('Error removing from cache: $e');
    }
  }
}

/// Result จากการโหลด Progressive Image
class ProgressiveImageResult {
  final Uint8List placeholderBytes;
  final Uint8List finalBytes;
  final bool isFromCache;

  ProgressiveImageResult({
    required this.placeholderBytes,
    required this.finalBytes,
    required this.isFromCache,
  });
}

/// Widget สำหรับแสดง Progressive Image
class ProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration? fadeInDuration;
  final int placeholderQuality;
  final int finalQuality;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.placeholderQuality = 30,
    this.finalQuality = 85,
  });

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage>
    with TickerProviderStateMixin {
  Uint8List? _placeholderBytes;
  Uint8List? _finalBytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showFinal = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _showFinal = false;
      });

      final result = await ProgressiveImageService.loadProgressiveImage(
        widget.imageUrl,
        placeholderQuality: widget.placeholderQuality,
        finalQuality: widget.finalQuality,
      );

      if (mounted) {
        setState(() {
          _placeholderBytes = result.placeholderBytes;
          _finalBytes = result.finalBytes;
          _isLoading = false;
        });

        // แสดง placeholder ก่อน
        await Future.delayed(const Duration(milliseconds: 100));

        // แสดง final image ด้วย animation
        if (mounted) {
          setState(() {
            _showFinal = true;
          });
          _fadeController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildLoadingWidget();
    }

    return Stack(
      children: [
        // Placeholder Image
        if (_placeholderBytes != null && !_showFinal)
          Image.memory(
            _placeholderBytes!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          ),

        // Final Image (with fade in)
        if (_finalBytes != null && _showFinal)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Image.memory(
              _finalBytes!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
            const SizedBox(height: 8),
            Text(
              'กำลังโหลด...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'โหลดรูปไม่สำเร็จ',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

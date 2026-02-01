import 'dart:ui';
import 'package:flutter/material.dart';

/// GlassButton - ปุ่มแบบ Glassmorphism ที่มีเอฟเฟกต์กระจกเงา
/// 
/// ใช้สำหรับสร้างปุ่มที่มีพื้นหลังโปร่งแสง/เบลอ ดูทันสมัยและสวยงาม
/// 
/// ตัวอย่างการใช้งาน:
/// ```dart
/// GlassButton(
///   text: 'สร้างกลุ่มใหม่',
///   onPressed: () {},
///   backgroundColor: Colors.blue,
///   icon: Icons.add,
/// )
/// ```
class GlassButton extends StatelessWidget {
  /// ข้อความบนปุ่ม
  final String text;
  
  /// ฟังก์ชันเมื่อกดปุ่ม
  final VoidCallback? onPressed;
  
  /// สีพื้นหลังของปุ่ม (จะถูกทำให้โปร่งแสง)
  final Color backgroundColor;
  
  /// สีข้อความบนปุ่ม
  final Color textColor;
  
  /// ไอคอนที่จะแสดงหน้าข้อความ (optional)
  final IconData? icon;
  
  /// ขนาดตัวอักษร
  final double fontSize;
  
  /// ระดับความโปร่งแสงของพื้นหลัง (0.0 - 1.0)
  final double opacity;
  
  /// ความแรงของเอฟเฟกต์เบลอ
  final double blurStrength;
  
  /// ขนาดของปุ่ม
  final EdgeInsets padding;
  
  /// ความโค้งของขอบปุ่ม
  final double borderRadius;
  
  /// ความกว้างของปุ่ม (null = wrap content)
  final double? width;
  
  /// ความสูงของปุ่ม (null = default)
  final double? height;
  
  /// เงาของปุ่ม
  final bool hasShadow;
  
  /// ขอบปุ่ม
  final BoxBorder? border;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.icon,
    this.fontSize = 16,
    this.opacity = 0.3,
    this.blurStrength = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = 16,
    this.width,
    this.height,
    this.hasShadow = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final bool expandContent = width != null && width == double.infinity;
    
    Widget buttonContent = Row(
      mainAxisSize: expandContent ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: textColor,
            size: fontSize + 4,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget glassContainer = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength,
          sigmaY: blurStrength,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: hasShadow
                ? [
                    BoxShadow(
                      color: backgroundColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: buttonContent,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: glassContainer,
      ),
    );
  }
}

/// GlassIconButton - ปุ่มไอคอนแบบ Glassmorphism
/// 
/// ใช้สำหรับสร้างปุ่มไอคอนกลมที่มีเอฟเฟกต์กระจก
class GlassIconButton extends StatelessWidget {
  /// ไอคอนที่จะแสดง
  final IconData icon;
  
  /// ฟังก์ชันเมื่อกดปุ่ม
  final VoidCallback? onPressed;
  
  /// สีพื้นหลังของปุ่ม
  final Color backgroundColor;
  
  /// สีไอคอน
  final Color iconColor;
  
  /// ขนาดของปุ่ม
  final double size;
  
  /// ขนาดของไอคอน
  final double iconSize;
  
  /// ระดับความโปร่งแสง
  final double opacity;
  
  /// ความแรงของเอฟเฟกต์เบลอ
  final double blurStrength;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.iconColor = Colors.white,
    this.size = 48,
    this.iconSize = 24,
    this.opacity = 0.3,
    this.blurStrength = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength,
          sigmaY: blurStrength,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(opacity),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GlassFloatingActionButton - FAB แบบ Glassmorphism
/// 
/// ใช้สำหรับสร้าง Floating Action Button ที่มีเอฟเฟกต์กระจก
class GlassFloatingActionButton extends StatelessWidget {
  /// ไอคอนที่จะแสดง
  final IconData icon;
  
  /// ฟังก์ชันเมื่อกดปุ่ม
  final VoidCallback? onPressed;
  
  /// สีพื้นหลังของปุ่ม
  final Color backgroundColor;
  
  /// สีไอคอน
  final Color iconColor;
  
  /// ขนาดของปุ่ม
  final double size;
  
  /// ระดับความโปร่งแสง
  final double opacity;
  
  /// ความแรงของเอฟเฟกต์เบลอ
  final double blurStrength;

  const GlassFloatingActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.iconColor = Colors.white,
    this.size = 56,
    this.opacity = 0.4,
    this.blurStrength = 15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength,
          sigmaY: blurStrength,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(opacity),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GlassButtonVariant - ตัวเลือกสีพร้อมใช้สำหรับ GlassButton
class GlassButtonVariants {
  /// สีเขียว (Primary)
  static const primary = Color(0xFF2E7D32);
  
  /// สีน้ำเงิน
  static const blue = Color(0xFF1976D2);
  
  /// สีแดง
  static const red = Color(0xFFD32F2F);
  
  /// สีส้ม
  static const orange = Color(0xFFF57C00);
  
  /// สีม่วง
  static const purple = Color(0xFF7B1FA2);
  
  /// สีฟ้า
  static const cyan = Color(0xFF0097A7);
  
  /// สีชมพู
  static const pink = Color(0xFFC2185B);
  
  /// สีเทา
  static const grey = Color(0xFF616161);
  
  /// สีดำ
  static const black = Color(0xFF212121);
  
  /// สีขาว
  static const white = Color(0xFFFFFFFF);
}

import 'package:flutter/material.dart';

/// Password Validator สำหรับตรวจสอบความแข็งแรงของรหัสผ่าน
class PasswordValidator {
  /// ตรวจสอบความแข็งแรงของรหัสผ่าน
  static PasswordStrength checkPasswordStrength(String password) {
    int score = 0;
    List<String> feedback = [];
    
    // ตรวจสอบความยาว
    if (password.length >= 8) {
      score += 1;
    } else {
      feedback.add('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร');
    }
    
    // ตรวจสอบตัวพิมพ์ใหญ่
    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    } else {
      feedback.add('ต้องมีตัวพิมพ์ใหญ่ (A-Z)');
    }
    
    // ตรวจสอบตัวพิมพ์เล็ก
    if (password.contains(RegExp(r'[a-z]'))) {
      score += 1;
    } else {
      feedback.add('ต้องมีตัวพิมพ์เล็ก (a-z)');
    }
    
    // ตรวจสอบตัวเลข
    if (password.contains(RegExp(r'[0-9]'))) {
      score += 1;
    } else {
      feedback.add('ต้องมีตัวเลข (0-9)');
    }
    
    // ตรวจสอบอักขระพิเศษ
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 1;
    } else {
      feedback.add('แนะนำให้มีอักขระพิเศษ (!@#\$%^&*)');
    }
    
    // กำหนดความแข็งแรง
    if (score <= 2) {
      return PasswordStrength(
        level: PasswordLevel.weak,
        score: score,
        feedback: feedback,
        color: Colors.red,
        message: 'รหัสผ่านอ่อน',
      );
    } else if (score <= 3) {
      return PasswordStrength(
        level: PasswordLevel.fair,
        score: score,
        feedback: feedback,
        color: Colors.orange,
        message: 'รหัสผ่านปานากลาง',
      );
    } else if (score <= 4) {
      return PasswordStrength(
        level: PasswordLevel.good,
        score: score,
        feedback: feedback,
        color: Colors.yellow.shade700,
        message: 'รหัสผ่านดี',
      );
    } else {
      return PasswordStrength(
        level: PasswordLevel.strong,
        score: score,
        feedback: feedback,
        color: Colors.green,
        message: 'รหัสผ่านแข็งแรงมาก',
      );
    }
  }
  
  /// ตรวจสอบว่ารหัสผ่านผ่านขั้นต่ำหรือไม่
  static bool isValidPassword(String password) {
    final strength = checkPasswordStrength(password);
    return strength.score >= 3; // ต้องได้อย่างน้อย 3 คะแนน
  }
  
  /// ตรวจสอบว่ารหัสผ่านผ่านขั้นต่ำสำหรับ registration (6 ตัวอักษร)
  static bool isValidBasicPassword(String password) {
    return password.length >= 6;
  }
  
  /// ตรวจสอบว่ารหัสผ่านผ่านขั้นต่ำสำหรับ reset (8 ตัวอักษร)
  static bool isValidResetPassword(String password) {
    return password.length >= 8;
  }
  
  /// ดูข้อความแจ้งเตือนสำหรับรหัสผ่าน
  static String? getValidationMessage(String password, {bool isReset = false}) {
    if (password.isEmpty) {
      return 'กรุณากรอกรหัสผ่าน';
    }
    
    if (isReset) {
      if (password.length < 8) {
        return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
      }
    } else {
      if (password.length < 6) {
        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      }
    }
    
    return null;
  }
}

/// ระดับความแข็งแรงของรหัสผ่าน
enum PasswordLevel {
  weak,
  fair,
  good,
  strong,
}

/// ข้อมูลความแข็งแรงของรหัสผ่าน
class PasswordStrength {
  final PasswordLevel level;
  final int score;
  final List<String> feedback;
  final Color color;
  final String message;
  
  PasswordStrength({
    required this.level,
    required this.score,
    required this.feedback,
    required this.color,
    required this.message,
  });
  
  /// ดูว่าผ่านขั้นต่ำหรือไม่
  bool get isValid => score >= 3;
  
  /// ดูว่าแข็งแรงหรือไม่
  bool get isStrong => score >= 4;
  
  /// ดูว่าอ่อนหรือไม่
  bool get isWeak => score <= 2;
}

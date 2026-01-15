import 'dart:math';
import 'package:flutter/material.dart';

class OTPService {
  static String _generatedOTP = '';
  static DateTime? _otpExpiryTime;
  
  // Generate 6-digit OTP
  static String generateOTP() {
    final random = Random();
    _generatedOTP = (100000 + random.nextInt(900000)).toString();
    _otpExpiryTime = DateTime.now().add(const Duration(minutes: 5));
    return _generatedOTP;
  }
  
  // Verify OTP
  static bool verifyOTP(String inputOTP) {
    if (_otpExpiryTime == null || DateTime.now().isAfter(_otpExpiryTime!)) {
      return false; // OTP expired
    }
    
    return inputOTP == _generatedOTP;
  }
  
  // Check if OTP is expired
  static bool isOTPExpired() {
    if (_otpExpiryTime == null) return true;
    return DateTime.now().isAfter(_otpExpiryTime!);
  }
  
  // Get remaining time in seconds
  static int getRemainingSeconds() {
    if (_otpExpiryTime == null) return 0;
    final remaining = _otpExpiryTime!.difference(DateTime.now());
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }
  
  // Simulate sending OTP (in real app, use SMS service)
  static Future<bool> sendOTP(String phoneNumber) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate new OTP
      final otp = generateOTP();
      
      // In real app, send via SMS service like:
      // - Twilio
      // - AWS SNS
      // - Firebase Cloud Messaging
      // - Thai SMS services (SMS Thailand, etc.)
      
      debugPrint('OTP sent to $phoneNumber: $otp');
      
      return true;
    } catch (e) {
      debugPrint('Failed to send OTP: $e');
      return false;
    }
  }
  
  // Clear OTP
  static void clearOTP() {
    _generatedOTP = '';
    _otpExpiryTime = null;
  }
}

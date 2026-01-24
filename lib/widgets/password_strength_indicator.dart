import 'package:flutter/material.dart';
import '../utils/password_validator.dart';

/// Widget สำหรับแสดงความแข็งแรงของรหัสผ่าน
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;
  
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final strength = PasswordValidator.checkPasswordStrength(password);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        _buildProgressBar(strength),
        const SizedBox(height: 8),
        
        // Strength text
        _buildStrengthText(strength),
        
        // Requirements list
        if (showRequirements && strength.feedback.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRequirementsList(strength.feedback),
        ],
      ],
    );
  }
  
  /// สร้าง progress bar
  Widget _buildProgressBar(PasswordStrength strength) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey.shade300,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: strength.score / 5.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: strength.color,
          ),
        ),
      ),
    );
  }
  
  /// สร้างข้อความแสดงความแข็งแรง
  Widget _buildStrengthText(PasswordStrength strength) {
    return Row(
      children: [
        Icon(
          _getStrengthIcon(strength.level),
          size: 16,
          color: strength.color,
        ),
        const SizedBox(width: 6),
        Text(
          strength.message,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: strength.color,
          ),
        ),
      ],
    );
  }
  
  /// สร้างรายการความต้องการ
  Widget _buildRequirementsList(List<String> feedback) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ความต้องการ:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...feedback.map((requirement) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    requirement,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  /// ดู icon ตามความแข็งแรง
  IconData _getStrengthIcon(PasswordLevel level) {
    switch (level) {
      case PasswordLevel.weak:
        return Icons.error_outline;
      case PasswordLevel.fair:
        return Icons.warning_amber_outlined;
      case PasswordLevel.good:
        return Icons.check_circle_outline;
      case PasswordLevel.strong:
        return Icons.verified;
    }
  }
}

/// Widget สำหรับแสดงความแข็งแรงแบบง่าย (compact)
class CompactPasswordStrengthIndicator extends StatelessWidget {
  final String password;
  
  const CompactPasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final strength = PasswordValidator.checkPasswordStrength(password);
    
    return Row(
      children: [
        // Progress bar
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey.shade300,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: strength.score / 5.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: strength.color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Strength text
        Text(
          strength.message,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: strength.color,
          ),
        ),
      ],
    );
  }
}

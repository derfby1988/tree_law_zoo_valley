class DailyCouponShareToken {
  final String id;
  final String discountId;
  final String couponCode;
  final String couponAudience;
  final String shareToken;
  final int groupSize;
  final int maxUses;
  final int usesCount;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? revokedReason;
  final DateTime? lastUsedAt;
  final String? lastUsedMemberIdentifier;
  final String? lastUsedChannel;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyCouponShareToken({
    required this.id,
    required this.discountId,
    required this.couponCode,
    required this.couponAudience,
    required this.shareToken,
    required this.groupSize,
    required this.maxUses,
    required this.usesCount,
    required this.expiresAt,
    this.revokedAt,
    this.revokedReason,
    this.lastUsedAt,
    this.lastUsedMemberIdentifier,
    this.lastUsedChannel,
    this.metadata = const {},
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyCouponShareToken.fromMap(Map<String, dynamic> map) {
    return DailyCouponShareToken(
      id: map['id']?.toString() ?? '',
      discountId: map['discount_id']?.toString() ?? '',
      couponCode: map['coupon_code']?.toString() ?? '',
      couponAudience: map['coupon_audience']?.toString() ?? 'group',
      shareToken: map['share_token']?.toString() ?? '',
      groupSize: _intValue(map['group_size'], fallback: 2),
      maxUses: _intValue(map['max_uses'], fallback: 2),
      usesCount: _intValue(map['uses_count']),
      expiresAt: _parseDateTime(map['expires_at']) ?? DateTime.now(),
      revokedAt: _parseDateTime(map['revoked_at']),
      revokedReason: map['revoked_reason']?.toString(),
      lastUsedAt: _parseDateTime(map['last_used_at']),
      lastUsedMemberIdentifier: map['last_used_member_identifier']?.toString(),
      lastUsedChannel: map['last_used_channel']?.toString(),
      metadata: _mapValue(map['metadata']),
      createdBy: map['created_by']?.toString(),
      updatedBy: map['updated_by']?.toString(),
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'discount_id': discountId,
      'coupon_code': couponCode,
      'coupon_audience': couponAudience,
      'share_token': shareToken,
      'group_size': groupSize,
      'max_uses': maxUses,
      'uses_count': usesCount,
      'expires_at': expiresAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'revoked_reason': revokedReason,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'last_used_member_identifier': lastUsedMemberIdentifier,
      'last_used_channel': lastUsedChannel,
      'metadata': metadata,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DailyCouponShareToken copyWith({
    String? id,
    String? discountId,
    String? couponCode,
    String? couponAudience,
    String? shareToken,
    int? groupSize,
    int? maxUses,
    int? usesCount,
    DateTime? expiresAt,
    DateTime? revokedAt,
    String? revokedReason,
    DateTime? lastUsedAt,
    String? lastUsedMemberIdentifier,
    String? lastUsedChannel,
    Map<String, dynamic>? metadata,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyCouponShareToken(
      id: id ?? this.id,
      discountId: discountId ?? this.discountId,
      couponCode: couponCode ?? this.couponCode,
      couponAudience: couponAudience ?? this.couponAudience,
      shareToken: shareToken ?? this.shareToken,
      groupSize: groupSize ?? this.groupSize,
      maxUses: maxUses ?? this.maxUses,
      usesCount: usesCount ?? this.usesCount,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedReason: revokedReason ?? this.revokedReason,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastUsedMemberIdentifier: lastUsedMemberIdentifier ?? this.lastUsedMemberIdentifier,
      lastUsedChannel: lastUsedChannel ?? this.lastUsedChannel,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get remainingUses => maxUses - usesCount > 0 ? maxUses - usesCount : 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive => revokedAt == null && !isExpired && remainingUses > 0;

  String get shareTokenPreview {
    if (shareToken.length <= 10) return shareToken;
    return '${shareToken.substring(0, 6)}...${shareToken.substring(shareToken.length - 4)}';
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}

import 'package:flutter/material.dart';
import '../../models/pos_shift_model.dart';
import '../../widgets/pos_shift_widget.dart';

/// Header ของหน้า POS
///
/// รับข้อมูลและ callback ทั้งหมดจากภายนอก ไม่มี state เป็นของตัวเอง
/// ช่วยให้ [PosPage] อ่านง่ายขึ้นโดยไม่เปลี่ยน logic หรือ UI ใดๆ
class PosHeaderWidget extends StatelessWidget {
  const PosHeaderWidget({
    super.key,
    required this.brandName,
    required this.userName,
    required this.dateStr,
    required this.timeStr,
    this.orderType = 'walk_in',
    this.tableNumber,
    this.zoneName,
    this.customerName,
    this.customerPhone,
    this.selectedResponsibleStaff,
    required this.salesStaffUsers,
    this.currentShift,
    required this.onBack,
    required this.onTableTap,
    this.onMoveTable,
    this.onStoreTap,
    this.storeName,
    required this.onStaffSelected,
    required this.onOpenShift,
    required this.onCloseShift,
    required this.accentGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.bgColor,
    required this.cardColor,
    required this.borderColor,
    required this.iconGradient,
  });

  final String brandName;
  final String userName;
  final String dateStr;
  final String timeStr;
  final String orderType;
  final String? tableNumber;
  final String? zoneName;
  final String? customerName;
  final String? customerPhone;
  final Map<String, dynamic>? selectedResponsibleStaff;
  final List<Map<String, dynamic>> salesStaffUsers;
  final PosShift? currentShift;
  final VoidCallback onBack;
  final VoidCallback onTableTap;
  final VoidCallback? onMoveTable;
  final VoidCallback? onStoreTap;
  final String? storeName;
  final ValueChanged<Map<String, dynamic>?> onStaffSelected;
  final VoidCallback onOpenShift;
  final VoidCallback onCloseShift;
  final Color accentGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Color bgColor;
  final Color cardColor;
  final Color borderColor;
  final LinearGradient iconGradient;

  String get _tableLabel => tableNumber?.trim().isNotEmpty == true ? tableNumber!.trim() : '-';
  String get _orderTypeLabel => orderType == 'dine_in' ? 'Dine-in' : 'Walk-in';

  @override
  Widget build(BuildContext context) {
    final customerLabel = customerName?.trim().isNotEmpty == true ? customerName!.trim() : null;
    final customerPhoneLabel = customerPhone?.trim().isNotEmpty == true ? customerPhone!.trim() : null;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: _gradientIcon(Icons.arrow_back, size: 20),
            color: textSecondary,
            onPressed: onBack,
            tooltip: 'กลับ',
          ),
          const SizedBox(width: 8),
          _gradientIcon(Icons.storefront, size: 22),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              brandName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (storeName != null) ...[
                    InkWell(
                      onTap: onStoreTap,
                      borderRadius: BorderRadius.circular(6),
                      child: _headerChip(Icons.store_mall_directory, storeName!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (zoneName != null) ...[
                    InkWell(
                      onTap: onTableTap,
                      borderRadius: BorderRadius.circular(6),
                      child: _headerChip(Icons.store, zoneName!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    onTap: onTableTap,
                    borderRadius: BorderRadius.circular(6),
                    child: _headerChip(Icons.table_restaurant, orderType == 'dine_in' ? 'โต๊ะ $_tableLabel' : 'โต๊ะ -'),
                  ),
                  if (onMoveTable != null && orderType == 'dine_in' && tableNumber != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onMoveTable,
                      borderRadius: BorderRadius.circular(6),
                      child: Tooltip(
                        message: 'ย้ายโต๊ะ',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _gradientIcon(Icons.swap_horiz, size: 14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _headerChip(Icons.receipt_long, _orderTypeLabel),
                  if (customerLabel != null) ...[
                    const SizedBox(width: 8),
                    _headerChip(Icons.person_pin, customerLabel),
                  ],
                  if (customerPhoneLabel != null) ...[
                    const SizedBox(width: 8),
                    _headerChip(Icons.phone, customerPhoneLabel),
                  ],
                  const SizedBox(width: 8),
                  _buildResponsibleStaffSelector(context),
                  const SizedBox(width: 8),
                  PosShiftChip(
                    currentShift: currentShift,
                    onOpenShift: onOpenShift,
                    onCloseShift: onCloseShift,
                  ),
                  const SizedBox(width: 8),
                  _headerChip(Icons.calendar_today, dateStr),
                  const SizedBox(width: 8),
                  _headerChip(Icons.access_time, timeStr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsibleStaffSelector(BuildContext context) {
    final selected = selectedResponsibleStaff;
    final hasSelection = selected != null;

    return PopupMenuButton<String>(
      tooltip: 'เลือกพนักงานผู้รับผิดชอบ',
      enabled: salesStaffUsers.isNotEmpty,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (userId) {
        final selectedUser = salesStaffUsers.firstWhere(
          (user) => user['id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
        onStaffSelected(selectedUser.isEmpty ? null : selectedUser);
      },
      itemBuilder: (context) => salesStaffUsers
          .map(
            (user) => PopupMenuItem<String>(
              value: user['id']?.toString() ?? '',
              child: Row(
                children: [
                  Icon(
                    Icons.badge,
                    size: 18,
                    color: (user['id']?.toString() == selected?['id']?.toString())
                        ? accentGreen
                        : textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayFullNameFromUser(user),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasSelection ? bgColor : Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasSelection ? borderColor : Colors.orange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gradientIcon(Icons.badge, size: 14),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                hasSelection ? _displayNameFromUser(selected) : 'เลือกพนักงานรับผิดชอบ',
                style: TextStyle(
                  fontSize: 11,
                  color: hasSelection ? textSecondary : Colors.orange[800],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: hasSelection ? textSecondary : Colors.orange[800],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gradientIcon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _gradientIcon(IconData icon, {double size = 18}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  String _displayNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'ไม่ระบุ';
    final email = user['email']?.toString();
    final username = user['username']?.toString();
    final fullName = user['full_name']?.toString();
    return fullName != null
        ? _abbreviateStaffName(fullName)
        : username ??
            (email != null && email.contains('@') ? email.split('@').first : null) ??
            'ไม่ระบุ';
  }

  String _displayFullNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'ไม่ระบุ';
    final fullName = user['full_name']?.toString();
    final email = user['email']?.toString();
    final username = user['username']?.toString();
    return fullName ??
        username ??
        (email != null && email.contains('@') ? email.split('@').first : null) ??
        'ไม่ระบุ';
  }

  String _abbreviateStaffName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return fullName.trim();
    return '${parts.first} ${parts.last.substring(0, 1)}.';
  }
}

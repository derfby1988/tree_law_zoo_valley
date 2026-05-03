import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';

/// รายการหน้าทั้งหมดในระบบ พร้อมชื่อปุ่มที่เกี่ยวข้อง
final List<Map<String, dynamic>> _systemPages = [
  {'id': 'dashboard', 'name': 'หน้าหลัก', 'button': 'แดชบอร์ด', 'icon': Icons.dashboard},
  {'id': 'inventory', 'name': 'คลังสินค้า', 'button': 'สินค้า', 'icon': Icons.inventory},
  {'id': 'table_booking', 'name': 'จองโต๊ะ', 'button': 'จองโต๊ะ', 'icon': Icons.table_restaurant},
  {'id': 'room_booking', 'name': 'จองห้อง', 'button': 'จองห้อง', 'icon': Icons.meeting_room},
  {'id': 'restaurant_menu', 'name': 'เมนูร้านอาหาร', 'button': 'เมนู', 'icon': Icons.restaurant_menu},
  {'id': 'user_management', 'name': 'จัดการผู้ใช้', 'button': 'ผู้ใช้', 'icon': Icons.people},
  {'id': 'user_permissions', 'name': 'สิทธิ์ผู้ใช้', 'button': 'สิทธิ์', 'icon': Icons.security},
  {'id': 'user_groups', 'name': 'กลุ่มผู้ใช้', 'button': 'กลุ่ม', 'icon': Icons.group_work},
  {'id': 'reports', 'name': 'รายงาน', 'button': 'รายงาน', 'icon': Icons.bar_chart},
  {'id': 'settings', 'name': 'ตั้งค่า', 'button': 'ตั้งค่า', 'icon': Icons.settings},
  {'id': 'end_drawer', 'name': 'เมนูจัดการร้าน (End Drawer)', 'button': 'End Drawer', 'icon': Icons.menu_open},
  {'id': 'procurement', 'name': 'ระบบสั่งซื้อ', 'button': 'สั่งซื้อ', 'icon': Icons.shopping_cart},
  {'id': 'tax_rules_admin', 'name': 'จัดการกฎภาษี', 'button': 'กฎภาษี', 'icon': Icons.rule},
  {'id': 'pos', 'name': 'ขาย/POS', 'button': 'POS', 'icon': Icons.point_of_sale},
  {'id': 'stock_movement', 'name': 'Stock Movement', 'button': 'Movement', 'icon': Icons.swap_vert},
  {'id': 'table_management', 'name': 'จัดการโต๊ะและร้าน', 'button': 'โต๊ะ', 'icon': Icons.table_restaurant},
  {'id': 'coupon_promotion', 'name': 'จัดการคูปอง & โปรโมชั่น', 'button': 'คูปอง', 'icon': Icons.local_offer},
];

/// รายการ Tab ทั้งหมดในแต่ละหน้า
final List<Map<String, dynamic>> _systemTabs = [
  // คลังสินค้า (inventory) - 5 tabs
  {'id': 'inventory_overview', 'page_id': 'inventory', 'name': 'สถิติ / รายงาน', 'icon': Icons.dashboard},
  {'id': 'inventory_products', 'page_id': 'inventory', 'name': 'จัดการสินค้า', 'icon': Icons.inventory},
  {'id': 'inventory_adjustment', 'page_id': 'inventory', 'name': 'ปรับปรุงคลัง', 'icon': Icons.build},
  {'id': 'inventory_warehouse', 'page_id': 'inventory', 'name': 'สถานที่เก็บ', 'icon': Icons.warehouse},
  {'id': 'inventory_ingredients', 'page_id': 'inventory', 'name': 'จัดการวัตถุดิบ', 'icon': Icons.restaurant_menu},
  {'id': 'inventory_recipe', 'page_id': 'inventory', 'name': 'สูตรอาหาร', 'icon': Icons.dinner_dining},
  {'id': 'inventory_reports', 'page_id': 'inventory', 'name': 'รายงานคลัง', 'icon': Icons.insights},
  // จองโต๊ะ (table_booking)
  {'id': 'table_booking_main', 'page_id': 'table_booking', 'name': 'จองโต๊ะ', 'icon': Icons.table_restaurant},
  // จองห้อง (room_booking)
  {'id': 'room_booking_main', 'page_id': 'room_booking', 'name': 'จองห้อง', 'icon': Icons.meeting_room},
  // ระบบสั่งซื้อ (procurement) - 6 tabs
  {'id': 'procurement_request', 'page_id': 'procurement', 'name': 'ขอซื้อ', 'icon': Icons.request_page},
  {'id': 'procurement_order', 'page_id': 'procurement', 'name': 'วางใบสั่งซื้อ', 'icon': Icons.description},
  {'id': 'procurement_confirm', 'page_id': 'procurement', 'name': 'Confirm รับออเดอร์', 'icon': Icons.check_circle},
  {'id': 'procurement_ship', 'page_id': 'procurement', 'name': 'ส่งสินค้า', 'icon': Icons.local_shipping},
  {'id': 'procurement_receive', 'page_id': 'procurement', 'name': 'รับสินค้า', 'icon': Icons.inventory_2},
  {'id': 'procurement_audit', 'page_id': 'procurement', 'name': 'Audit Trail', 'icon': Icons.history},
  // Table Management (table_management)
  {'id': 'table_management_zones', 'page_id': 'table_management', 'name': 'จัดการร้าน/โซน', 'icon': Icons.store},
  {'id': 'table_management_tables', 'page_id': 'table_management', 'name': 'จัดการโต๊ะ', 'icon': Icons.table_restaurant},
  {'id': 'table_management_layout', 'page_id': 'table_management', 'name': 'ผังร้าน (Floor Plan)', 'icon': Icons.grid_view},
  {'id': 'table_management_types', 'page_id': 'table_management', 'name': 'ประเภทโต๊ะ', 'icon': Icons.category},
  // POS (pos)
  {'id': 'pos_main', 'page_id': 'pos', 'name': 'ขายสินค้า', 'icon': Icons.point_of_sale},
  // Stock Movement (stock_movement)
  {'id': 'stock_movement_main', 'page_id': 'stock_movement', 'name': 'รายงาน Movement', 'icon': Icons.swap_vert},
  // เมนูร้านอาหาร (restaurant_menu)
  {'id': 'restaurant_menu_main', 'page_id': 'restaurant_menu', 'name': 'เมนูอาหาร', 'icon': Icons.restaurant_menu},
  // จัดการผู้ใช้ (user_management)
  {'id': 'user_management_main', 'page_id': 'user_management', 'name': 'รายชื่อผู้ใช้', 'icon': Icons.people},
  // สิทธิ์ผู้ใช้ (user_permissions)
  {'id': 'user_permissions_main', 'page_id': 'user_permissions', 'name': 'กำหนดสิทธิ์', 'icon': Icons.security},
  // กลุ่มผู้ใช้ (user_groups)
  {'id': 'user_groups_main', 'page_id': 'user_groups', 'name': 'จัดการกลุ่ม', 'icon': Icons.group_work},
  // จัดการคูปอง & โปรโมชั่น (coupon_promotion)
  {'id': 'coupon_promotion_coupons', 'page_id': 'coupon_promotion', 'name': 'จัดการคูปอง', 'icon': Icons.local_offer},
  {'id': 'coupon_promotion_promotions', 'page_id': 'coupon_promotion', 'name': 'จัดการโปรโมชั่น', 'icon': Icons.celebration},
  {'id': 'coupon_promotion_analytics', 'page_id': 'coupon_promotion', 'name': 'วิเคราะห์การใช้งาน', 'icon': Icons.analytics},
];

/// รายการ Action/ปุ่มทั้งหมดในแต่ละ Tab
final List<Map<String, dynamic>> _systemActions = [
  // Tab: จัดการสินค้า (inventory_products)
  {'id': 'inventory_products_category', 'tab_id': 'inventory_products', 'name': 'จัดการประเภท', 'icon': Icons.folder},
  {'id': 'inventory_products_unit', 'tab_id': 'inventory_products', 'name': 'จัดการหน่วยนับ', 'icon': Icons.scale},
  {'id': 'inventory_products_add', 'tab_id': 'inventory_products', 'name': 'เพิ่มสินค้า', 'icon': Icons.add_circle},
  {'id': 'inventory_products_produce', 'tab_id': 'inventory_products', 'name': 'ผลิตสินค้า', 'icon': Icons.factory},
  {'id': 'inventory_products_edit', 'tab_id': 'inventory_products', 'name': 'แก้ไขสินค้า', 'icon': Icons.edit},
  {'id': 'inventory_products_delete', 'tab_id': 'inventory_products', 'name': 'ลบสินค้า', 'icon': Icons.delete},
  // Tab: ปรับปรุงคลัง (inventory_adjustment)
  {'id': 'inventory_adjustment_shelf', 'tab_id': 'inventory_adjustment', 'name': '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e0a\u0e31\u0e49\u0e19\u0e27\u0e32\u0e07', 'icon': Icons.shelves},
  {'id': 'inventory_adjustment_purchase', 'tab_id': 'inventory_adjustment', 'name': '\u0e23\u0e31\u0e1a\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32', 'icon': Icons.add_shopping_cart},
  {'id': 'inventory_adjustment_withdraw', 'tab_id': 'inventory_adjustment', 'name': '\u0e40\u0e1a\u0e34\u0e01\u0e43\u0e0a\u0e49', 'icon': Icons.outbox},
  {'id': 'inventory_adjustment_damage', 'tab_id': 'inventory_adjustment', 'name': 'ตัดสินค้าเสีย', 'icon': Icons.delete_forever},
  {'id': 'inventory_adjustment_count', 'tab_id': 'inventory_adjustment', 'name': 'ตรวจนับสต๊อก', 'icon': Icons.inventory_2},
  {'id': 'inventory_adjustment_warehouse_add', 'tab_id': 'inventory_adjustment', 'name': 'เพิ่มคลังสินค้า', 'icon': Icons.add_business},
  {'id': 'inventory_adjustment_warehouse_edit', 'tab_id': 'inventory_adjustment', 'name': 'แก้ไขคลังสินค้า', 'icon': Icons.edit},
  {'id': 'inventory_adjustment_warehouse_delete', 'tab_id': 'inventory_adjustment', 'name': 'ลบคลังสินค้า', 'icon': Icons.delete},
  {'id': 'inventory_adjustment_product_move_shelf', 'tab_id': 'inventory_adjustment', 'name': 'ย้ายสินค้าไปชั้นวางอื่น', 'icon': Icons.move_up},
  {'id': 'inventory_adjustment_product_move_warehouse', 'tab_id': 'inventory_adjustment', 'name': 'โอนสินค้าไปคลังอื่น', 'icon': Icons.warehouse},
  {'id': 'inventory_adjustment_approve', 'tab_id': 'inventory_adjustment', 'name': 'อนุมัติการปรับปรุง', 'icon': Icons.verified},
  {'id': 'inventory_ingredients_count', 'tab_id': 'inventory_adjustment', 'name': 'ตรวจนับวัตถุดิบ', 'icon': Icons.checklist},
  {'id': 'inventory_reports_view', 'tab_id': 'inventory_reports', 'name': 'ดูรายงานคลังสินค้า', 'icon': Icons.insights},
  // Tab: สถานที่เก็บ (inventory_warehouse)
  {'id': 'inventory_warehouse_manage', 'tab_id': 'inventory_warehouse', 'name': 'จัดการคลัง/โซน', 'icon': Icons.account_tree},
  {'id': 'inventory_warehouse_manager', 'tab_id': 'inventory_warehouse', 'name': 'กำหนดผู้ดูแล', 'icon': Icons.admin_panel_settings},
  {'id': 'inventory_transfer_request', 'tab_id': 'inventory_warehouse', 'name': 'สร้างคำขอโอน', 'icon': Icons.add_business},
  {'id': 'inventory_transfer_approve', 'tab_id': 'inventory_warehouse', 'name': 'อนุมัติคำขอโอน', 'icon': Icons.check_circle},
  // Tab: จัดการวัตถุดิบ (inventory_ingredients)
  {'id': 'inventory_ingredients_category', 'tab_id': 'inventory_ingredients', 'name': 'จัดการประเภท', 'icon': Icons.folder},
  {'id': 'inventory_ingredients_unit', 'tab_id': 'inventory_ingredients', 'name': 'จัดการหน่วยนับ', 'icon': Icons.scale},
  {'id': 'inventory_ingredients_add', 'tab_id': 'inventory_ingredients', 'name': 'เพิ่มวัตถุดิบ', 'icon': Icons.add_circle},
  {'id': 'inventory_ingredients_edit', 'tab_id': 'inventory_ingredients', 'name': 'แก้ไขวัตถุดิบ', 'icon': Icons.edit},
  {'id': 'inventory_ingredients_delete', 'tab_id': 'inventory_ingredients', 'name': 'ลบวัตถุดิบ', 'icon': Icons.delete},
  // Tab: สูตรอาหาร (inventory_recipe)
  {'id': 'inventory_recipe_add', 'tab_id': 'inventory_recipe', 'name': 'เพิ่มสูตร', 'icon': Icons.add},
  {'id': 'inventory_recipe_edit', 'tab_id': 'inventory_recipe', 'name': 'แก้ไขสูตร', 'icon': Icons.edit},
  {'id': 'inventory_recipe_delete', 'tab_id': 'inventory_recipe', 'name': 'ลบสูตร', 'icon': Icons.delete},
  {'id': 'inventory_recipe_produce', 'tab_id': 'inventory_recipe', 'name': 'ผลิตสินค้า', 'icon': Icons.play_arrow},
  {'id': 'inventory_recipe_category', 'tab_id': 'inventory_recipe', 'name': 'จัดการประเภทสูตร', 'icon': Icons.settings},
  // Tab: จองโต๊ะ (table_booking_main)
  {'id': 'table_booking_book', 'tab_id': 'table_booking_main', 'name': 'จองโต๊ะ', 'icon': Icons.book_online},
  // Tab: จองห้อง (room_booking_main)
  {'id': 'room_booking_book', 'tab_id': 'room_booking_main', 'name': 'จองห้อง', 'icon': Icons.book_online},
  // Tab: เมนูอาหาร (restaurant_menu_main)
  {'id': 'restaurant_menu_order', 'tab_id': 'restaurant_menu_main', 'name': 'สั่งอาหาร', 'icon': Icons.shopping_cart},
  // Tab: จัดการกลุ่ม (user_groups_main)
  {'id': 'user_groups_create', 'tab_id': 'user_groups_main', 'name': 'สร้างกลุ่ม', 'icon': Icons.group_add},
  {'id': 'user_groups_edit', 'tab_id': 'user_groups_main', 'name': 'แก้ไขกลุ่ม', 'icon': Icons.edit},
  {'id': 'user_groups_delete', 'tab_id': 'user_groups_main', 'name': 'ลบกลุ่ม', 'icon': Icons.delete},
  {'id': 'user_groups_sort_order', 'tab_id': 'user_groups_main', 'name': 'จัดลำดับกลุ่ม', 'icon': Icons.swap_vert},
  // Tab: จัดการร้าน/โซน (table_management_zones)
  {'id': 'table_management_zones_add', 'tab_id': 'table_management_zones', 'name': 'เพิ่มร้าน/โซน', 'icon': Icons.add_business},
  {'id': 'table_management_zones_edit', 'tab_id': 'table_management_zones', 'name': 'แก้ไขร้าน/โซน', 'icon': Icons.edit},
  {'id': 'table_management_zones_delete', 'tab_id': 'table_management_zones', 'name': 'ลบร้าน/โซน', 'icon': Icons.delete},
  // Tab: จัดการโต๊ะ (table_management_tables)
  {'id': 'table_management_tables_add', 'tab_id': 'table_management_tables', 'name': 'เพิ่มโต๊ะ', 'icon': Icons.add},
  {'id': 'table_management_tables_edit', 'tab_id': 'table_management_tables', 'name': 'แก้ไขโต๊ะ', 'icon': Icons.edit},
  {'id': 'table_management_tables_delete', 'tab_id': 'table_management_tables', 'name': 'ลบโต๊ะ', 'icon': Icons.delete},
  // Tab: ผังร้าน (table_management_layout)
  {'id': 'table_management_layout_move', 'tab_id': 'table_management_layout', 'name': 'ย้ายโต๊ะบนผัง', 'icon': Icons.open_with},
  {'id': 'table_management_layout_element_add', 'tab_id': 'table_management_layout', 'name': 'เพิ่มข้อความ/รูปทรง', 'icon': Icons.add_box},
  {'id': 'table_management_layout_element_delete', 'tab_id': 'table_management_layout', 'name': 'ลบข้อความ/รูปทรง', 'icon': Icons.delete},
  // Tab: ประเภทโต๊ะ (table_management_types)
  {'id': 'table_management_types_add', 'tab_id': 'table_management_types', 'name': 'เพิ่มประเภทโต๊ะ', 'icon': Icons.add},
  {'id': 'table_management_types_edit', 'tab_id': 'table_management_types', 'name': 'แก้ไขประเภทโต๊ะ', 'icon': Icons.edit},
  {'id': 'table_management_types_delete', 'tab_id': 'table_management_types', 'name': 'ลบประเภทโต๊ะ', 'icon': Icons.delete},
  // Tab: จองโต๊ะ (table_booking_main)
  {'id': 'table_booking_create', 'tab_id': 'table_booking_main', 'name': 'สร้างการจอง', 'icon': Icons.book_online},
  {'id': 'table_booking_cancel', 'tab_id': 'table_booking_main', 'name': 'ยกเลิกการจอง', 'icon': Icons.cancel},
  // Tab: POS (pos_main)
  {'id': 'pos_main_sell', 'tab_id': 'pos_main', 'name': 'ขายสินค้า', 'icon': Icons.point_of_sale},
  {'id': 'pos_main_discount', 'tab_id': 'pos_main', 'name': 'ให้ส่วนลด', 'icon': Icons.discount},
  {'id': 'pos_main_void', 'tab_id': 'pos_main', 'name': 'ยกเลิกรายการ', 'icon': Icons.cancel},
  // Tab: Stock Movement (stock_movement_main)
  {'id': 'stock_movement_main_view', 'tab_id': 'stock_movement_main', 'name': 'ดูรายงาน', 'icon': Icons.visibility},
  {'id': 'stock_movement_main_export', 'tab_id': 'stock_movement_main', 'name': 'ส่งออกรายงาน', 'icon': Icons.file_download},
  // Tab: รับสินค้า (procurement_receive)
  {'id': 'procurement_receive_add', 'tab_id': 'procurement_receive', 'name': 'รับสินค้าเข้า', 'icon': Icons.add_shopping_cart},
  // Tab: ขอซื้อ (procurement_request)
  {'id': 'procurement_request_create', 'tab_id': 'procurement_request', 'name': 'สร้างใบขอซื้อ', 'icon': Icons.add},
  {'id': 'procurement_request_edit', 'tab_id': 'procurement_request', 'name': 'แก้ไขใบขอซื้อ', 'icon': Icons.edit},
  {'id': 'procurement_request_delete', 'tab_id': 'procurement_request', 'name': 'ลบใบขอซื้อ', 'icon': Icons.delete},
  {'id': 'procurement_request_submit', 'tab_id': 'procurement_request', 'name': 'ส่งอนุมัติ', 'icon': Icons.send},
  // Tab: วางใบสั่งซื้อ (procurement_order)
  {'id': 'procurement_order_create', 'tab_id': 'procurement_order', 'name': 'สร้างใบสั่งซื้อ', 'icon': Icons.description},
  {'id': 'procurement_order_edit', 'tab_id': 'procurement_order', 'name': 'แก้ไขใบสั่งซื้อ', 'icon': Icons.edit},
  {'id': 'procurement_order_delete', 'tab_id': 'procurement_order', 'name': 'ลบใบสั่งซื้อ', 'icon': Icons.delete},
  {'id': 'procurement_order_send', 'tab_id': 'procurement_order', 'name': 'ส่งใบสั่งซื้อ', 'icon': Icons.send},
  // Tab: Confirm รับออเดอร์ (procurement_confirm)
  {'id': 'procurement_confirm_approve', 'tab_id': 'procurement_confirm', 'name': 'อนุมัติออเดอร์', 'icon': Icons.check_circle},
  {'id': 'procurement_confirm_reject', 'tab_id': 'procurement_confirm', 'name': 'ปฏิเสธออเดอร์', 'icon': Icons.cancel},
  {'id': 'procurement_confirm_view', 'tab_id': 'procurement_confirm', 'name': 'ดูรายละเอียด', 'icon': Icons.visibility},
  // Tab: ส่งสินค้า (procurement_ship)
  {'id': 'procurement_ship_create', 'tab_id': 'procurement_ship', 'name': 'สร้างใบส่งของ', 'icon': Icons.local_shipping},
  {'id': 'procurement_ship_track', 'tab_id': 'procurement_ship', 'name': 'ติดตามการส่ง', 'icon': Icons.gps_fixed},
  {'id': 'procurement_ship_complete', 'tab_id': 'procurement_ship', 'name': 'ยืนยันการส่ง', 'icon': Icons.done_all},
  // Tab: รับสินค้า (procurement_receive)
  {'id': 'procurement_receive_confirm', 'tab_id': 'procurement_receive', 'name': 'ยืนยันรับของ', 'icon': Icons.inventory_2},
  {'id': 'procurement_receive_inspect', 'tab_id': 'procurement_receive', 'name': 'ตรวจสอบสินค้า', 'icon': Icons.search},
  {'id': 'procurement_receive_return', 'tab_id': 'procurement_receive', 'name': 'คืนสินค้า', 'icon': Icons.keyboard_return},
  // Tab: Audit Trail (procurement_audit)
  {'id': 'procurement_audit_view', 'tab_id': 'procurement_audit', 'name': 'ดู Audit Trail', 'icon': Icons.visibility},
  {'id': 'procurement_audit_export', 'tab_id': 'procurement_audit', 'name': 'ส่งออก Audit Trail', 'icon': Icons.file_download},
  // Tab: จัดการคูปอง (coupon_promotion_coupons)
  {'id': 'coupon_promotion_coupons_add', 'tab_id': 'coupon_promotion_coupons', 'name': 'เพิ่มคูปอง', 'icon': Icons.add_circle},
  {'id': 'coupon_promotion_coupons_edit', 'tab_id': 'coupon_promotion_coupons', 'name': 'แก้ไขคูปอง', 'icon': Icons.edit},
  {'id': 'coupon_promotion_coupons_delete', 'tab_id': 'coupon_promotion_coupons', 'name': 'ลบคูปอง', 'icon': Icons.delete},
  {'id': 'coupon_promotion_coupons_activate', 'tab_id': 'coupon_promotion_coupons', 'name': 'เปิด/ปิดคูปอง', 'icon': Icons.toggle_on},
  {'id': 'coupon_promotion_coupons_archive', 'tab_id': 'coupon_promotion_coupons', 'name': 'เก็บถาวรคูปอง', 'icon': Icons.archive},
  {'id': 'coupon_promotion_coupons_duplicate', 'tab_id': 'coupon_promotion_coupons', 'name': 'ทำสำเนาคูปอง', 'icon': Icons.copy},
  // Tab: จัดการโปรโมชั่น (coupon_promotion_promotions)
  {'id': 'coupon_promotion_promotions_add', 'tab_id': 'coupon_promotion_promotions', 'name': 'เพิ่มโปรโมชั่น', 'icon': Icons.add_circle},
  {'id': 'coupon_promotion_promotions_edit', 'tab_id': 'coupon_promotion_promotions', 'name': 'แก้ไขโปรโมชั่น', 'icon': Icons.edit},
  {'id': 'coupon_promotion_promotions_delete', 'tab_id': 'coupon_promotion_promotions', 'name': 'ลบโปรโมชั่น', 'icon': Icons.delete},
  {'id': 'coupon_promotion_promotions_activate', 'tab_id': 'coupon_promotion_promotions', 'name': 'เปิด/ปิดโปรโมชั่น', 'icon': Icons.toggle_on},
  {'id': 'coupon_promotion_promotions_archive', 'tab_id': 'coupon_promotion_promotions', 'name': 'เก็บถาวรโปรโมชั่น', 'icon': Icons.archive},
  {'id': 'coupon_promotion_promotions_duplicate', 'tab_id': 'coupon_promotion_promotions', 'name': 'ทำสำเนาโปรโมชั่น', 'icon': Icons.copy},
  // Tab: วิเคราะห์การใช้งาน (coupon_promotion_analytics)
  {'id': 'coupon_promotion_analytics_view', 'tab_id': 'coupon_promotion_analytics', 'name': 'ดูรายงานการใช้งาน', 'icon': Icons.visibility},
  {'id': 'coupon_promotion_analytics_view_detail', 'tab_id': 'coupon_promotion_analytics', 'name': 'ดูรายละเอียดออเดอร์', 'icon': Icons.receipt_long},
  {'id': 'coupon_promotion_analytics_export', 'tab_id': 'coupon_promotion_analytics', 'name': 'ส่งออกรายงาน', 'icon': Icons.file_download},
];

class UserPermissionsPage extends StatefulWidget {
  final Map<String, dynamic>? initialGroup;
  
  const UserPermissionsPage({super.key, this.initialGroup});

  @override
  State<UserPermissionsPage> createState() => _UserPermissionsPageState();
}

class _UserPermissionsPageState extends State<UserPermissionsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _userGroups = [];
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _pagePermissions = [];
  List<Map<String, dynamic>> _tabPermissions = [];
  List<Map<String, dynamic>> _actionPermissions = [];
  Map<String, dynamic>? _selectedGroup;
  String? _updatingPageId; // Track which page is being updated
  String? _updatingTabId;
  String? _updatingActionId;
  
  // Search controllers
  final TextEditingController _groupSearchController = TextEditingController();
  String _groupSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _groupSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // โหลดข้อมูลกลุ่มผู้ใช้
      final groupsResponse = await SupabaseService.client
          .from('user_groups')
          .select('*')
          .eq('is_active', true)
          .order('group_name', ascending: true);

      // โหลดข้อมูล permissions (user-group mapping)
      final permissionsResponse = await SupabaseService.client
          .from('user_group_members')
          .select('*');

      // โหลดข้อมูลผู้ใช้ (สำหรับแสดงในกลุ่ม) - ใช้ public.users เป็นหลัก
      List<dynamic> usersResponse = [];
      try {
        usersResponse = await SupabaseService.client
            .from('users')
            .select('id, full_name, email, username, avatar_url, is_active')
            .order('full_name', ascending: true);
      } catch (_) {}
      // Fallback: ถ้า public.users อ่านไม่ได้ ลอง user_profiles
      if (usersResponse.isEmpty) {
        try {
          usersResponse = await SupabaseService.client
              .from('user_profiles')
              .select('*')
              .eq('is_active', true)
              .order('full_name', ascending: true);
        } catch (_) {
          usersResponse = [];
        }
      }
      print('📋 Loaded ${usersResponse.length} users');

      // โหลดข้อมูลสิทธิ์การเข้าถึงหน้า (group_page_permissions)
      final pagePermissionsResponse = await SupabaseService.client
          .from('group_page_permissions')
          .select('*');

      // โหลดข้อมูลสิทธิ์ Tab
      List<dynamic> tabPermissionsResponse = [];
      try {
        tabPermissionsResponse = await SupabaseService.client
            .from('group_tab_permissions')
            .select('*');
      } catch (_) {}

      // โหลดข้อมูลสิทธิ์ Action/ปุ่ม
      List<dynamic> actionPermissionsResponse = [];
      try {
        actionPermissionsResponse = await SupabaseService.client
            .from('group_action_permissions')
            .select('*');
      } catch (_) {}

      final loadedGroups = List<Map<String, dynamic>>.from(groupsResponse);
      final loadedUsers = List<Map<String, dynamic>>.from(usersResponse)
          .map((u) {
            // Normalize: many schemas use user_profiles.user_id as the auth user id.
            final userId = u['user_id']?.toString();
            if (userId != null && userId.isNotEmpty) {
              return {
                ...u,
                'id': userId,
              };
            }
            return u;
          })
          .toList();
      
      setState(() {
        _userGroups = loadedGroups;
        _permissions = List<Map<String, dynamic>>.from(permissionsResponse);
        _pagePermissions = List<Map<String, dynamic>>.from(pagePermissionsResponse);
        _tabPermissions = List<Map<String, dynamic>>.from(tabPermissionsResponse);
        _actionPermissions = List<Map<String, dynamic>>.from(actionPermissionsResponse);
        _users = loadedUsers;
        
        // ถ้ามี initialGroup ให้เลือกกลุ่มนั้นอัตโนมัติ
        if (widget.initialGroup != null) {
          _selectedGroup = loadedGroups.firstWhere(
            (g) => g['id'] == widget.initialGroup!['id'],
            orElse: () => widget.initialGroup!,
          );
        }
        
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMemberActive(String groupId, String userId, bool isActive) async {
    try {
      await SupabaseService.client.rpc('toggle_user_active', params: {
        'p_user_id': userId,
        'p_is_active': isActive,
      });
    } catch (e) {
      print('⚠️ Toggle user is_active failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถอัปเดตสถานะผู้ใช้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupMembersViaRpc(String groupId) async {
    try {
      final response = await SupabaseService.client
          .rpc('get_group_members', params: {'p_group_id': groupId});
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('⚠️ RPC get_group_members failed: $e');
      // Fallback: ดึงจาก _permissions + _users
      final groupUserIds = _permissions
          .where((p) => p['group_id'] == groupId)
          .map((p) => p['user_id'].toString())
          .toSet();
      final matched = _users
          .where((u) => groupUserIds.contains(u['id'].toString()))
          .toList();
      if (matched.isNotEmpty) return matched;
      // Fallback สุดท้าย: ลองดึงจาก users/user_profiles
      return _fetchUsersByIdsFromUsersTable(groupUserIds);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersByIdsFromUsersTable(Set<String> userIds) async {
    if (userIds.isEmpty) return [];

    // 1) Try public.users
    try {
      final response = await SupabaseService.client
          .from('users')
          .select('id, full_name, email, username')
          .inFilter('id', userIds.toList());
      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    // 2) Fallback: try user_profiles (common schema: user_id)
    try {
      final response = await SupabaseService.client
          .from('user_profiles')
          .select('user_id, full_name, email')
          .inFilter('user_id', userIds.toList());
      final rows = List<Map<String, dynamic>>.from(response)
          .map((u) => {
                ...u,
                'id': (u['user_id'] ?? '').toString(),
              })
          .toList();
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    // 3) Fallback: some schemas store membership using user_profiles.id (profile PK)
    try {
      final response = await SupabaseService.client
          .from('user_profiles')
          .select('id, user_id, full_name, email')
          .inFilter('id', userIds.toList());
      final rows = List<Map<String, dynamic>>.from(response)
          .map((u) => {
                ...u,
                'id': (u['id'] ?? '').toString(),
              })
          .toList();
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    return [];
  }

  Future<void> _updateGroupUsers(String groupId, List<String> userIds) async {
    try {
      await SupabaseService.client
          .from('user_group_members')
          .delete()
          .eq('group_id', groupId);

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      for (final userId in userIds) {
        await SupabaseService.client.from('user_group_members').insert({
          'user_id': userId,
          'group_id': groupId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตสมาชิกกลุ่มสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสมาชิกกลุ่ม: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGroupPermissionDialog(Map<String, dynamic> group) {
    final groupUserIds = _permissions
        .where((p) => p['group_id'] == group['id'])
        .map((p) => p['user_id'].toString())
        .toSet();

    final groupColor = _hexToColor(group['color']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'จัดการสมาชิกกลุ่ม',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: groupColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['group_name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _darkenColor(groupColor, 0.2),
                            ),
                          ),
                          if (group['group_description'] != null)
                            Text(
                              group['group_description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'เลือกผู้ใช้ที่อยู่ในกลุ่มนี้:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isSelected = groupUserIds.contains(user['id'].toString());
                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: groupColor,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            groupUserIds.add(user['id'].toString());
                          } else {
                            groupUserIds.remove(user['id'].toString());
                          }
                        });
                      },
                      title: Text(user['full_name'] ?? 'ไม่ระบุชื่อ'),
                      subtitle: Text(user['email'] ?? ''),
                      secondary: CircleAvatar(
                        backgroundColor: groupColor.withOpacity(0.15),
                        child: Text(
                          (user['full_name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(color: groupColor),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    text: 'บันทึก',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateGroupUsers(group['id'], groupUserIds.toList());
                    },
                    backgroundColor: groupColor,
                    icon: Icons.save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// แปลง HEX string เป็น Color
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4CAF50);
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFF4CAF50);
    }
  }

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }


  void _showGroupUsersDialog(Map<String, dynamic> group) {
    setState(() {
      _selectedGroup = group;
    });

    final groupId = group['id'] as String;

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'ผู้ใช้ในกลุ่ม',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(
                      Icons.group,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['group_name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (group['group_description'] != null)
                          Text(
                            group['group_description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Users List - ใช้ RPC get_group_members เพื่อ bypass RLS
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchGroupMembersViaRpc(groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                final members = snapshot.data ?? [];

                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      children: [
                        Text(
                          'ผู้ใช้ที่มีสิทธิ์ในกลุ่มนี้ (${members.length} คน):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: BoxConstraints(maxHeight: 300),
                          child: members.isEmpty
                              ? Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'ยังไม่มีผู้ใช้ในกลุ่มนี้',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: members.length,
                                  itemBuilder: (context, index) {
                                    final user = members[index];
                                    final displayName = (user['full_name'] ?? user['username'] ?? 'ไม่ระบุชื่อ').toString();
                                    final displayEmail = (user['email'] ?? '').toString();
                                    final isActive = user['is_active'] == true;
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                                      title: Text(
                                        displayName,
                                        style: TextStyle(
                                          color: isActive ? Colors.black87 : Colors.grey,
                                          decoration: isActive ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      subtitle: Text(
                                        displayEmail,
                                        style: TextStyle(
                                          color: isActive ? Colors.grey[600] : Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Switch(
                                        value: isActive,
                                        activeColor: Color(0xFF2E7D32),
                                        onChanged: (val) async {
                                          setDialogState(() {
                                            members[index] = {...user, 'is_active': val};
                                          });
                                          await _toggleMemberActive(
                                            groupId,
                                            user['user_id'].toString(),
                                            val,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassButton(
                  text: 'ปิด',
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง Dialog จัดการสิทธิ์การเข้าถึงหน้าต่างๆ ของกลุ่ม
  void _showPagePermissionsDialog(Map<String, dynamic> group) {
    final groupColor = _hexToColor(group['color']);
    
    // โหลดสิทธิ์ปัจจุบันของกลุ่มจาก _pagePermissions
    final groupPagePermissions = _pagePermissions
        .where((p) => p['group_id'] == group['id'] && p['can_access'] == true)
        .map((p) => p['page_id'] as String)
        .toList();
    final selectedPages = Set<String>.from(groupPagePermissions);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'กำหนดสิทธิ์การเข้าถึง',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group Info Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: groupColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['group_name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _darkenColor(groupColor, 0.2),
                            ),
                          ),
                          Text(
                            'เลือกหน้าที่กลุ่มนี้สามารถเข้าถึงได้',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Page List with Checkboxes
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _systemPages.length,
                  itemBuilder: (context, index) {
                    final page = _systemPages[index];
                    final hasPermission = selectedPages.contains(page['id']);
                    
                    return CheckboxListTile(
                      value: hasPermission,
                      activeColor: groupColor,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedPages.add(page['id'] as String);
                          } else {
                            selectedPages.remove(page['id']);
                          }
                        });
                      },
                      title: Text(
                        page['name'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'ปุ่ม: ${page['button']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      secondary: hasPermission 
                        ? Icon(Icons.check_circle, color: groupColor)
                        : Icon(Icons.circle_outlined, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    text: 'บันทึก',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updatePagePermissions(
                        group['id'], 
                        selectedPages.toList(),
                      );
                    },
                    backgroundColor: groupColor,
                    icon: Icons.save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle page permission immediately
  Future<void> _togglePagePermission(String groupId, String pageId, bool enable) async {
    setState(() {
      _updatingPageId = pageId;
    });
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      if (enable) {
        // Insert new permission
        await SupabaseService.client.from('group_page_permissions').insert({
          'group_id': groupId,
          'page_id': pageId,
          'can_access': true,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Remove permission
        await SupabaseService.client
            .from('group_page_permissions')
            .delete()
            .eq('group_id', groupId)
            .eq('page_id', pageId);
        // Cascade: ปิดหน้า → ปิด tab + action ทั้งหมดในหน้านั้น
        await _cascadeDisablePage(groupId, pageId);
      }

      // Update local state
      setState(() {
        if (enable) {
          _pagePermissions.add({
            'group_id': groupId,
            'page_id': pageId,
            'can_access': true,
            'assigned_by': currentUser.id,
            'assigned_at': DateTime.now().toIso8601String(),
          });
        } else {
          _pagePermissions.removeWhere(
            (p) => p['group_id'] == groupId && p['page_id'] == pageId,
          );
        }
        _updatingPageId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'เปิดใช้งานสิทธิ์สำเร็จ' : 'ปิดใช้งานสิทธิ์สำเร็จ'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _updatingPageId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสิทธิ์: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  /// Toggle tab permission immediately
  Future<void> _toggleTabPermission(String groupId, String tabId, bool enable) async {
    setState(() {
      _updatingTabId = tabId;
    });
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      if (enable) {
        await SupabaseService.client.from('group_tab_permissions').insert({
          'group_id': groupId,
          'tab_id': tabId,
          'can_access': true,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
        setState(() {
          _tabPermissions.add({
            'group_id': groupId,
            'tab_id': tabId,
            'can_access': true,
          });
        });
      } else {
        // Cascade: ปิด tab → ปิด action ทั้งหมดใน tab นั้น
        final actionsInTab = _systemActions
            .where((a) => a['tab_id'] == tabId)
            .map((a) => a['id'] as String)
            .toList();
        
        await SupabaseService.client
            .from('group_tab_permissions')
            .delete()
            .eq('group_id', groupId)
            .eq('tab_id', tabId);

        // ลบ action permissions ที่อยู่ใน tab นี้
        for (final actionId in actionsInTab) {
          await SupabaseService.client
              .from('group_action_permissions')
              .delete()
              .eq('group_id', groupId)
              .eq('action_id', actionId);
        }

        setState(() {
          _tabPermissions.removeWhere(
            (p) => p['group_id'] == groupId && p['tab_id'] == tabId,
          );
          _actionPermissions.removeWhere(
            (p) => p['group_id'] == groupId && actionsInTab.contains(p['action_id']),
          );
        });
      }

      setState(() {
        _updatingTabId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'เปิดใช้งาน Tab สำเร็จ' : 'ปิดใช้งาน Tab สำเร็จ'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _updatingTabId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสิทธิ์ Tab: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Toggle action permission immediately
  Future<void> _toggleActionPermission(String groupId, String actionId, bool enable) async {
    setState(() {
      _updatingActionId = actionId;
    });
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      if (enable) {
        await SupabaseService.client.from('group_action_permissions').insert({
          'group_id': groupId,
          'action_id': actionId,
          'can_access': true,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
        setState(() {
          _actionPermissions.add({
            'group_id': groupId,
            'action_id': actionId,
            'can_access': true,
          });
        });
      } else {
        await SupabaseService.client
            .from('group_action_permissions')
            .delete()
            .eq('group_id', groupId)
            .eq('action_id', actionId);
        setState(() {
          _actionPermissions.removeWhere(
            (p) => p['group_id'] == groupId && p['action_id'] == actionId,
          );
        });
      }

      setState(() {
        _updatingActionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'เปิดใช้งานปุ่มสำเร็จ' : 'ปิดใช้งานปุ่มสำเร็จ'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _updatingActionId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสิทธิ์ปุ่ม: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Cascade: ปิดหน้า → ปิด tab ทั้งหมด → ปิด action ทั้งหมด
  Future<void> _cascadeDisablePage(String groupId, String pageId) async {
    final tabsInPage = _systemTabs
        .where((t) => t['page_id'] == pageId)
        .map((t) => t['id'] as String)
        .toList();

    for (final tabId in tabsInPage) {
      // ลบ tab permission
      try {
        await SupabaseService.client
            .from('group_tab_permissions')
            .delete()
            .eq('group_id', groupId)
            .eq('tab_id', tabId);
      } catch (_) {}

      // ลบ action permissions ใน tab
      final actionsInTab = _systemActions
          .where((a) => a['tab_id'] == tabId)
          .map((a) => a['id'] as String)
          .toList();
      for (final actionId in actionsInTab) {
        try {
          await SupabaseService.client
              .from('group_action_permissions')
              .delete()
              .eq('group_id', groupId)
              .eq('action_id', actionId);
        } catch (_) {}
      }
    }

    setState(() {
      _tabPermissions.removeWhere(
        (p) => p['group_id'] == groupId && tabsInPage.contains(p['tab_id']),
      );
      final allActionsInPage = _systemActions
          .where((a) => tabsInPage.contains(a['tab_id']))
          .map((a) => a['id'] as String)
          .toSet();
      _actionPermissions.removeWhere(
        (p) => p['group_id'] == groupId && allActionsInPage.contains(p['action_id']),
      );
    });
  }

  /// ใช้ตาราง group_page_permissions
  Future<void> _updatePagePermissions(String groupId, List<String> pageIds) async {
    try {
      // ลบสิทธิ์เดิมทั้งหมดของกลุ่มนี้
      await SupabaseService.client
          .from('group_page_permissions')
          .delete()
          .eq('group_id', groupId);

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      // เพิ่มสิทธิ์ใหม่
      for (final pageId in pageIds) {
        await SupabaseService.client.from('group_page_permissions').insert({
          'group_id': groupId,
          'page_id': pageId,
          'can_access': true,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกสิทธิ์การเข้าถึงสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกสิทธิ์: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 8),
            Text('จัดการสิทธิ์ผู้ใช้', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Color(0xFF2E7D32),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFF1F8E9),
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? _buildSkeletonLoader()
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GlassButton(
                          text: 'ลองใหม่',
                          onPressed: _loadData,
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  )
                : DraggableScrollableSheet(
                    initialChildSize: 1.0,
                    minChildSize: 0.9,
                    maxChildSize: 1.0,
                    expand: true,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: _buildGroupsTab(scrollController),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1000
            ? 3
            : width >= 720
                ? 2
                : 1;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.5,
          ),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skeleton Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 50,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Skeleton Content - reduced
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Container(
                      width: 70,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < 2; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 120,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Skeleton Button - single button
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsTab(ScrollController scrollController) {
    // If initialGroup is provided, show only that group
    List<Map<String, dynamic>> filteredGroups;
    if (widget.initialGroup != null) {
      filteredGroups = _userGroups.where((group) => group['id'] == widget.initialGroup!['id']).toList();
    } else {
      // Filter groups based on search query
      filteredGroups = _userGroups.where((group) {
        final searchLower = _groupSearchQuery.toLowerCase();
        final groupName = (group['group_name'] ?? '').toLowerCase();
        final description = (group['group_description'] ?? '').toLowerCase();
        return groupName.contains(searchLower) || description.contains(searchLower);
      }).toList();
    }

    // Single group view: make the content scrollable to avoid bottom overflow on small screens.
    if (widget.initialGroup != null) {
      return ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          if (filteredGroups.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _buildGroupCard(filteredGroups.first),
            ),
          if (filteredGroups.isNotEmpty)
            _buildPagePermissionsSection(filteredGroups.first),
          if (filteredGroups.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'ไม่พบกลุ่มผู้ใช้',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        // Search Bar - only show if not viewing single group
        if (widget.initialGroup == null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _groupSearchController,
              onChanged: (value) {
                setState(() {
                  _groupSearchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ค้นหากลุ่ม...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon: _groupSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _groupSearchController.clear();
                          setState(() {
                            _groupSearchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        // Group Cards Grid - Fixed position, no scroll
        filteredGroups.isEmpty
            ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _groupSearchQuery.isEmpty ? Icons.group_off : Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _groupSearchQuery.isEmpty
                            ? 'ยังไม่มีกลุ่มผู้ใช้'
                            : 'ไม่พบกลุ่มที่ค้นหา',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1000
                      ? 3
                      : width >= 720
                          ? 2
                          : 1;
                  final cardWidth = (width - (20 * 2) - ((crossAxisCount - 1) * 16)) / crossAxisCount;
                  
                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: filteredGroups.map((group) {
                        return SizedBox(
                          width: cardWidth,
                          child: _buildGroupCard(group),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildPagePermissionsSection(Map<String, dynamic> group) {
    final groupColor = _hexToColor(group['color']);
    final groupId = group['id'] as String;
    final isCompact = MediaQuery.of(context).size.width < 420;
    
    // สิทธิ์ปัจจุบัน
    final enabledPages = _pagePermissions
        .where((p) => p['group_id'] == groupId && p['can_access'] == true)
        .map((p) => p['page_id'] as String)
        .toSet();
    final enabledTabs = _tabPermissions
        .where((p) => p['group_id'] == groupId && p['can_access'] == true)
        .map((p) => p['tab_id'] as String)
        .toSet();
    final enabledActions = _actionPermissions
        .where((p) => p['group_id'] == groupId && p['can_access'] == true)
        .map((p) => p['action_id'] as String)
        .toSet();

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Icon(Icons.security, color: groupColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สิทธิ์การเข้าถึง',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'กำหนดสิทธิ์ หน้า → Tab → ปุ่ม (บันทึกอัตโนมัติ)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 3-Level ExpansionTile: Page → Tab → Action
          ..._systemPages.map((page) {
            final pageId = page['id'] as String;
            final hasPagePerm = enabledPages.contains(pageId);
            final isPageUpdating = _updatingPageId == pageId;
            final tabsForPage = _systemTabs.where((t) => t['page_id'] == pageId).toList();

            // นับจำนวน tab/action ที่เปิดอยู่
            final enabledTabCount = tabsForPage.where((t) => enabledTabs.contains(t['id'])).length;
            final totalActionCount = _systemActions.where((a) => tabsForPage.any((t) => t['id'] == a['tab_id'])).length;
            final enabledActionCount = _systemActions.where((a) => tabsForPage.any((t) => t['id'] == a['tab_id']) && enabledActions.contains(a['id'])).length;

            return Container(
              margin: EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasPagePerm ? groupColor.withOpacity(0.3) : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: isCompact
                      ? null
                      : isPageUpdating
                          ? SizedBox(
                              width: 24, height: 24,
                              child: CupertinoActivityIndicator(color: groupColor),
                            )
                          : Icon(
                              page['icon'] as IconData,
                              color: hasPagePerm ? groupColor : Colors.grey[400],
                            ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          page['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: hasPagePerm ? Colors.grey[800] : Colors.grey[500],
                          ),
                        ),
                      ),
                      if (!isCompact && hasPagePerm && tabsForPage.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: groupColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$enabledTabCount/${tabsForPage.length} tab · $enabledActionCount/$totalActionCount',
                            style: TextStyle(fontSize: 10, color: groupColor),
                          ),
                        ),
                    ],
                  ),
                  trailing: SizedBox(
                    height: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: hasPagePerm,
                        activeColor: groupColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: isPageUpdating ? null : (value) async {
                          await _togglePagePermission(groupId, pageId, value);
                        },
                      ),
                    ),
                  ),
                  children: [
                    if (hasPagePerm && tabsForPage.isNotEmpty)
                      ...tabsForPage.map((tab) {
                        final tabId = tab['id'] as String;
                        final hasTabPerm = enabledTabs.contains(tabId);
                        final isTabUpdating = _updatingTabId == tabId;
                        final actionsForTab = _systemActions.where((a) => a['tab_id'] == tabId).toList();

                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasTabPerm ? groupColor.withOpacity(0.04) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasTabPerm ? groupColor.withOpacity(0.15) : Colors.grey[200]!,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: isCompact
                                  ? null
                                  : isTabUpdating
                                      ? SizedBox(
                                          width: 20, height: 20,
                                          child: CupertinoActivityIndicator(color: groupColor),
                                        )
                                      : Icon(
                                          tab['icon'] as IconData,
                                          size: 20,
                                          color: hasTabPerm ? groupColor : Colors.grey[400],
                                        ),
                              title: Text(
                                tab['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: hasTabPerm ? Colors.grey[800] : Colors.grey[500],
                                ),
                              ),
                              trailing: SizedBox(
                                height: 32,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Switch(
                                    value: hasTabPerm,
                                    activeColor: groupColor,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onChanged: isTabUpdating ? null : (value) async {
                                      await _toggleTabPermission(groupId, tabId, value);
                                    },
                                  ),
                                ),
                              ),
                              children: [
                                if (hasTabPerm && actionsForTab.isNotEmpty)
                                  ...actionsForTab.map((action) {
                                    final actionId = action['id'] as String;
                                    final hasActionPerm = enabledActions.contains(actionId);
                                    final isActionUpdating = _updatingActionId == actionId;

                                    return Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                                      child: Row(
                                        children: [
                                          isActionUpdating
                                              ? SizedBox(
                                                  width: 18, height: 18,
                                                  child: CupertinoActivityIndicator(color: groupColor),
                                                )
                                              : Icon(
                                                  action['icon'] as IconData,
                                                  size: 18,
                                                  color: hasActionPerm ? groupColor : Colors.grey[400],
                                                ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              action['name'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: hasActionPerm ? Colors.grey[800] : Colors.grey[500],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 28,
                                            child: FittedBox(
                                              child: Switch(
                                                value: hasActionPerm,
                                                activeColor: groupColor,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                onChanged: isActionUpdating ? null : (value) async {
                                                  await _toggleActionPermission(groupId, actionId, value);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                if (hasTabPerm && actionsForTab.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'ไม่มีปุ่มที่กำหนดสิทธิ์ได้',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (hasPagePerm && tabsForPage.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'ไม่มี Tab ที่กำหนดสิทธิ์ได้',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          }),
          
          // Auto-save info
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'เปิด/ปิดสิทธิ์จะบันทึกอัตโนมัติ · ปิดหน้า→ปิด Tab ทั้งหมด · ปิด Tab→ปิดปุ่มทั้งหมด',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    // นับจำนวนสมาชิกจาก permissions (user_group_members) โดยตรง
    final memberCount = _permissions
        .where((p) => p['group_id'] == group['id'])
        .length;

    final groupColor = _hexToColor(group['color']);
    final headerColor = _darkenColor(groupColor, 0.15);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor, groupColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['group_name'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$memberCount ผู้ใช้',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'ผู้ใช้ในกลุ่ม:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: memberCount == 0
                ? Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'ยังไม่มีผู้ใช้ในกลุ่ม',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchGroupMembersViaRpc(group['id'] as String),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: CupertinoActivityIndicator(radius: 8),
                        );
                      }
                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text(
                              '$memberCount ผู้ใช้',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        );
                      }
                      final userItems = members
                          .map((u) => (u['full_name'] ?? u['username'] ?? u['email'] ?? 'ไม่ระบุชื่อ').toString())
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...userItems
                              .take(3)
                              .map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: groupColor, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          if (userItems.length > 3)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '+${userItems.length - 3} คนเพิ่มเติม',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showGroupUsersDialog(group),
                    icon: Icon(Icons.people, size: 16, color: headerColor),
                    label: Text('สมาชิก', style: TextStyle(color: headerColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: headerColor.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

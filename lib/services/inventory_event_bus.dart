import 'dart:async';

/// Simple event bus for propagating inventory structural changes (warehouses / zones / shelves)
/// so that multiple tabs can refresh consistently when the warehouse management UI updates data.
enum InventoryEventType {
  storageStructureChanged,
}

class InventoryEventBus {
  static final StreamController<InventoryEventType> _controller =
      StreamController<InventoryEventType>.broadcast();

  static Stream<InventoryEventType> get stream => _controller.stream;

  static void emit(InventoryEventType event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}

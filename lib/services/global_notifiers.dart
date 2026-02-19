import 'package:flutter/foundation.dart';

class GlobalNotifiers {
  // Notifies listeners when crop data has changed (added/deleted)
  // so other screens (Advisory, Chat) can refresh their data.
  static final ValueNotifier<bool> shouldRefreshAdvisory = ValueNotifier(false);

  // Optimistic updates payloads
  static final ValueNotifier<Map<String, dynamic>?> selectionAdded =
      ValueNotifier(null);
  static final ValueNotifier<int?> selectionDeleted = ValueNotifier(null);
  static final ValueNotifier<Map<String, dynamic>?> selectionUpdated =
      ValueNotifier(null);
}

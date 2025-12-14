// session_filter_provider.dart
import 'package:flutter/material.dart';

class SessionFilterProvider extends ChangeNotifier {
  // The private variable holding the state
  bool _showOnlyActiveSessions = true;

  // Getter to expose the current state
  bool get showOnlyActiveSessions => _showOnlyActiveSessions;

  // Method to update the state and notify listeners
  void setShowOnlyActiveSessions(bool newValue) {
    if (_showOnlyActiveSessions != newValue) {
      // Only update if value actually changes
      _showOnlyActiveSessions = newValue;
      notifyListeners(); // Notify all widgets that are listening for changes
    }
  }
}

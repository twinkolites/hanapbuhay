import 'dart:async';
import 'package:flutter/material.dart';

/// Utility class for debouncing button clicks and other user interactions
/// 
/// This prevents rapid successive clicks that could cause:
/// - Duplicate API calls
/// - Multiple navigation actions
/// - Unintended form submissions
/// - Poor user experience
class ButtonDebouncer {
  static final Map<String, Timer> _timers = {};
  
  /// Default debounce duration in milliseconds
  static const int defaultDebounceMs = 500;
  
  /// Debounce a function call with a specific duration
  /// 
  /// [key] - Unique identifier for this debounced action
  /// [callback] - Function to execute after debounce period
  /// [durationMs] - Debounce duration in milliseconds (default: 500ms)
  static void debounce(
    String key,
    VoidCallback callback, {
    int durationMs = defaultDebounceMs,
  }) {
    // Cancel existing timer for this key
    _timers[key]?.cancel();
    
    // Create new timer
    _timers[key] = Timer(Duration(milliseconds: durationMs), () {
      callback();
      _timers.remove(key);
    });
  }
  
  /// Check if a specific action is currently debounced
  /// 
  /// [key] - Unique identifier for the action
  /// Returns true if the action is currently debounced
  static bool isDebounced(String key) {
    return _timers.containsKey(key);
  }
  
  /// Cancel a specific debounced action
  /// 
  /// [key] - Unique identifier for the action to cancel
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }
  
  /// Cancel all debounced actions
  static void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
  
  /// Get the number of currently active debounced actions
  static int get activeCount => _timers.length;
}

/// Extension to make debouncing easier to use with StatefulWidget
extension ButtonDebouncerExtension on State {
  /// Debounce a function call using the widget's context as key
  /// 
  /// [callback] - Function to execute after debounce period
  /// [durationMs] - Debounce duration in milliseconds (default: 500ms)
  void debounceAction(
    VoidCallback callback, {
    int durationMs = ButtonDebouncer.defaultDebounceMs,
  }) {
    final key = '${runtimeType}_${hashCode}';
    ButtonDebouncer.debounce(key, callback, durationMs: durationMs);
  }
  
  /// Debounce a function call with a custom key
  /// 
  /// [key] - Unique identifier for this debounced action
  /// [callback] - Function to execute after debounce period
  /// [durationMs] - Debounce duration in milliseconds (default: 500ms)
  void debounceActionWithKey(
    String key,
    VoidCallback callback, {
    int durationMs = ButtonDebouncer.defaultDebounceMs,
  }) {
    ButtonDebouncer.debounce(key, callback, durationMs: durationMs);
  }
}

/// Mixin to add debouncing capabilities to any widget
mixin ButtonDebouncerMixin {
  final Map<String, Timer> _debounceTimers = {};
  
  /// Debounce a function call
  /// 
  /// [key] - Unique identifier for this debounced action
  /// [callback] - Function to execute after debounce period
  /// [durationMs] - Debounce duration in milliseconds (default: 500ms)
  void debounce(
    String key,
    VoidCallback callback, {
    int durationMs = ButtonDebouncer.defaultDebounceMs,
  }) {
    // Cancel existing timer for this key
    _debounceTimers[key]?.cancel();
    
    // Create new timer
    _debounceTimers[key] = Timer(Duration(milliseconds: durationMs), () {
      callback();
      _debounceTimers.remove(key);
    });
  }
  
  /// Check if a specific action is currently debounced
  bool isDebounced(String key) {
    return _debounceTimers.containsKey(key);
  }
  
  /// Cancel a specific debounced action
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }
  
  /// Cancel all debounced actions
  void cancelAllDebounces() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
  
  /// Dispose method to be called in widget dispose
  void disposeDebouncer() {
    cancelAllDebounces();
  }
}

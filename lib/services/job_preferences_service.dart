import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service to manage job preferences completion status for new applicants
class JobPreferencesService {
  static const String _hasCompletedPreferencesKey = 'has_completed_job_preferences';
  
  /// Check if the user has completed job preferences setup
  static Future<bool> hasCompletedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasCompletedPreferencesKey) ?? false;
    } catch (e) {
      debugPrint('Error checking job preferences completion: $e');
      return false;
    }
  }
  
  /// Mark job preferences as completed
  static Future<bool> markPreferencesCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_hasCompletedPreferencesKey, true);
    } catch (e) {
      debugPrint('Error marking job preferences as completed: $e');
      return false;
    }
  }
  
  /// Reset job preferences completion status (useful for testing or user wants to update)
  static Future<bool> resetPreferencesCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_hasCompletedPreferencesKey, false);
    } catch (e) {
      debugPrint('Error resetting job preferences completion: $e');
      return false;
    }
  }
  
  /// Clear all job preferences data (useful for logout)
  static Future<bool> clearPreferencesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_hasCompletedPreferencesKey);
    } catch (e) {
      debugPrint('Error clearing job preferences data: $e');
      return false;
    }
  }
}

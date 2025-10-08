import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaySignedInService {
  static const String _staySignedInKey = 'stay_signed_in';
  static const String _sessionValidKey = 'session_valid';
  
  /// Save the user's preference for staying signed in
  static Future<void> saveStaySignedInPreference(bool staySignedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_staySignedInKey, staySignedIn);
    
    // If user doesn't want to stay signed in, mark session as invalid
    if (!staySignedIn) {
      await prefs.setBool(_sessionValidKey, false);
    }
  }
  
  /// Get the user's preference for staying signed in
  static Future<bool> shouldStaySignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_staySignedInKey) ?? false; // Default to false
  }
  
  /// Check if the current session should be valid based on user preference
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldStay = await shouldStaySignedIn();
    
    if (!shouldStay) {
      return false; // If user doesn't want to stay signed in, session is invalid
    }
    
    // Check if session was marked as valid
    return prefs.getBool(_sessionValidKey) ?? false;
  }
  
  /// Mark the current session as valid (called after successful login)
  static Future<void> markSessionAsValid() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldStay = await shouldStaySignedIn();
    
    // Only mark session as valid if user wants to stay signed in
    if (shouldStay) {
      await prefs.setBool(_sessionValidKey, true);
    } else {
      await prefs.setBool(_sessionValidKey, false);
    }
  }
  
  /// Clear all session data and preferences
  static Future<void> clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_staySignedInKey);
    await prefs.remove(_sessionValidKey);
    
    // Also clear any stored tokens
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
  
  /// Handle app termination - clear session if user doesn't want to stay signed in
  static Future<void> handleAppTermination() async {
    final shouldStay = await shouldStaySignedIn();
    if (!shouldStay) {
      await Supabase.instance.client.auth.signOut();
      await clearSessionData();
    }
  }
  
  /// Check and validate session on app startup
  static Future<bool> validateSessionOnStartup() async {
    try {
      final shouldStay = await shouldStaySignedIn();
      
      if (!shouldStay) {
        // User doesn't want to stay signed in, clear any existing session
        await Supabase.instance.client.auth.signOut();
        await clearSessionData();
        return false;
      }
      
      // Check if we have a valid session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        await clearSessionData();
        return false;
      }
      
      // Check if session is expired
      if (session.isExpired) {
        try {
          // Try to refresh the session
          final response = await Supabase.instance.client.auth.refreshSession();
          if (response.session != null) {
            // Only mark as valid if user wants to stay signed in
            if (shouldStay) {
              await markSessionAsValid();
            }
            return true;
          }
        } catch (e) {
          // Refresh failed, clear session
          await Supabase.instance.client.auth.signOut();
          await clearSessionData();
          return false;
        }
      }
      
      // Session is valid - only mark as valid if user wants to stay signed in
      if (shouldStay) {
        await markSessionAsValid();
      }
      return true;
      
    } catch (e) {
      // Any error, clear session
      await Supabase.instance.client.auth.signOut();
      await clearSessionData();
      return false;
    }
  }
}

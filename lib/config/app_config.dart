import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase Configuration
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL not found in environment variables');
    }
    return url;
  }
  
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in environment variables');
    }
    return key;
  }

  // App Configuration
  static String get appName => 
    dotenv.env['APP_NAME'] ?? 'HanapBuhay';
  
  static String get appVersion => 
    dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  static String get appEnvironment => 
    dotenv.env['APP_ENVIRONMENT'] ?? 'production';

  // Email Configuration
  static String get smtpHost => dotenv.env['SMTP_HOST'] ?? '';
  static String get smtpPort => dotenv.env['SMTP_PORT'] ?? '';
  static String get smtpUsername => dotenv.env['SMTP_USERNAME'] ?? '';
  static String get smtpPassword => dotenv.env['SMTP_PASSWORD'] ?? '';

  // Other API Keys
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';

  // Debug Configuration
  static bool get isDebug => kDebugMode;
  static bool get isProduction => appEnvironment == 'production';
  static bool get isDevelopment => appEnvironment == 'development';

  // Validation
  static bool get isConfigValid {
    try {
      final url = supabaseUrl;
      final key = supabaseAnonKey;
      return url.isNotEmpty && 
             key.isNotEmpty &&
             url.startsWith('https://') &&
             key.startsWith('eyJ');
    } catch (e) {
      return false;
    }
  }

  // Print configuration (only in debug mode)
  static void printConfig() {
    if (isDebug) {
      print('🔧 App Configuration:');
      print('   App Name: $appName');
      print('   App Version: $appVersion');
      print('   Environment: $appEnvironment');
      
      try {
        final url = supabaseUrl;
        final key = supabaseAnonKey;
        print('   Supabase URL: ${url.substring(0, 30)}...');
        print('   Supabase Key: ${key.substring(0, 20)}...');
      } catch (e) {
        print('   ❌ Supabase credentials not found in .env file');
      }
      
      print('   Config Valid: $isConfigValid');
    }
  }
}

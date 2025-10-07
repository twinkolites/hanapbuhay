import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload a file to the employer documents bucket
  static Future<String?> uploadEmployerDocument({
    required String userId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      print('📁 StorageService: Starting upload for user: $userId');
      print('📁 StorageService: Document type: $documentType');
      print('📁 StorageService: File name: ${file.name}');
      print('📁 StorageService: File size: ${file.size}');
      
      // Validate file size (10MB limit)
      if (file.size > 10 * 1024 * 1024) {
        throw Exception('File size must be less than 10MB');
      }

      // Validate file type
      final allowedTypes = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
      final fileExtension = file.extension?.toLowerCase();
      if (fileExtension == null || !allowedTypes.contains(fileExtension)) {
        throw Exception('File type not allowed. Allowed types: ${allowedTypes.join(', ')}');
      }

      // Create file path: userId/documentType/filename
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final filePath = '$userId/$documentType/$fileName';

      print('📁 StorageService: File path: $filePath');

      // Upload file to Supabase Storage
      final response = await _supabase.storage
          .from('employer-documents')
          .uploadBinary(
            filePath,
            file.bytes!,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      print('📁 StorageService: Upload response: $response');

      if (response.isNotEmpty) {
        // Get the public URL for the uploaded file
        final publicUrl = _supabase.storage
            .from('employer-documents')
            .getPublicUrl(filePath);

        print('📁 StorageService: Public URL: $publicUrl');
        return publicUrl;
      }

      print('📁 StorageService: Upload failed - empty response');
      return null;
    } catch (e) {
      print('📁 StorageService: Error uploading file: $e');
      rethrow;
    }
  }

  /// Get a signed URL for viewing a private file
  static Future<String?> getSignedUrl({
    required String filePath,
    int expiresIn = 3600, // 1 hour
  }) async {
    try {
      final response = await _supabase.storage
          .from('employer-documents')
          .createSignedUrl(filePath, expiresIn);

      return response;
    } catch (e) {
      print('Error getting signed URL: $e');
      return null;
    }
  }

  /// Delete a file from storage
  static Future<bool> deleteFile(String filePath) async {
    try {
      await _supabase.storage
          .from('employer-documents')
          .remove([filePath]);

      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Get all files for a specific user and document type
  static Future<List<Map<String, dynamic>>> getUserDocuments({
    required String userId,
    String? documentType,
  }) async {
    try {
      final prefix = documentType != null ? '$userId/$documentType/' : '$userId/';
      
      final response = await _supabase.storage
          .from('employer-documents')
          .list(
            path: prefix,
            searchOptions: const SearchOptions(
              limit: 100,
            ),
          );

      return response.map((file) => {
        'name': file.name,
        'path': '$prefix${file.name}',
        'size': file.metadata?['size'],
        'created_at': file.createdAt,
        'updated_at': file.updatedAt,
      }).toList();
    } catch (e) {
      print('Error getting user documents: $e');
      return [];
    }
  }

  /// Validate file before upload
  static String? validateFile(PlatformFile file) {
    // Check file size (10MB limit)
    if (file.size > 10 * 1024 * 1024) {
      return 'File size must be less than 10MB';
    }

    // Check file type
    final allowedTypes = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
    final fileExtension = file.extension?.toLowerCase();
    if (fileExtension == null || !allowedTypes.contains(fileExtension)) {
      return 'File type not allowed. Allowed types: ${allowedTypes.join(', ')}';
    }

    // Check if file has content
    if (file.bytes == null || file.bytes!.isEmpty) {
      return 'File appears to be empty';
    }

    return null; // No validation errors
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file type icon
  static String getFileTypeIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }
}

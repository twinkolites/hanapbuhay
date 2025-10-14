import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

final supabase = Supabase.instance.client;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload image to Supabase Storage
  static Future<String?> uploadProfileImage({
    required File imageFile,
    required String userId,
    String? fileName,
  }) async {
    try {
      // Generate unique filename if not provided
      final String finalFileName = fileName ?? 
          '${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Upload to Supabase Storage
      final String filePath = 'profile-images/$finalFileName';
      
      await supabase.storage
          .from('avatars')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Get public URL
      final String publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Delete image from Supabase Storage
  static Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final Uri uri = Uri.parse(imageUrl);
      final String filePath = uri.pathSegments.last;
      
      await supabase.storage
          .from('avatars')
          .remove(['profile-images/$filePath']);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Show image picker options dialog
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF013237),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Options
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF4CA771)),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4CA771)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Validate image file
  static bool validateImage(File imageFile) {
    // Check file size (max 5MB)
    const int maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    if (imageFile.lengthSync() > maxSizeInBytes) {
      return false;
    }

    // Check file extension
    final String extension = path.extension(imageFile.path).toLowerCase();
    const List<String> allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    
    return allowedExtensions.contains(extension);
  }

  /// Get error message for image validation
  static String getImageValidationError(File imageFile) {
    const int maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    if (imageFile.lengthSync() > maxSizeInBytes) {
      return 'Image size must be less than 5MB';
    }

    final String extension = path.extension(imageFile.path).toLowerCase();
    const List<String> allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    
    if (!allowedExtensions.contains(extension)) {
      return 'Only JPG, PNG, and WebP images are allowed';
    }

    return 'Invalid image file';
  }
}

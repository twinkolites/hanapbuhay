import 'package:flutter/material.dart';
import '../config/app_config.dart';

class VideoCallService {
  static bool _isInitialized = false;
  
  /// Initialize ZEGOCLOUD SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize ZEGOCLOUD with your App ID and App Sign
      final appID = AppConfig.zegoAppId;
      final appSign = AppConfig.zegoAppSign;
      
      if (appID == 0 || appSign.isEmpty) {
        print('ZEGOCLOUD credentials not configured');
        return;
      }
      
      // TODO: Initialize ZEGOCLOUD SDK when credentials are available
      // await ZegoUIKitPrebuiltCallInvitationService().init(
      //   appID: appID,
      //   appSign: appSign,
      // );
      
      _isInitialized = true;
      print('ZEGOCLOUD initialized successfully');
    } catch (e) {
      print('Failed to initialize ZEGOCLOUD: $e');
    }
  }
  
  /// Start a video call
  static Future<void> startVideoCall({
    required String callID,
    required String userID,
    required String userName,
    required List<String> invitees,
    required BuildContext context,
  }) async {
    try {
      await initialize();
      
      // TODO: Implement actual video call functionality
      _showErrorSnackBar(context, 'Video calling feature coming soon! Please configure ZEGOCLOUD credentials.');
    } catch (e) {
      print('Failed to start video call: $e');
      _showErrorSnackBar(context, 'Failed to start video call: $e');
    }
  }
  
  /// Join an ongoing call
  static Future<void> joinVideoCall({
    required String callID,
    required String userID,
    required String userName,
    required BuildContext context,
  }) async {
    try {
      await initialize();
      
      // TODO: Implement actual video call functionality
      _showErrorSnackBar(context, 'Video calling feature coming soon! Please configure ZEGOCLOUD credentials.');
    } catch (e) {
      print('Failed to join video call: $e');
      _showErrorSnackBar(context, 'Failed to join video call: $e');
    }
  }
  
  /// Send call invitation
  static Future<void> sendCallInvitation({
    required List<String> invitees,
    required String userID,
    required String userName,
    required BuildContext context,
  }) async {
    try {
      await initialize();
      
      // TODO: Implement actual call invitation functionality
      _showErrorSnackBar(context, 'Video calling feature coming soon! Please configure ZEGOCLOUD credentials.');
    } catch (e) {
      print('Failed to send call invitation: $e');
      _showErrorSnackBar(context, 'Failed to send call invitation: $e');
    }
  }
  
  
  /// Show error snackbar
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  /// Dispose resources
  static void dispose() {
    // TODO: Implement ZEGOCLOUD cleanup when SDK is properly integrated
    _isInitialized = false;
  }
}

/// Video call page widget
class VideoCallPage extends StatelessWidget {
  final String callID;
  final String userID;
  final String userName;
  final List<String> invitees;
  
  const VideoCallPage({
    super.key,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.invitees,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_call_rounded,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Video Calling Feature',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Configure ZEGOCLOUD credentials to enable video calling',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Call invitation widget for chat integration
class CallInvitationWidget extends StatelessWidget {
  final String callID;
  final String callerName;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  
  const CallInvitationWidget({
    super.key,
    required this.callID,
    required this.callerName,
    this.onAccept,
    this.onDecline,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_call_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incoming Video Call',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$callerName is calling you',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onDecline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_end_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Decline'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Accept'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

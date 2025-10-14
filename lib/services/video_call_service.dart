import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'attendance_tracking_service.dart';
import 'onesignal_notification_service.dart';

class VideoCallService {
  static bool _isInitialized = false;
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Initialize ZEGOCLOUD SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final appID = AppConfig.zegoAppId;
      final appSign = AppConfig.zegoAppSign;
      
      if (appID == 0 || appSign.isEmpty) {
        print('⚠️ ZEGOCLOUD credentials not configured in .env file');
        print('   Please add ZEGO_APP_ID and ZEGO_APP_SIGN to your .env file');
        return;
      }
      
      print('🔧 Initializing ZEGOCLOUD with App ID: $appID');
      
      // Initialize ZEGOCLOUD SDK with signaling plugin for call invitations
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: appID,
        appSign: appSign,
        userID: 'system', // System user for initialization
        userName: 'System',
        plugins: [ZegoUIKitSignalingPlugin()], // Add signaling plugin for call invitations
      );
      
      _isInitialized = true;
      print('✅ ZEGOCLOUD initialized successfully with signaling plugin');
    } catch (e) {
      print('❌ Failed to initialize ZEGOCLOUD: $e');
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
      
      if (!_isInitialized) {
        _showErrorSnackBar(context, 'ZEGOCLOUD not initialized. Please check your credentials in .env file.');
        return;
      }
      
      print('🎥 Starting video call: $callID');
      
      // Navigate to ZEGOCLOUD video call screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ZegoUIKitPrebuiltCall(
            appID: AppConfig.zegoAppId,
            appSign: AppConfig.zegoAppSign,
            callID: callID,
            userID: userID,
            userName: userName,
            config: ZegoUIKitPrebuiltCallConfig(
              // Configure call settings for Teams/Discord-style experience
              turnOnCameraWhenJoining: true,
              turnOnMicrophoneWhenJoining: true,
              useSpeakerWhenJoining: true,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Failed to start video call: $e');
      // Avoid using possibly deactivated context here; let caller show UI feedback
    }
  }
  
  /// Join an ongoing call (Teams/Discord Style)
  static Future<void> joinVideoCall({
    required String callID,
    required String userID,
    required String userName,
    required BuildContext context,
    bool isHost = false, // Determine if user is the host
    String? eventId, // For attendance tracking
    String? userRole, // 'applicant' or 'employer'
  }) async {
    try {
      await initialize();
      
      if (!_isInitialized) {
        _showErrorSnackBar(context, 'ZEGOCLOUD not initialized. Please check your credentials in .env file.');
        return;
      }
      
      print('🎥 ${isHost ? 'Creating' : 'Joining'} interview room: $callID');
      
      // Record attendance: User joined the call
      if (eventId != null && userRole != null) {
        await AttendanceTrackingService.recordCallJoin(
          eventId: eventId,
          userId: userID,
          userRole: userRole,
        );
        print('📊 [Attendance] Recorded join for $userRole');

        // Send notification when applicant joins video call
        if (userRole == 'applicant') {
          try {
            // Get event details for notification
            final eventDetails = await _supabase
                .from('calendar_events')
                .select('''
                  id,
                  title,
                  applicant_id,
                  employer_id,
                  job_id,
                  jobs (
                    title
                  )
                ''')
                .eq('id', eventId)
                .single();

            final applicantId = eventDetails['applicant_id'];
            final employerId = eventDetails['employer_id'];
            final jobId = eventDetails['job_id'];
            final jobTitle = eventDetails['jobs']['title'] ?? 'Unknown Job';
            final meetingTitle = eventDetails['title'];

            // Get applicant name
            final applicantProfile = await _supabase
                .from('profiles')
                .select('full_name')
                .eq('id', applicantId)
                .single();

            final applicantName = applicantProfile['full_name'] ?? 'Unknown';

            await OneSignalNotificationService.sendVideoCallJoinNotification(
              applicantId: applicantId,
              employerId: employerId,
              jobId: jobId,
              jobTitle: jobTitle,
              meetingTitle: meetingTitle,
              applicantName: applicantName,
              callId: callID,
              eventId: eventId,
            );

            print('✅ Video call join notification sent successfully');
          } catch (notificationError) {
            print('❌ Error sending video call join notification: $notificationError');
            // Don't fail the call join if notifications fail
          }
        }
      }
      
      // Navigate to ZEGOCLOUD video call screen with Teams/Discord-style config
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ZegoUIKitPrebuiltCall(
            appID: AppConfig.zegoAppId,
            appSign: AppConfig.zegoAppSign,
            callID: callID,
            userID: userID,
            userName: userName,
            config: ZegoUIKitPrebuiltCallConfig.groupVideoCall()
              // Basic settings - Discord/Teams persistent room style
              ..turnOnCameraWhenJoining = true
              ..turnOnMicrophoneWhenJoining = true
              ..useSpeakerWhenJoining = true
              // Persistent room behavior - doesn't end call for others when you leave
              ..hangUpConfirmDialogInfo = ZegoHangUpConfirmDialogInfo(
                title: 'Leave Interview Room?',
                message: 'Are you sure you want to leave? The room will stay open for others.',
              )
              // Show member list and controls like Teams/Discord
              ..topMenuBar = ZegoTopMenuBarConfig(
                isVisible: true,
                buttons: [
                  ZegoMenuBarButtonName.toggleCameraButton,
                  ZegoMenuBarButtonName.switchCameraButton,
                  ZegoMenuBarButtonName.toggleMicrophoneButton,
                  ZegoMenuBarButtonName.showMemberListButton,
                ],
              )
              ..bottomMenuBar = ZegoBottomMenuBarConfig(
                buttons: [
                  ZegoMenuBarButtonName.toggleCameraButton,
                  ZegoMenuBarButtonName.toggleMicrophoneButton,
                  ZegoMenuBarButtonName.hangUpButton,
                  ZegoMenuBarButtonName.switchAudioOutputButton,
                ],
              ),
          ),
        ),
      );
      
      // Record attendance when user returns (left the call)
      if (eventId != null && userRole != null) {
        await AttendanceTrackingService.recordCallLeave(
          eventId: eventId,
          userId: userID,
          userRole: userRole,
        );
        print('📊 [Attendance] Recorded leave for $userRole');
      }
    } catch (e) {
      print('❌ Failed to join video call: $e');
      // Avoid using possibly deactivated context here; let caller show UI feedback
    }
  }

  /// Best-effort cleanup to avoid stuck session when re-entering a room
  static Future<void> logoutRoomIfAny({String? roomID}) async {
    try {
      // ZegoUIKit provides leaveRoom to exit any ongoing room session
      await ZegoUIKit().leaveRoom();
      // Small delay to allow SDK to tear down internal state
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      // Swallow errors; this is a best-effort cleanup
      debugPrint('ZEGO logoutRoomIfAny error: $e');
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
      
      // For now, show a simple dialog
      // In production, this would use ZEGOCLOUD's invitation API
      _showCallInvitationDialog(context, invitees, userName);
    } catch (e) {
      print('Failed to send call invitation: $e');
      _showErrorSnackBar(context, 'Failed to send call invitation: $e');
    }
  }
  
  /// Show call invitation dialog
  static void _showCallInvitationDialog(
    BuildContext context, 
    List<String> invitees, 
    String userName
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Call Invitation'),
        content: Text('Send video call invitation to ${invitees.length} participant(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSuccessSnackBar(context, 'Call invitation sent successfully!');
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
  
  /// Show error snackbar
  static void _showErrorSnackBar(BuildContext context, String message) {
    try {
      final element = context as Element;
      if (!element.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Unable to show error SnackBar (context not mounted): $message');
    }
  }
  
  /// Show success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    try {
      final element = context as Element;
      if (!element.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Unable to show success SnackBar (context not mounted): $message');
    }
  }
  
  /// Dispose resources
  static void dispose() {
    _isInitialized = false;
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

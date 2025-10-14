# OneSignal Setup Guide for HanapBuhay

## ✅ Completed Setup

### 1. Database Schema
- ✅ Updated `user_devices` table with OneSignal columns
- ✅ Enhanced `notifications` table with tracking fields
- ✅ Created `notification_preferences` table
- ✅ Created `notification_categories` table
- ✅ Created `notification_templates` table
- ✅ Added RLS policies and functions
- ✅ Applied all database migrations

### 2. Flutter Code
- ✅ Added OneSignal dependencies to `pubspec.yaml`
- ✅ Created `OneSignalNotificationService` class
- ✅ Updated `main.dart` to initialize OneSignal
- ✅ Updated `AuthProvider` to subscribe/unsubscribe users
- ✅ Created `NotificationsScreen` UI
- ✅ Updated home screen to navigate to notifications

---

## 🔧 Required Setup Steps

### Step 1: Create OneSignal Account
1. Go to [OneSignal.com](https://onesignal.com)
2. Sign up for a free account
3. Create a new app:
   - **App Name**: HanapBuhay
   - **Platform**: Flutter (iOS + Android)

### Step 2: Get OneSignal App ID
1. In OneSignal dashboard, go to **Settings > Keys & IDs**
2. Copy your **App ID** (starts with letters/numbers)
3. Copy your **REST API Key** (starts with letters/numbers)

### Step 3: Update Environment Variables
Add to your `.env` file:
```env
# OneSignal Configuration
ONESIGNAL_APP_ID=your_onesignal_app_id_here
ONESIGNAL_REST_API_KEY=your_rest_api_key_here
```

### Step 4: Update OneSignal Service
In `lib/services/onesignal_notification_service.dart`, replace:
```dart
// Line 39: Replace with your actual App ID
OneSignal.initialize('YOUR_ONESIGNAL_APP_ID'); // Replace with your App ID
```

### Step 5: Platform Configuration

#### Android Setup
1. **Update `android/app/build.gradle.kts`:**
```kotlin
android {
    defaultConfig {
        manifestPlaceholders["onesignalAppId"] = "your_onesignal_app_id_here"
    }
}
```

2. **Update `android/app/src/main/AndroidManifest.xml`:**
```xml
<!-- Add these permissions if not already present -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Add this inside <application> tag -->
<meta-data android:name="onesignal_app_id" android:value="your_onesignal_app_id_here" />
```

#### iOS Setup
1. **Update `ios/Runner/Info.plist`:**
```xml
<!-- Add these keys -->
<key>OneSignal_APPID</key>
<string>your_onesignal_app_id_here</string>

<!-- Add these permissions if not already present -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Step 6: Install Dependencies
Run in your project root:
```bash
flutter pub get
```

### Step 7: Test Notifications

#### Test 1: Device Registration
1. Run your app
2. Log in with a user account
3. Check OneSignal dashboard > **Audience > All Users**
4. You should see your device registered

#### Test 2: Send Test Notification
1. Go to OneSignal dashboard > **Messages > New Push**
2. Create a test notification
3. Send to "All Users" or specific user
4. Check if notification appears on device

#### Test 3: App Integration
1. Navigate to different screens in your app
2. Trigger actions that should send notifications:
   - Apply for a job
   - Schedule a meeting
   - Send a chat message
3. Check if notifications are created in database

---

## 🎯 Notification Types Available

### 1. Application Status Updates
```dart
await OneSignalNotificationService.sendApplicationStatusNotification(
  userId: 'user_id',
  jobTitle: 'Software Engineer',
  companyName: 'Tech Corp',
  status: 'shortlisted',
  applicationId: 'app_id',
);
```

### 2. Meeting Reminders
```dart
await OneSignalNotificationService.sendMeetingReminderNotification(
  userId: 'user_id',
  meetingTitle: 'Job Interview',
  meetingTime: DateTime.now().add(Duration(hours: 1)),
  meetingId: 'meeting_id',
  minutesBefore: 15,
);
```

### 3. AI Screening Completed
```dart
await OneSignalNotificationService.sendAIScreeningNotification(
  userId: 'user_id',
  jobTitle: 'Data Scientist',
  applicantName: 'John Doe',
  aiScore: 8.5,
  applicationId: 'app_id',
);
```

### 4. Chat Messages
```dart
await OneSignalNotificationService.sendChatMessageNotification(
  userId: 'user_id',
  senderName: 'HR Manager',
  messagePreview: 'Hi, let\'s schedule an interview',
  chatId: 'chat_id',
  jobTitle: 'Software Engineer',
);
```

### 5. Job Matches
```dart
await OneSignalNotificationService.sendJobMatchNotification(
  userId: 'user_id',
  jobTitle: 'Flutter Developer',
  companyName: 'Startup Inc',
  jobId: 'job_id',
  matchScore: 0.85,
);
```

---

## 🔍 Integration Points

### Replace Existing Notification Calls

#### 1. Calendar Service
In `lib/services/calendar_service.dart`:
```dart
// Replace this:
await _supabase.from('notifications').insert({...});

// With this:
await OneSignalNotificationService.sendNotification(
  userId: userId,
  title: title,
  message: message,
  type: 'meeting_scheduled',
  priority: 'high',
);
```

#### 2. AI Screening Service
In `lib/services/ai_screening_service.dart`:
```dart
// Replace the _sendScreeningNotification method with:
await OneSignalNotificationService.sendAIScreeningNotification(
  userId: company['owner_id'],
  jobTitle: job['title'],
  applicantName: application['profiles']['full_name'],
  aiScore: screeningResult['overall_score'],
  applicationId: applicationId,
);
```

#### 3. Chat Service
In `lib/services/chat_service.dart`, add after sending a message:
```dart
// Send notification to recipient
await OneSignalNotificationService.sendChatMessageNotification(
  userId: recipientId,
  senderName: senderName,
  messagePreview: content,
  chatId: chatId,
  jobTitle: jobTitle,
);
```

---

## 🚀 Advanced Features

### 1. Notification Preferences
Users can customize notification settings:
- Enable/disable specific notification types
- Set quiet hours
- Choose delivery methods (push, email, both)

### 2. Rich Notifications
- Images for job postings
- Action buttons (Accept/Decline meetings)
- Deep linking to specific app screens

### 3. Analytics
- Track notification delivery rates
- Monitor click-through rates
- A/B test notification content

### 4. Scheduled Notifications
- Meeting reminders (15 min, 1 hour, 1 day before)
- Daily job recommendations digest
- Weekly activity summaries

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Device Not Registered
- Check if OneSignal App ID is correct
- Verify permissions are granted
- Check device logs for errors

#### 2. Notifications Not Received
- Check OneSignal dashboard for delivery status
- Verify user is subscribed to notifications
- Check notification preferences in database

#### 3. Database Errors
- Ensure all migrations were applied successfully
- Check RLS policies are correctly configured
- Verify user permissions

#### 4. iOS Notifications Not Working
- Check iOS provisioning profile includes push notifications
- Verify OneSignal App ID in Info.plist
- Test on physical device (notifications don't work on simulator)

### Debug Commands

#### Check Database Tables
```sql
-- Check user devices
SELECT * FROM user_devices WHERE user_id = 'your_user_id';

-- Check notifications
SELECT * FROM notifications WHERE user_id = 'your_user_id' ORDER BY created_at DESC LIMIT 10;

-- Check notification preferences
SELECT * FROM notification_preferences WHERE user_id = 'your_user_id';
```

#### Check OneSignal Dashboard
- **Audience > All Users**: Verify devices are registered
- **Messages > History**: Check notification delivery status
- **Settings > Keys & IDs**: Verify App ID and API keys

---

## 📱 Testing Checklist

- [ ] Device registers with OneSignal on app launch
- [ ] User subscribes to notifications on login
- [ ] User unsubscribes from notifications on logout
- [ ] Notifications appear in notification center
- [ ] Tapping notification navigates to correct screen
- [ ] Unread count updates correctly
- [ ] Mark as read functionality works
- [ ] All notification types work (applications, meetings, chat, jobs)
- [ ] Database notifications are created and updated
- [ ] Notification preferences can be customized

---

## 🎉 You're All Set!

Once you complete these setup steps, your HanapBuhay app will have a complete push notification system with:

- ✅ Real-time push notifications
- ✅ Notification history and management
- ✅ User preferences and customization
- ✅ Rich notification content
- ✅ Analytics and tracking
- ✅ Cross-platform support (iOS + Android)

The system is designed to be scalable and maintainable, with proper error handling and user experience considerations.

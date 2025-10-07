# HanapBuhay Calendar & Video Calling Implementation Guide

## Overview

This guide outlines the implementation of calendar scheduling and video calling features for the HanapBuhay AI Resume Screening Platform. The implementation includes:

- **Calendar Integration**: Syncfusion Flutter Calendar for meeting scheduling
- **Video Calling**: ZEGOCLOUD SDK for real-time video communication
- **Availability Management**: User availability settings and booking system
- **Meeting Requests**: Request and approval workflow for meetings

## 🚀 Features Implemented

### 1. Calendar Functionality
- **Employer Calendar Screen**: View, schedule, and manage meetings
- **Applicant Calendar Screen**: View meetings and request new ones
- **Availability Settings**: Set weekly availability and meeting preferences
- **Meeting Scheduling**: Create meetings with automatic notifications
- **Meeting Requests**: Request meetings with approval workflow

### 2. Video Calling Integration
- **ZEGOCLOUD SDK**: Professional video calling solution
- **Call Invitations**: Send and receive call invitations
- **Call Management**: Accept, decline, and manage calls
- **Chat Integration**: Calendar button replaces attachment button in chat

### 3. Database Schema
- **calendar_events**: Store all calendar events and meetings
- **availability_settings**: User availability preferences
- **meeting_requests**: Meeting request workflow
- **RLS Policies**: Secure data access controls
- **Database Functions**: Automated availability checking and event creation

## 📋 Setup Instructions

### 1. Dependencies Added

```yaml
# Calendar and Video Calling Dependencies
syncfusion_flutter_calendar: ^26.2.14
zego_uikit_prebuilt_call: ^3.8.4
table_calendar: ^3.1.2
```

### 2. Environment Variables

Add these to your `.env` file:

```env
# ZEGOCLOUD Video Calling Configuration
ZEGO_APP_ID=your_zego_app_id
ZEGO_APP_SIGN=your_zego_app_sign
```

### 3. Database Migration

Run the SQL migration in `database_migrations/calendar_schema.sql`:

```sql
-- Execute the entire calendar_schema.sql file in your Supabase SQL editor
-- This creates all necessary tables, indexes, RLS policies, and functions
```

### 4. ZEGOCLOUD Setup

1. **Create ZEGOCLOUD Account**: Sign up at [zegocloud.com](https://zegocloud.com)
2. **Create Project**: Create a new project in ZEGOCLOUD console
3. **Get Credentials**: Copy App ID and App Sign from project settings
4. **Add to Environment**: Add credentials to your `.env` file

### 5. Platform Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for video calls</string>
```

## 🏗️ Architecture

### File Structure

```
lib/
├── models/
│   └── calendar_models.dart          # Calendar data models
├── services/
│   ├── calendar_service.dart         # Calendar operations
│   └── video_call_service.dart       # Video calling functionality
├── screens/
│   ├── employer/
│   │   ├── calendar_screen.dart      # Employer calendar view
│   │   ├── availability_settings_screen.dart
│   │   └── schedule_meeting_screen.dart
│   └── applicant/
│       ├── calendar_screen.dart      # Applicant calendar view
│       └── book_meeting_screen.dart
└── config/
    └── app_config.dart               # Updated with ZEGOCLOUD config
```

### Database Schema

```sql
-- Core Tables
calendar_events          # All calendar events and meetings
availability_settings    # User availability preferences  
meeting_requests        # Meeting request workflow

-- Key Functions
check_time_slot_availability()    # Check if time slot is free
get_available_time_slots()        # Get available slots for booking
create_event_from_meeting_request() # Auto-create events from accepted requests
expire_old_meeting_requests()     # Clean up expired requests
```

## 🔧 Implementation Details

### 1. Calendar Integration

**Syncfusion Flutter Calendar** provides:
- Multiple view modes (month, week, day)
- Custom appointment rendering
- Tap-to-create functionality
- Real-time updates

**Key Features**:
- Professional UI with custom styling
- Responsive design for all screen sizes
- Integration with Supabase real-time updates
- Appointment color coding by type

### 2. Video Calling

**ZEGOCLOUD Integration**:
- Prebuilt UI components for quick integration
- Professional video calling experience
- Cross-platform compatibility
- Real-time communication

**Call Flow**:
1. User initiates call from calendar or chat
2. System generates unique call ID
3. Invitation sent to participants
4. Call starts when participants join
5. Call ends with automatic cleanup

### 3. Availability Management

**Features**:
- Weekly availability settings
- Customizable meeting durations
- Advance booking limits
- Blocked dates support
- Real-time availability checking

**Workflow**:
1. Employer sets availability preferences
2. System generates available time slots
3. Applicants can book from available slots
4. Automatic conflict detection and prevention

### 4. Meeting Requests

**Request Flow**:
1. Applicant selects employer and time slot
2. System creates meeting request
3. Employer receives notification
4. Employer accepts/declines request
5. System auto-creates calendar event if accepted

## 🎨 UI/UX Features

### Design System
- **Color Palette**: Consistent with existing HanapBuhay design
- **Typography**: Professional and readable fonts
- **Icons**: Material Design icons for consistency
- **Animations**: Smooth transitions and loading states

### User Experience
- **Progressive Disclosure**: Step-by-step meeting creation
- **Real-time Updates**: Live calendar and availability updates
- **Intuitive Navigation**: Easy access from chat and main screens
- **Responsive Design**: Works on all device sizes

## 🔒 Security Features

### Row Level Security (RLS)
- Users can only access their own calendar events
- Meeting requests are private to participants
- Availability settings are user-specific

### Data Validation
- Input validation on all forms
- SQL injection prevention
- XSS protection in user inputs

### Access Control
- Role-based access (employer vs applicant)
- Secure API endpoints
- Encrypted data transmission

## 📱 Mobile Optimization

### Performance
- Lazy loading for large calendar views
- Optimized database queries
- Efficient real-time subscriptions
- Minimal memory usage

### Offline Support
- Local caching of calendar events
- Offline availability checking
- Sync when connection restored

## 🚀 Deployment

### Production Checklist
- [ ] ZEGOCLOUD credentials configured
- [ ] Database migration executed
- [ ] Platform permissions set
- [ ] Environment variables secured
- [ ] RLS policies tested
- [ ] Video calling tested on devices

### Testing
- [ ] Calendar functionality on all views
- [ ] Video calling on Android/iOS
- [ ] Availability management
- [ ] Meeting request workflow
- [ ] Real-time updates
- [ ] Error handling

## 🔄 Future Enhancements

### Planned Features
1. **Recurring Meetings**: Support for weekly/monthly recurring meetings
2. **Meeting Templates**: Pre-defined meeting types and durations
3. **Calendar Sync**: Integration with Google Calendar, Outlook
4. **Advanced Scheduling**: AI-powered optimal time suggestions
5. **Meeting Analytics**: Track meeting statistics and insights
6. **File Sharing**: Share documents during meetings
7. **Screen Sharing**: Enhanced collaboration features
8. **Meeting Recording**: Record important meetings
9. **Mobile Notifications**: Push notifications for meetings
10. **Timezone Support**: Multi-timezone meeting coordination

### Technical Improvements
1. **Performance Optimization**: Further optimize database queries
2. **Caching Strategy**: Implement Redis for better performance
3. **Real-time Enhancements**: WebSocket optimization
4. **Mobile App**: Native iOS/Android apps
5. **API Versioning**: Version control for API changes

## 🐛 Troubleshooting

### Common Issues

1. **Video Call Not Working**
   - Check ZEGOCLOUD credentials
   - Verify platform permissions
   - Test on physical device (not simulator)

2. **Calendar Not Loading**
   - Check Supabase connection
   - Verify RLS policies
   - Check user authentication

3. **Availability Not Showing**
   - Ensure availability settings exist
   - Check time zone settings
   - Verify date range

### Debug Tools
- Enable debug mode in app config
- Check Supabase logs
- Monitor ZEGOCLOUD console
- Use Flutter inspector for UI debugging

## 📞 Support

For technical support:
- **Documentation**: Check this guide and code comments
- **ZEGOCLOUD**: [docs.zegocloud.com](https://docs.zegocloud.com)
- **Syncfusion**: [help.syncfusion.com](https://help.syncfusion.com)
- **Supabase**: [supabase.com/docs](https://supabase.com/docs)

---

**Implementation Status**: ✅ Complete
**Last Updated**: January 2025
**Version**: 1.0.0

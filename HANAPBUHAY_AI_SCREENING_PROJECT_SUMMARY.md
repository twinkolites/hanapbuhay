# HanapBuhay AI Resume Screening System - Project Summary

## 🎯 **Project Overview**
This document summarizes the comprehensive AI resume screening system implementation for the HanapBuhay job platform. The system uses Google Gemini API to automate resume screening, providing employers with AI-powered insights to efficiently evaluate job applicants.

## 🏗️ **System Architecture**

### **Frontend (Flutter)**
- **Progressive Disclosure UI**: Step-by-step application profile creation
- **AI Screening Integration**: Real-time AI analysis display
- **Professional Preview System**: Clean, formatted profile preview
- **Mobile-First Design**: Responsive, touch-optimized interface

### **Backend (Supabase)**
- **PostgreSQL Database**: Comprehensive schema with AI screening tables
- **Storage Integration**: PDF resume storage with RLS policies
- **Real-time Features**: Live updates and notifications
- **Authentication**: Secure user management

### **AI Integration**
- **Google Gemini API**: Free-tier AI model for resume analysis
- **PDF Processing**: Automated resume content extraction
- **Structured Analysis**: Skills, experience, education scoring
- **Recommendation Engine**: AI-powered hiring recommendations

## 📊 **Database Schema Analysis**

### **Core Tables**
1. **profiles** - User authentication and basic info
2. **companies** - Employer company profiles
3. **jobs** - Job postings with metadata
4. **job_applications** - Application submissions
5. **applicant_profile** - Comprehensive applicant data (NEW)

### **AI Screening Tables**
1. **ai_screening_results** - AI analysis results
2. **ai_screening_criteria** - Customizable screening criteria

### **Key Schema Features**
- **JSONB Fields**: Flexible data storage for skills, education, experience
- **RLS Policies**: Row-level security for data protection
- **Foreign Key Constraints**: Proper relational integrity
- **Audit Logging**: Complete change tracking
- **Profile Completeness**: Automated calculation system

## 🚀 **Major Features Implemented**

### **1. AI Resume Screening System**
- **Automated Analysis**: AI evaluates resumes against job requirements
- **Scoring System**: 0-10 scale for skills, experience, education
- **Detailed Insights**: Strengths, concerns, and recommendations
- **Batch Processing**: Screen multiple applications simultaneously

### **2. Enhanced Application Profile**
- **Comprehensive Data**: 15+ fields for complete professional profiles
- **Progressive Disclosure**: Step-by-step profile completion
- **Real-time Validation**: Immediate feedback on required fields
- **Profile Completeness**: Visual progress tracking

### **3. Professional UI/UX Design**
- **Clean Interface**: No gradients, professional color scheme
- **Mobile Optimized**: Responsive design for all devices
- **Visual Hierarchy**: Clear information organization
- **Accessibility**: Proper contrast and touch targets

### **4. PDF Resume Processing**
- **File Upload**: PDF-only resume uploads
- **Content Extraction**: Automated text extraction from PDFs
- **Storage Management**: Secure file storage with RLS
- **URL Generation**: Public URLs for AI processing

### **5. Profile Preview System**
- **Professional Layout**: Clean, formatted profile display
- **Real-time Preview**: Shows current form data
- **Export Ready**: Print and share functionality
- **Responsive Design**: Works on all screen sizes

### **6. Job Application Withdrawal System** (NEW)
- **Professional Withdrawal Process**: Industry-standard withdrawal handling following web best practices
- **Feedback Collection**: Optional reason selection with common withdrawal reasons
- **Database Tracking**: Complete audit trail with withdrawal reason and timestamp
- **Status Management**: Proper status updates and visual indicators
- **Employer Analytics**: Withdrawal data collection for process improvement
- **Professional Communication**: Maintains positive candidate-employer relationships
- **User Experience**: Intuitive dialog with quick-select reasons and custom input

## 🔧 **Technical Implementation**

### **Dependencies Added**
```yaml
google_generative_ai: ^0.4.7
syncfusion_flutter_pdf: ^26.2.14
file_picker: ^8.0.0+1
```

### **Key Services**
- **AIScreeningService**: Core AI integration logic
- **JobService**: Job management functionality
- **AuthService**: User authentication
- **ChatService**: Real-time messaging

### **Database Functions**
- **calculate_profile_completeness()**: Automated completeness calculation
- **update_profile_completeness()**: Trigger-based updates
- **RLS Policies**: Secure data access control

## 📱 **User Experience Features**

### **For Applicants**
- **Step-by-Step Profile**: Guided profile creation process
- **Real-time Feedback**: Immediate validation and progress tracking
- **Professional Preview**: See how profile appears to employers
- **Data Pre-population**: Auto-fill from existing user data

### **For Employers**
- **AI Insights Dashboard**: Comprehensive screening results
- **Batch Screening**: Process multiple applications at once
- **Detailed Analysis**: Skills, experience, education breakdowns
- **Recommendation Engine**: AI-powered hiring suggestions

## 🎨 **UI/UX Improvements**

### **Design Principles Applied**
1. **Progressive Disclosure**: Information revealed step-by-step
2. **Visual Progress Indicators**: Clear completion status
3. **Consistent Design Language**: Uniform colors, typography, spacing
4. **Mobile-First Approach**: Optimized for mobile devices
5. **Accessibility**: Proper contrast ratios and touch targets
6. **Compact Design**: Efficient space utilization without sacrificing usability
7. **Professional Aesthetics**: Clean, modern interface following web best practices

### **Color Scheme**
- **Primary**: Medium Sea Green (#4CA771)
- **Secondary**: Dark Teal (#013237)
- **Accent**: Blue (#2196F3)
- **Success**: Green (#4CAF50)
- **Warning**: Orange (#FF9800)
- **Error**: Red (#F44336)
- **Withdrawn**: Grey (#9E9E9E)

### **Typography Scale (Latest Updates)**
- **Body Text**: 11px (standard reading text)
- **Titles**: 13px (section headers)
- **Maximum**: 16px (main headings only)
- **Consistent Hierarchy**: Clear visual information architecture

## 📈 **Performance Optimizations**

### **Frontend**
- **Efficient Rendering**: Only current step content rendered
- **Smooth Animations**: 60fps animations with proper disposal
- **Memory Management**: Proper controller disposal
- **Responsive Layout**: Adaptive to screen sizes

### **Backend**
- **Database Indexing**: Optimized query performance
- **RLS Policies**: Efficient data filtering
- **Storage Optimization**: Compressed file storage
- **Caching**: Reduced API calls
- **Stored Procedures**: Database-level operations for chat and profile data
- **Database Triggers**: Automated updates for real-time chat functionality
- **Data Type Optimization**: Fixed enum and bigint handling for better performance

### **Chat System Performance** (Latest)
- **Database Procedures**: `get_user_chats()`, `get_chat_messages()`, `mark_chat_messages_read()`
- **Automatic Triggers**: `update_chat_last_message()` for real-time updates
- **Comprehensive Indexing**: Optimized queries for chat operations
- **Error Handling**: Robust error handling for chat operations

### **Profile Screen Performance** (Latest)
- **Single RPC Calls**: Consolidated data fetching with `get_applicant_profile_stats()` and `get_employer_profile_data()`
- **Smart Caching**: 30-second cache implementation to prevent unnecessary reloads
- **Fallback Methods**: Comprehensive error handling for failed RPC calls
- **Performance Monitoring**: Cache-based performance improvements

## 🔒 **Security Features**

### **Data Protection**
- **Row-Level Security**: User-specific data access
- **File Upload Validation**: PDF-only, size-limited uploads
- **Input Sanitization**: XSS and injection prevention
- **Audit Logging**: Complete change tracking

### **API Security**
- **Environment Variables**: Secure API key storage
- **Rate Limiting**: Prevents API abuse
- **Error Handling**: Secure error messages
- **Authentication**: JWT-based user sessions

## 📊 **Sample Data**

### **Mock Applicant Profile (Tenkol Rodriguez)**
- **Complete Profile**: 100% completeness score
- **Professional Summary**: Comprehensive career overview
- **Work Experience**: 3 positions with detailed descriptions
- **Education**: Bachelor's and Master's degrees
- **Skills**: 14 technical and soft skills
- **Certifications**: 3 industry certifications
- **Languages**: 3 languages with proficiency levels
- **Social Links**: LinkedIn, Portfolio, GitHub profiles

## 🎯 **Business Impact**

### **For Employers**
- **Time Savings**: Automated initial screening
- **Better Decisions**: AI-powered insights
- **Scalability**: Handle large application volumes
- **Quality Control**: Consistent evaluation criteria
- **Withdrawal Analytics**: Insights into why candidates withdraw applications
- **Process Improvement**: Feedback collection helps identify recruitment process issues
- **Professional Handling**: Maintains positive candidate experience and employer brand
- **Data-Driven Decisions**: Withdrawal data for better recruitment strategy

### **For Applicants**
- **Professional Profiles**: Comprehensive data collection
- **Fair Evaluation**: Consistent AI assessment
- **Better Matching**: Improved job-candidate fit
- **Transparency**: Clear profile completeness tracking
- **Professional Withdrawal**: Easy, respectful application withdrawal process
- **Feedback Opportunity**: Can provide constructive feedback during withdrawal
- **Positive Relationships**: Maintains professional relationships with employers

## 🚀 **Future Enhancements**

### **Pending Features**
- **AI Screening Configuration**: Customizable employer criteria
- **Advanced Analytics**: Detailed screening statistics
- **Integration APIs**: Third-party platform connections
- **Machine Learning**: Continuous model improvement

### **Scalability Considerations**
- **Multi-tenant Architecture**: Support multiple companies
- **Performance Monitoring**: Real-time system metrics
- **Load Balancing**: Handle increased traffic
- **Data Archiving**: Long-term data management

## 🔄 **Recent Major Updates & Fixes**

### **Job Application Withdrawal System** (Latest Updates - December 2024)
- **Professional Withdrawal Handling**: Implemented comprehensive withdrawal system following industry best practices
- **Database Schema Enhancement**: Added `withdrawal_reason` and `withdrawn_at` columns to `job_applications` table
- **Withdrawal Status Tracking**: Added `'withdrawn'` status to `app_status` enum for proper status management
- **Feedback Collection System**: Optional reason selection with common withdrawal reasons (found another opportunity, changed mind, salary expectations, etc.)
- **Enhanced User Experience**: Professional dialog design with quick-select reasons and custom text input
- **Employer Analytics**: Withdrawal data collection for process improvement and candidate insights
- **Status Management**: Updated status filters, colors, and display logic to include withdrawn applications
- **Professional Communication**: Maintains positive candidate-employer relationships through courteous messaging

### **UI/UX Design System Overhaul** (Latest Updates - December 2024)
- **Applications Overview Screen Redesign**: Completely redesigned employer applications overview for better space utilization
- **Compact Header Design**: Combined AI screening button with key statistics in single compact header
- **Optimized Application Cards**: Reduced card sizes, improved information hierarchy, and better visual organization
- **Enhanced Filter System**: Compact filter chips with reduced height and improved spacing
- **AI Analysis Report Improvements**: Redesigned AI details sheet with smaller sizing (body 11px, title 13px, max 16px)
- **Professional Dialog Design**: Improved status update dialogs with better typography and spacing
- **Mobile-First Optimization**: Better touch targets, responsive layouts, and improved readability
- **Consistent Design Language**: Unified spacing scale (8px, 12px, 16px, 20px) and typography hierarchy

### **Chat System Performance Optimization** (Latest Updates - December 2024)
- **Supabase Stored Procedures**: Implemented database-level procedures for chat operations (`get_user_chats`, `get_chat_messages`, `mark_chat_messages_read`)
- **Database Triggers**: Added automatic `update_chat_last_message()` trigger for real-time chat updates
- **Performance Indexing**: Created comprehensive database indexes for faster chat queries
- **Data Type Fixes**: Resolved `bigint` vs `integer` and `enum` vs `text` data type mismatches
- **UI Rendering Fixes**: Fixed message display issues and visual gaps in chat interfaces
- **Debug Code Cleanup**: Removed all debug print statements for cleaner production code
- **Error Handling**: Enhanced error handling for chat operations and real-time updates

### **Messaging System UI/UX Overhaul** (Latest Updates - December 2024)
- **WhatsApp/Messenger-Style Design**: Implemented proper message bubble separation with left/right alignment
- **Message Status Indicators**: Added comprehensive status tracking (sending → sent → delivered → seen)
- **Real-time Status Updates**: Fixed messages stuck in "sending" status with proper progression logic
- **Timestamp & Status Display**: Implemented tap-to-show timestamps for sender messages and status indicators for user messages
- **Chronological Message Ordering**: Fixed message display order (oldest at top, newest at bottom)
- **Avatar & Name Positioning**: Corrected avatar display with latest messages and names with first messages
- **Typing Indicators**: Added real-time typing indicators with animated dots ("..." bubble)
- **Message Input Optimization**: Reduced padding and spacing for better space utilization
- **Action Button Cleanup**: Removed unnecessary reload, video call, and settings buttons for cleaner interface
- **Database Schema Fixes**: Resolved message status progression issues and stuck "sending" messages
- **Error Handling**: Enhanced error handling for failed message status updates
- **Professional Layout**: Implemented industry-standard messaging app patterns and visual hierarchy

### **Profile Screen Performance Enhancement** (Latest Updates - December 2024)
- **Consolidated Data Fetching**: Single RPC calls (`get_applicant_profile_stats`, `get_employer_profile_data`) for all profile data
- **Caching Implementation**: Added `_lastDataLoad` timestamp with 30-second cache to prevent unnecessary reloads
- **Database Optimization**: Reduced network requests from multiple queries to single optimized procedures
- **Error Handling**: Added comprehensive fallback methods for failed RPC calls
- **Performance Monitoring**: Implemented cache-based performance improvements

### **AI Screening System Overhaul** (Previous Updates - December 2024)
- **Fixed 0.0 Score Issue**: Resolved critical bug where AI was returning 0.0 scores despite working analysis
- **JSON Parsing Fix**: Replaced corrupted `Uri.splitQueryString()` with proper `jsonDecode()` for accurate data parsing
- **Database Query Optimization**: Fixed `.single()` to `.maybeSingle()` in application details queries to prevent exceptions
- **Enhanced Debug Logging**: Added comprehensive logging throughout AI screening pipeline for better troubleshooting
- **Model Compatibility**: Updated model list to use `gemini-2.5-flash` and other free-tier compatible models
- **Profile Data Integration**: Fixed applicant profile lookup to properly extract structured resume data instead of just cover letters
- **Error Handling**: Improved error handling for missing profiles and failed AI responses

### **Enhanced Application System** (Latest Updates)
- **Profile Integration**: `apply_job_screen.dart` now pre-populates with comprehensive applicant profile data
- **AI-Powered Cover Letter Generation**: Personalized cover letters generated using Google Gemini AI with job-specific details
- **PDF Resume Upload**: Direct file upload to Supabase Storage with proper RLS policies
- **Immediate AI Screening**: Automatic AI analysis triggered upon successful application submission
- **Application Tracking**: Complete audit trail of application status changes with `application_tracking` table
- **Enhanced Database Schema**: Added fields for `application_notes`, `employer_rating`, `interview_scheduled_at`, `profile_completeness_score`, `ai_screening_triggered`, `application_stage`

### **UI/UX Improvements** (Latest Updates)
- **Professional Redesign**: Complete overhaul of `apply_job_screen.dart` with modern, clean design
- **Responsive Layout**: Fixed overflow issues using `Expanded`, `Flexible`, and `Wrap` widgets
- **Optimized Text Sizing**: Adjusted all text sizes to 11-16px range for better readability
- **Compact Design**: Reduced vertical spacing and element sizes for efficient screen usage
- **Card-Based Layout**: Modern card design with proper shadows, borders, and rounded corners
- **Progressive Disclosure**: Step-by-step form completion with visual progress indicators
- **Button Layout Enhancement**: Reorganized application card buttons with wide "View Details" button below AI Analysis and Chat buttons

### **AI Integration Enhancements** (Latest Updates)
- **Model Fallback System**: Implemented fallback mechanism for Google Gemini API free tier limitations
- **Dynamic Model Tracking**: System automatically detects and uses compatible AI models
- **Error Handling**: Comprehensive error handling for missing resume PDFs and API failures
- **Resume Content Extraction**: Enhanced PDF processing with fallback to cover letter content
- **AI Insights Dashboard**: Detailed analysis display with error states and recommendations
- **Debug Functions**: Added `debugResumeExtraction()` and `testDatabaseConnection()` for troubleshooting
- **Proper JSON Handling**: Fixed AI response parsing to maintain data integrity

### **Database & Security Fixes** (Latest Updates)
- **RLS Policy Updates**: Added missing policies for `application_tracking` table
- **Schema Alignment**: Fixed enum values and column references to match actual database schema
- **Null Safety**: Implemented comprehensive null safety across all employer screens
- **Data Validation**: Enhanced input validation and error handling throughout the system
- **Query Optimization**: Fixed database queries to use proper methods and handle edge cases

### **Employer Experience Improvements** (Latest Updates)
- **Enhanced Application Cards**: Better display of applicant information with profile completeness indicators
- **AI Score Integration**: Prominent display of AI analysis scores and recommendations (now showing real scores instead of 0.0)
- **Application Details Modal**: Comprehensive application information in expandable bottom sheets
- **Error State Handling**: Clear indication when resume PDFs are missing or AI analysis fails
- **Responsive Design**: Fixed overflow issues in application cards and lists
- **Improved Button Layout**: Better visual hierarchy with wide "View Details" button for primary action

### **Code Quality & Maintenance** (Latest Updates)
- **Linting Fixes**: Resolved all Flutter analyzer warnings and errors
- **Code Refactoring**: Cleaned up orphaned code and improved structure
- **Error Handling**: Added comprehensive try-catch blocks and user-friendly error messages
- **Performance Optimization**: Improved rendering efficiency and memory management
- **Debug Infrastructure**: Added comprehensive debugging tools for AI screening system

### **Technical Challenges Solved** (Latest Updates)
- **Google Gemini API Free Tier**: Implemented model fallback system to handle API limitations
- **UI Overflow Issues**: Fixed responsive layout problems using proper Flutter widgets
- **Database Schema Mismatches**: Aligned code with actual Supabase schema and enum values
- **RLS Policy Violations**: Added missing policies for application tracking functionality
- **Null Safety Errors**: Implemented comprehensive null safety across all screens
- **PDF Processing Failures**: Added fallback mechanisms for missing resume content
- **AI Model Compatibility**: Dynamic model detection and initialization system
- **JSON Parsing Corruption**: Fixed critical data corruption in AI response parsing
- **Profile Data Extraction**: Resolved issue where AI only received cover letters instead of full profile data
- **Database Query Failures**: Fixed application details queries that were throwing exceptions

## 📋 **Project Status**

### **Completed Features** ✅
- AI Resume Screening System
- Enhanced Application Profile
- Professional UI/UX Design
- PDF Resume Processing
- Profile Preview System
- Database Schema Optimization
- Security Implementation
- Mobile Optimization
- **NEW**: Profile Integration in Application Process
- **NEW**: AI-Powered Cover Letter Generation
- **NEW**: PDF Resume Upload System
- **NEW**: Immediate AI Screening Trigger
- **NEW**: Application Tracking System
- **NEW**: Enhanced Employer Application Management
- **NEW**: Responsive UI/UX Design
- **NEW**: Comprehensive Error Handling
- **NEW**: Model Fallback System for AI APIs
- **LATEST**: Fixed 0.0 AI Score Bug - Now showing real scores (7.5/10)
- **LATEST**: JSON Parsing Corruption Fix
- **LATEST**: Database Query Optimization
- **LATEST**: Enhanced Debug Logging System
- **LATEST**: Profile Data Integration Fix
- **LATEST**: Improved Button Layout in Application Cards
- **LATEST**: Comprehensive AI Screening Debug Tools
- **LATEST**: Professional Job Application Withdrawal System
- **LATEST**: Chat System Performance Optimization with Database Procedures
- **LATEST**: Profile Screen Performance Enhancement with Caching
- **LATEST**: Applications Overview Screen UI/UX Redesign
- **LATEST**: AI Analysis Report Design Improvements
- **LATEST**: WhatsApp/Messenger-Style Chat Interface with Status Indicators
- **LATEST**: Real-time Message Status Tracking (sending → sent → delivered → seen)
- **LATEST**: Professional Chat UI/UX with Proper Message Bubble Separation
- **LATEST**: Typing Indicators and Real-time Chat Updates
- **LATEST**: Message Status Progression Logic and Database Schema Fixes

### **In Progress** 🔄
- AI Screening Configuration for Employers
- Advanced Analytics Dashboard
- Performance Monitoring

### **Future Roadmap** 📅
- Machine Learning Model Training
- Third-party Integrations
- Advanced Reporting
- Mobile App Optimization

## 🔧 **Development Environment**

### **Project Structure**
```
lib/
├── config/           # App configuration
├── providers/        # State management
├── screens/          # UI screens
│   ├── applicant/    # Applicant-specific screens
│   └── employer/     # Employer-specific screens
├── services/         # Business logic
├── utils/            # Helper functions
└── widgets/          # Reusable components
```

### **Key Files**
- `ai_screening_service.dart` - **LATEST**: Core AI integration with fixed JSON parsing, debug logging, and profile data extraction
- `application_profile_screen.dart` - Profile creation UI with progressive disclosure
- `profile_preview_screen.dart` - Professional preview system
- `apply_job_screen.dart` - **ENHANCED**: Profile integration, AI cover letter generation, PDF upload
- `applications_screen.dart` - **ENHANCED**: Employer application management with responsive design + **NEW**: Professional withdrawal system
- `applications_screen.dart` (applicant) - **LATEST**: Comprehensive withdrawal dialog with feedback collection and professional messaging
- `ai_insights_page.dart` - **ENHANCED**: AI analysis dashboard with error handling
- `applications_overview_screen.dart` - **LATEST**: Complete UI/UX redesign with compact header, optimized cards, and better space utilization
- `job_service.dart` - **ENHANCED**: Application handling with AI integration + **NEW**: `withdrawApplication()` method
- `home_screen.dart` - **ENHANCED**: Applied job handling and navigation + **NEW**: `setState()` after dispose fixes
- `chat_service.dart` - **LATEST**: Performance optimization with Supabase stored procedures, database triggers, message status tracking, and real-time typing indicators
- `chat_screen.dart` (applicant) - **LATEST**: WhatsApp/Messenger-style UI with proper message bubble separation, status indicators, and real-time updates
- `chat_screen.dart` (employer) - **LATEST**: Professional chat interface with chronological message ordering and optimized spacing
- `profile_screen.dart` (both) - **LATEST**: Performance enhancement with single RPC calls and caching implementation
- `application_details_sheet.dart` - **LATEST**: Refactored from applications_screen.dart for better code organization

## 🔧 **Debugging & Troubleshooting Tools**

### **AI Screening Debug Functions** (Latest Addition)
- **`debugResumeExtraction(applicationId)`**: Tests resume content extraction process with detailed logging
- **`testDatabaseConnection()`**: Verifies database connectivity and data availability
- **`testBasicConnection()`**: Tests AI API connection and model availability
- **`listAvailableModels()`**: Discovers which AI models are available in the current API tier
- **`manualTriggerScreening(applicationId)`**: Manually triggers AI screening for testing purposes

### **Enhanced Logging System**
- **Comprehensive Debug Output**: Detailed logging throughout the AI screening pipeline
- **Profile Data Tracking**: Logs applicant profile lookup and data extraction
- **AI Response Analysis**: Logs AI responses and JSON parsing results
- **Error State Identification**: Clear identification of failure points in the screening process
- **Performance Monitoring**: Tracks processing times and success rates

### **Troubleshooting Workflow**
1. **Run `testDatabaseConnection()`** to verify data availability
2. **Use `debugResumeExtraction()`** to test profile data extraction
3. **Check AI model availability** with `listAvailableModels()`
4. **Test manual screening** with `manualTriggerScreening()`
5. **Review debug logs** for detailed error analysis

## 📞 **Support & Maintenance**

### **Monitoring**
- **Error Tracking**: Comprehensive error logging
- **Performance Metrics**: Real-time system monitoring
- **User Analytics**: Usage pattern analysis
- **Security Audits**: Regular security assessments

### **Documentation**
- **API Documentation**: Complete endpoint reference
- **User Guides**: Step-by-step user instructions
- **Developer Docs**: Technical implementation details
- **Troubleshooting**: Common issue resolution

---

## 🎯 **Next Steps for New Developer**

1. **Review Codebase**: Understand the Flutter app structure
2. **Analyze Database**: Study the Supabase schema and relationships
3. **Test AI Integration**: Verify Gemini API functionality
4. **Review UI Components**: Understand the progressive disclosure design
5. **Check Security**: Validate RLS policies and data protection
6. **Test Features**: Verify all implemented functionality works
7. **Plan Enhancements**: Identify areas for improvement
8. **Document Changes**: Maintain comprehensive documentation

This system represents a comprehensive, production-ready AI resume screening platform that significantly enhances the job application process for both employers and applicants.

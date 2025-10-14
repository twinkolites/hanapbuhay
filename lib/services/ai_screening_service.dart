import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'onesignal_notification_service.dart';

class AIScreeningService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static late final GenerativeModel _model;
  static bool _isInitialized = false;
  static String _currentModelName = 'unknown';

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Try multiple models in order of preference (using models available in free tier)
      final modelsToTry = [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro',
        'gemini-pro-vision',
        'gemini-1.0-pro',
      ];
      
      GenerativeModel? model;
      String? successfulModel;
      for (final modelName in modelsToTry) {
        try {
          // Validate API key first
          if (AppConfig.geminiApiKey.isEmpty) {
            debugPrint('❌ Gemini API key is empty');
            continue;
          }
          
          model = GenerativeModel(
            model: modelName,
            apiKey: AppConfig.geminiApiKey,
          );
          
          // Test the model with a simple request
          final testContent = [Content.text('Test')];
          final testResponse = await model.generateContent(testContent);
          
          if (testResponse.text != null) {
            successfulModel = modelName;
            debugPrint('✅ AI Screening Service initialized with model: $modelName');
            break;
          } else {
            debugPrint('❌ Model $modelName returned null response');
            continue;
          }
        } catch (e) {
          debugPrint('❌ Failed to initialize model $modelName: $e');
          continue;
        }
      }
      
      if (model != null && successfulModel != null) {
        _model = model;
        _currentModelName = successfulModel;
        _isInitialized = true;
      } else {
        debugPrint('❌ All AI models failed to initialize');
        _currentModelName = 'failed';
      }
    } catch (e) {
      debugPrint('❌ Error initializing AI Screening Service: $e');
    }
  }

  static Future<Map<String, dynamic>?> screenResume({
    required String applicationId,
  }) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
        // Wait a bit for initialization
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isInitialized) {
          debugPrint('❌ AI Screening Service still not initialized after retry');
          return null;
        }
      }

      // Get application details
      final application = await _getApplicationDetails(applicationId);
      if (application == null) return null;

      // Extract resume content
      final resumeContent = await _extractResumeContent(applicationId);
      if (resumeContent == null) {
        debugPrint('❌ Could not extract resume content');
        return null;
      }

      // Check for error cases
      if (resumeContent == 'ERROR_NO_RESUME_CONTENT') {
        // Store error result in database
        final errorResult = await _storeErrorResult(applicationId, 'No resume content available');
        return errorResult;
      }

      // Generate AI analysis
      final analysis = await _analyzeWithGemini(application, resumeContent);
      
      // Store results in database
      final result = await _storeScreeningResult(applicationId, analysis);
      
      return result;
    } catch (e) {
      debugPrint('❌ Error in AI screening: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getApplicationDetails(String applicationId) async {
    try {
      debugPrint('🔍 Getting application details for ID: $applicationId');
      final response = await _supabase
          .from('job_applications')
          .select('''
            *,
            jobs (
              *,
              companies (*)
            ),
            profiles (*)
          ''')
          .eq('id', applicationId)
          .maybeSingle();
      
      debugPrint('🔍 Application query result: ${response != null ? 'Found' : 'Not found'}');
      if (response != null) {
        debugPrint('🔍 Application applicant_id: ${response['applicant_id']}');
        debugPrint('🔍 Application keys: ${response.keys.toList()}');
      }
      
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching application details: $e');
      return null;
    }
  }

  static Future<String?> _extractResumeContent(String applicationId) async {
    try {
      // Get application details with applicant profile
      final application = await _getApplicationDetails(applicationId);
      if (application == null) return null;

      // First, try to get structured data from applicant_profile table
      final applicantProfile = await _getApplicantProfile(application['applicant_id']);
      debugPrint('🔍 Applicant profile found: ${applicantProfile != null}');
      if (applicantProfile != null) {
        debugPrint('🔍 Profile data keys: ${applicantProfile.keys.toList()}');
        debugPrint('🔍 Skills: ${applicantProfile['skills']}');
        debugPrint('🔍 Professional summary: ${applicantProfile['professional_summary']}');
        
        final structuredData = _buildStructuredResumeData(applicantProfile);
        debugPrint('🔍 Structured data length: ${structuredData.length}');
        if (structuredData.isNotEmpty) {
          debugPrint('✅ Using structured applicant profile data');
          debugPrint('🔍 First 200 chars of structured data: ${structuredData.substring(0, structuredData.length > 200 ? 200 : structuredData.length)}...');
          return structuredData;
        }
      }

      // Fallback to resume text if available
      if (applicantProfile?['resume_text'] != null && applicantProfile!['resume_text'].toString().isNotEmpty) {
        debugPrint('✅ Using extracted resume text');
        return applicantProfile['resume_text'];
      }

      // Try to extract from resume URL (skip placeholder URLs)
      final resumeUrl = application['resume_url'] ?? applicantProfile?['resume_url'];
      if (resumeUrl != null && resumeUrl.isNotEmpty && !resumeUrl.contains('example.com')) {
        final resumeText = await _extractPDFContent(resumeUrl);
        if (resumeText != null && resumeText.isNotEmpty) {
          debugPrint('✅ Successfully extracted resume from PDF');
          return resumeText;
        }
      } else if (resumeUrl != null && resumeUrl.contains('example.com')) {
        debugPrint('⚠️ Skipping placeholder resume URL: $resumeUrl');
      }

      // Use cover letter as fallback
      final coverLetter = application['cover_letter'];
      if (coverLetter != null && coverLetter.toString().isNotEmpty) {
        debugPrint('⚠️ Using cover letter as fallback');
        return 'Cover Letter:\n$coverLetter';
      }

      debugPrint('❌ No resume content available');
      return 'ERROR_NO_RESUME_CONTENT';
    } catch (e) {
      debugPrint('❌ Error extracting resume content: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getApplicantProfile(String applicantId) async {
    try {
      debugPrint('🔍 Looking for applicant profile with user_id: $applicantId');
      final response = await _supabase
          .from('applicant_profile')
          .select('*')
          .eq('user_id', applicantId)
          .maybeSingle();
      
      debugPrint('🔍 Profile query result: ${response != null ? 'Found' : 'Not found'}');
      if (response != null) {
        debugPrint('🔍 Profile keys: ${response.keys.toList()}');
      }
      
      return response;
    } catch (e) {
      debugPrint('❌ Error getting applicant profile: $e');
      return null;
    }
  }

  static String _buildStructuredResumeData(Map<String, dynamic> profile) {
    final buffer = StringBuffer();
    
    // Personal Information
    buffer.writeln('=== PERSONAL INFORMATION ===');
    if (profile['full_name'] != null) buffer.writeln('Name: ${profile['full_name']}');
    if (profile['email'] != null) buffer.writeln('Email: ${profile['email']}');
    if (profile['phone_number'] != null) buffer.writeln('Phone: ${profile['phone_number']}');
    if (profile['location'] != null) buffer.writeln('Location: ${profile['location']}');
    buffer.writeln();

    // Professional Summary
    if (profile['professional_summary'] != null) {
      buffer.writeln('=== PROFESSIONAL SUMMARY ===');
      buffer.writeln(profile['professional_summary']);
      buffer.writeln();
    }

    // Professional Information
    buffer.writeln('=== PROFESSIONAL INFORMATION ===');
    if (profile['current_position'] != null) buffer.writeln('Current Position: ${profile['current_position']}');
    if (profile['current_company'] != null) buffer.writeln('Current Company: ${profile['current_company']}');
    if (profile['years_of_experience'] != null) buffer.writeln('Years of Experience: ${profile['years_of_experience']}');
    buffer.writeln();

    // Skills
    if (profile['skills'] != null) {
      final skills = profile['skills'] as List<dynamic>;
      if (skills.isNotEmpty) {
        buffer.writeln('=== SKILLS ===');
        buffer.writeln('Skills: ${skills.join(', ')}');
        buffer.writeln();
      }
    }

    // Languages
    if (profile['languages'] != null) {
      final languages = profile['languages'] as List<dynamic>;
      if (languages.isNotEmpty) {
        buffer.writeln('=== LANGUAGES ===');
        for (int i = 0; i < languages.length; i++) {
          final lang = languages[i] as Map<String, dynamic>;
          buffer.writeln('${i + 1}. ${lang['name'] ?? 'Language'} - ${lang['proficiency'] ?? 'Proficiency'}');
        }
        buffer.writeln();
      }
    }

    // Education
    if (profile['education'] != null) {
      final education = profile['education'] as List<dynamic>;
      if (education.isNotEmpty) {
        buffer.writeln('=== EDUCATION ===');
        for (int i = 0; i < education.length; i++) {
          final edu = education[i] as Map<String, dynamic>;
          buffer.writeln('${i + 1}. ${edu['degree'] ?? 'Degree'} from ${edu['institution'] ?? 'Institution'}');
          if (edu['year'] != null) buffer.writeln('   Year: ${edu['year']}');
          if (edu['field'] != null) buffer.writeln('   Field: ${edu['field']}');
          buffer.writeln();
        }
      }
    }

    // Work Experience
    if (profile['work_experience'] != null) {
      final experiences = profile['work_experience'] as List<dynamic>;
      if (experiences.isNotEmpty) {
        buffer.writeln('=== WORK EXPERIENCE ===');
        for (int i = 0; i < experiences.length; i++) {
          final exp = experiences[i] as Map<String, dynamic>;
          buffer.writeln('${i + 1}. ${exp['title'] ?? 'Position'} at ${exp['company'] ?? 'Company'}');
          if (exp['description'] != null) buffer.writeln('   ${exp['description']}');
          if (exp['duration'] != null) buffer.writeln('   Duration: ${exp['duration']}');
          buffer.writeln();
        }
      }
    }

    // Certifications
    if (profile['certifications'] != null) {
      final certs = profile['certifications'] as List<dynamic>;
      if (certs.isNotEmpty) {
        buffer.writeln('=== CERTIFICATIONS ===');
        for (int i = 0; i < certs.length; i++) {
          final cert = certs[i] as Map<String, dynamic>;
          buffer.writeln('${i + 1}. ${cert['name'] ?? 'Certification'}');
          if (cert['issuer'] != null) buffer.writeln('   Issuer: ${cert['issuer']}');
          if (cert['date'] != null) buffer.writeln('   Date: ${cert['date']}');
          buffer.writeln();
        }
      }
    }

    // Additional Information
    buffer.writeln('=== ADDITIONAL INFORMATION ===');
    if (profile['portfolio_url'] != null) buffer.writeln('Portfolio: ${profile['portfolio_url']}');
    if (profile['linkedin_url'] != null) buffer.writeln('LinkedIn: ${profile['linkedin_url']}');
    if (profile['github_url'] != null) buffer.writeln('GitHub: ${profile['github_url']}');
    buffer.writeln();

    return buffer.toString();
  }

  static Future<String?> _extractPDFContent(String pdfUrl) async {
    try {
      // Validate PDF URL
      if (!pdfUrl.toLowerCase().endsWith('.pdf')) {
        debugPrint('❌ Invalid PDF URL: $pdfUrl');
        return null;
      }

      debugPrint('📄 Downloading PDF from: $pdfUrl');
      
      // Download PDF content
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download PDF: ${response.statusCode}');
        return null;
      }

      // Validate content type
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/pdf')) {
        debugPrint('❌ Invalid content type: $contentType');
        return null;
      }

      debugPrint('📄 Extracting text from PDF (${response.bodyBytes.length} bytes)');

      // Extract text using Syncfusion PDF
      final PdfDocument document = PdfDocument(inputBytes: response.bodyBytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (extractedText.trim().isEmpty) {
        debugPrint('❌ No text found in PDF - may be image-based or corrupted');
        return null;
      }

      debugPrint('✅ Successfully extracted ${extractedText.length} characters from PDF');
      return extractedText;
    } catch (e) {
      debugPrint('❌ Error extracting PDF content: $e');
      return null;
    }
  }


  // Trigger AI screening immediately after application
  static Future<Map<String, dynamic>?> triggerAIScreening({
    required String applicationId,
  }) async {
    try {
      if (!_isInitialized) {
        debugPrint('❌ AI Screening Service not initialized');
        return null;
      }

      // Mark as triggered in database
      await _supabase
          .from('job_applications')
          .update({
            'ai_screening_triggered': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);

      // Perform AI screening
      final result = await screenResume(applicationId: applicationId);
      
      if (result != null) {
        debugPrint('✅ AI screening completed for application: $applicationId');
        
        // Send notification to employer
        await _sendScreeningNotification(applicationId, result);
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Error triggering AI screening: $e');
      return null;
    }
  }

  // Send notification to employer about AI screening completion
  static Future<void> _sendScreeningNotification(
    String applicationId,
    Map<String, dynamic> screeningResult,
  ) async {
    try {
      // Get application details
      final application = await _getApplicationDetails(applicationId);
      if (application == null) return;

      final job = application['jobs'];
      final company = job['companies'];
      final applicant = application['profiles'];
      
      // Send OneSignal notifications
      await OneSignalNotificationService.sendAIScreeningCompletedNotification(
        applicantId: application['applicant_id'],
        employerId: company['owner_id'],
        jobId: job['id'],
        jobTitle: job['title'],
        applicantName: applicant['full_name'] ?? 'Unknown',
        score: screeningResult['overall_score']?.toDouble() ?? 0.0,
        recommendation: screeningResult['reasoning'] ?? 'Analysis completed',
        applicationId: applicationId,
      );

      // Also create database notification for consistency
      await _supabase
          .from('notifications')
          .insert({
            'user_id': company['owner_id'],
            'type': 'ai_screening_completed',
            'payload': {
              'application_id': applicationId,
              'job_title': job['title'],
              'applicant_name': applicant['full_name'],
              'ai_score': screeningResult['overall_score'],
              'recommendation': screeningResult['reasoning'],
            },
            'is_read': false,
          });

      debugPrint('✅ AI screening notifications sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending screening notification: $e');
    }
  }

  // Enhanced AI analysis with more comprehensive evaluation
  static Future<Map<String, dynamic>> _analyzeWithGemini(
    Map<String, dynamic> application,
    String resumeContent,
  ) async {
    final job = application['jobs'];
    final applicant = application['profiles'];
    
    debugPrint('🔍 AI Analysis - Resume content length: ${resumeContent.length}');
    debugPrint('🔍 AI Analysis - First 300 chars: ${resumeContent.substring(0, resumeContent.length > 300 ? 300 : resumeContent.length)}...');
    
    final prompt = '''
Analyze this resume comprehensively for the job position: "${job['title']}"

JOB REQUIREMENTS:
- Title: ${job['title']}
- Description: ${job['description']}
- Experience Level: ${job['experience_level']}
- Location: ${job['location']}
- Type: ${job['type']}
- Salary Range: ${job['salary_min']} - ${job['salary_max']}

APPLICANT INFORMATION:
- Name: ${applicant['full_name']}
- Email: ${applicant['email']}

RESUME CONTENT:
$resumeContent

Please provide a comprehensive analysis in the following JSON format:
{
  "overall_score": 8.5,
  "skills_match_score": 8.0,
  "experience_match_score": 9.0,
  "education_match_score": 7.5,
  "cultural_fit_score": 8.0,
  "skills_analysis": {
    "matched_skills": ["React", "JavaScript", "Node.js"],
    "missing_skills": ["TypeScript", "AWS"],
    "skill_gaps": "Missing cloud experience",
    "skill_strength": "Strong frontend development skills"
  },
  "experience_analysis": {
    "relevant_experience": "3 years of frontend development",
    "experience_level_match": "Meets requirements",
    "career_progression": "Good progression from junior to mid-level",
    "leadership_experience": "Some team leadership experience"
  },
  "education_analysis": {
    "education_level": "Bachelor's in Computer Science",
    "relevance": "Highly relevant",
    "additional_certifications": ["React Certification"],
    "academic_strength": "Strong technical foundation"
  },
  "cultural_fit_analysis": {
    "communication_style": "Professional and clear",
    "team_collaboration": "Shows evidence of teamwork",
    "problem_solving": "Demonstrates analytical thinking",
    "adaptability": "Shows flexibility in technology stack"
  },
  "strengths": [
    "Strong technical skills",
    "Relevant work experience",
    "Good project portfolio",
    "Clear communication"
  ],
  "concerns": [
    "Limited backend experience",
    "No cloud platform experience"
  ],
  "recommendation": "strong_match",
  "reasoning": "Candidate has strong frontend skills and relevant experience, but lacks some backend and cloud skills mentioned in job requirements.",
  "interview_questions": [
    "Can you describe your experience with backend technologies?",
    "How would you approach learning cloud technologies?",
    "Tell me about a challenging project you've worked on"
  ],
  "salary_expectation_match": true,
  "availability_match": true,
  "hiring_recommendation": "Proceed to interview",
  "risk_assessment": "Low risk - strong candidate with minor skill gaps"
}

Scoring Guidelines:
- overall_score: 0-10 (10 = perfect match)
- Recommendation: "strong_match", "good_match", "weak_match", "not_suitable"
- Be objective and focus on job requirements
- Consider both technical skills and soft skills
- Look for career progression and growth potential
- Assess cultural fit and team compatibility
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final responseText = response.text ?? '{}';
      debugPrint('🔍 AI Response length: ${responseText.length}');
      debugPrint('🔍 AI Response: $responseText');
      
      // Parse JSON response
      final jsonStart = responseText.indexOf('{');
      final jsonEnd = responseText.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        debugPrint('❌ No valid JSON found in response');
        throw Exception('No valid JSON found in response');
      }
      
      final jsonString = responseText.substring(jsonStart, jsonEnd);
      debugPrint('🔍 Extracted JSON: $jsonString');
      
      // Parse JSON properly using dart:convert
      final analysis = jsonDecode(jsonString) as Map<String, dynamic>;
      
      debugPrint('🔍 Parsed analysis: $analysis');
      
      // Convert string values to proper types
      return {
        'overall_score': double.tryParse(analysis['overall_score']?.toString() ?? '0') ?? 0.0,
        'skills_match_score': double.tryParse(analysis['skills_match_score']?.toString() ?? '0') ?? 0.0,
        'experience_match_score': double.tryParse(analysis['experience_match_score']?.toString() ?? '0') ?? 0.0,
        'education_match_score': double.tryParse(analysis['education_match_score']?.toString() ?? '0') ?? 0.0,
        'cultural_fit_score': double.tryParse(analysis['cultural_fit_score']?.toString() ?? '0') ?? 0.0,
        'skills_analysis': analysis['skills_analysis'] ?? {},
        'experience_analysis': analysis['experience_analysis'] ?? {},
        'education_analysis': analysis['education_analysis'] ?? {},
        'cultural_fit_analysis': analysis['cultural_fit_analysis'] ?? {},
        'strengths': _parseStringArray(analysis['strengths']?.toString() ?? ''),
        'concerns': _parseStringArray(analysis['concerns']?.toString() ?? ''),
        'recommendation': analysis['recommendation']?.toString() ?? 'unknown',
        'reasoning': analysis['reasoning']?.toString() ?? 'No reasoning provided',
        'interview_questions': _parseStringArray(analysis['interview_questions']?.toString() ?? ''),
        'salary_expectation_match': analysis['salary_expectation_match']?.toString() == 'true',
        'availability_match': analysis['availability_match']?.toString() == 'true',
        'hiring_recommendation': analysis['hiring_recommendation']?.toString() ?? 'Review required',
        'risk_assessment': analysis['risk_assessment']?.toString() ?? 'Standard risk',
      };
    } catch (e) {
      debugPrint('❌ Error with Gemini API: $e');
      return {
        'overall_score': 0.0,
        'skills_match_score': 0.0,
        'experience_match_score': 0.0,
        'education_match_score': 0.0,
        'cultural_fit_score': 0.0,
        'skills_analysis': {},
        'experience_analysis': {},
        'education_analysis': {},
        'cultural_fit_analysis': {},
        'strengths': [],
        'concerns': ['Error processing resume'],
        'recommendation': 'error',
        'reasoning': 'Error processing resume: $e',
        'interview_questions': [],
        'salary_expectation_match': false,
        'availability_match': false,
        'hiring_recommendation': 'Manual review required',
        'risk_assessment': 'Unable to assess',
      };
    }
  }

  static List<String> _parseStringArray(String input) {
    if (input.isEmpty) return [];
    
    // Try to parse as JSON array first
    try {
      final cleaned = input.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      return cleaned.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [input];
    }
  }

  static Future<Map<String, dynamic>?> _storeErrorResult(
    String applicationId,
    String errorMessage,
  ) async {
    try {
      // Get job_id from application
      final application = await _supabase
          .from('job_applications')
          .select('job_id, applicant_id')
          .eq('id', applicationId)
          .single();

      final response = await _supabase
          .from('ai_screening_results')
          .insert({
            'application_id': applicationId,
            'job_id': application['job_id'],
            'applicant_id': application['applicant_id'],
            'overall_score': 0.0,
            'skills_match_score': 0.0,
            'experience_match_score': 0.0,
            'education_match_score': 0.0,
            'skills_analysis': {},
            'experience_analysis': {},
            'education_analysis': {},
            'strengths': [],
            'concerns': ['Resume content not available for analysis'],
            'reasoning': errorMessage,
            'ai_model_version': 'error',
            'processing_status': 'error',
          })
          .select()
          .single();

      debugPrint('✅ Error result stored successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Error storing error result: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _storeScreeningResult(
    String applicationId,
    Map<String, dynamic> analysis,
  ) async {
    try {
      // Get job_id from application
      final application = await _supabase
          .from('job_applications')
          .select('job_id, applicant_id')
          .eq('id', applicationId)
          .single();

      final response = await _supabase
          .from('ai_screening_results')
          .insert({
            'application_id': applicationId,
            'job_id': application['job_id'],
            'applicant_id': application['applicant_id'],
            'overall_score': analysis['overall_score'],
            'skills_match_score': analysis['skills_match_score'],
            'experience_match_score': analysis['experience_match_score'],
            'education_match_score': analysis['education_match_score'],
            'skills_analysis': analysis['skills_analysis'],
            'experience_analysis': analysis['experience_analysis'],
            'education_analysis': analysis['education_analysis'],
            'strengths': analysis['strengths'],
            'concerns': analysis['concerns'],
            'reasoning': analysis['reasoning'],
            'ai_model_version': _currentModelName,
            'processing_status': 'completed',
          })
          .select()
          .single();

      debugPrint('✅ AI screening result stored successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Error storing screening result: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getScreeningResults(String jobId) async {
    try {
      final response = await _supabase
          .from('ai_screening_results')
          .select('''
            *,
            job_applications (
              *,
              profiles (*)
            )
          ''')
          .eq('job_id', jobId)
          .order('overall_score', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching screening results: $e');
      return [];
    }
  }

  static Future<bool> hasBeenScreened(String applicationId) async {
    try {
      final response = await _supabase
          .from('ai_screening_results')
          .select('id')
          .eq('application_id', applicationId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking screening status: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> screenAllApplications(String jobId) async {
    try {
      // Get all applications for the job
      final applications = await _supabase
          .from('job_applications')
          .select('id')
          .eq('job_id', jobId);

      List<Map<String, dynamic>> results = [];
      
      for (final application in applications) {
        final alreadyScreened = await hasBeenScreened(application['id']);
        if (!alreadyScreened) {
          final result = await screenResume(applicationId: application['id']);
          if (result != null) {
            results.add(result);
          }
          
          // Add delay to respect API rate limits (5 requests per minute)
          await Future.delayed(Duration(seconds: 12));
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('❌ Error screening all applications: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getScreeningCriteria(String jobId) async {
    try {
      final response = await _supabase
          .from('ai_screening_criteria')
          .select('*')
          .eq('job_id', jobId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching screening criteria: $e');
      return null;
    }
  }

  static Future<bool> setScreeningCriteria({
    required String jobId,
    required String companyId,
    List<String>? requiredSkills,
    List<String>? preferredSkills,
    int? minExperienceYears,
    String? requiredEducationLevel,
    List<String>? requiredCertifications,
    double? autoScreenThreshold,
  }) async {
    try {
      await _supabase
          .from('ai_screening_criteria')
          .upsert({
            'job_id': jobId,
            'company_id': companyId,
            'required_skills': requiredSkills,
            'preferred_skills': preferredSkills,
            'min_experience_years': minExperienceYears,
            'required_education_level': requiredEducationLevel,
            'required_certifications': requiredCertifications,
            'auto_screen_threshold': autoScreenThreshold ?? 7.0,
          });
      
      return true;
    } catch (e) {
      debugPrint('❌ Error setting screening criteria: $e');
      return false;
    }
  }

  // Function to list available models (for debugging)
  static Future<List<String>> listAvailableModels() async {
    try {
      // This is a workaround since the Flutter package doesn't have listModels
      // We'll try each model and see which ones work
      final modelsToTest = [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro',
        'gemini-pro-vision',
        'gemini-1.0-pro',
        'text-bison-001',
        'chat-bison-001',
      ];
      
      final availableModels = <String>[];
      
      for (final modelName in modelsToTest) {
        try {
          if (AppConfig.geminiApiKey.isEmpty) {
            debugPrint('❌ API key is empty, cannot test models');
            break;
          }
          
          final model = GenerativeModel(
            model: modelName,
            apiKey: AppConfig.geminiApiKey,
          );
          
          // Test with a simple request
          final testContent = [Content.text('test')];
          final testResponse = await model.generateContent(testContent);
          
          if (testResponse.text != null) {
            availableModels.add(modelName);
            debugPrint('✅ Model $modelName is available');
          }
        } catch (e) {
          debugPrint('❌ Model $modelName not available: $e');
        }
      }
      
      return availableModels;
    } catch (e) {
      debugPrint('❌ Error listing models: $e');
      return [];
    }
  }

  // Simple test function to verify AI is working
  static Future<bool> testAIConnection() async {
    try {
      if (!_isInitialized) {
        await initialize();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!_isInitialized) {
        debugPrint('❌ AI service not initialized');
        return false;
      }
      
      // Test with a simple prompt
      final testPrompt = 'Hello, respond with "AI working"';
      final content = [Content.text(testPrompt)];
      final response = await _model.generateContent(content);
      
      if (response.text != null && response.text!.isNotEmpty) {
        debugPrint('✅ AI connection test successful');
        debugPrint('Response: ${response.text}');
        return true;
      } else {
        debugPrint('❌ AI connection test failed - no response');
        return false;
      }
    } catch (e) {
      debugPrint('❌ AI connection test error: $e');
      return false;
    }
  }

  // Simple test to verify API key and basic functionality
  static Future<Map<String, dynamic>> testBasicConnection() async {
    final result = <String, dynamic>{};
    
    try {
      // Check API key
      result['api_key_empty'] = AppConfig.geminiApiKey.isEmpty;
      result['api_key_length'] = AppConfig.geminiApiKey.length;
      
      if (AppConfig.geminiApiKey.isEmpty) {
        result['error'] = 'API key is empty';
        return result;
      }
      
      // List available models first
      final availableModels = await listAvailableModels();
      result['available_models'] = availableModels;
      
      if (availableModels.isNotEmpty) {
        // Try to initialize with the first available model
        final model = GenerativeModel(
          model: availableModels.first,
          apiKey: AppConfig.geminiApiKey,
        );
        
        // Test with simple prompt
        final content = [Content.text('Hello, respond with "Working"')];
        final response = await model.generateContent(content);
        
        result['model_initialized'] = true;
        result['response_received'] = response.text != null;
        result['response_text'] = response.text ?? 'null';
        result['success'] = response.text != null && response.text!.isNotEmpty;
      } else {
        result['error'] = 'No models available';
        result['success'] = false;
      }
      
    } catch (e) {
      result['error'] = e.toString();
      result['error_type'] = e.runtimeType.toString();
      result['success'] = false;
    }
    
    return result;
  }

  // Manual trigger for AI screening (for testing)
  static Future<Map<String, dynamic>?> manualTriggerScreening(String applicationId) async {
    try {
      debugPrint('🔄 Manually triggering AI screening for application: $applicationId');
      
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!_isInitialized) {
        debugPrint('❌ AI service not initialized for manual trigger');
        return null;
      }
      
      // Test AI connection first
      final connectionTest = await testAIConnection();
      if (!connectionTest) {
        debugPrint('❌ AI connection test failed');
        return null;
      }
      
      // Proceed with screening
      final result = await screenResume(applicationId: applicationId);
      
      if (result != null) {
        debugPrint('✅ Manual AI screening completed successfully');
        
        // Update application status
        await _supabase
            .from('job_applications')
            .update({'ai_screening_triggered': true})
            .eq('id', applicationId);
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Error in manual AI screening: $e');
      return null;
    }
  }

  // Debug function to test resume content extraction
  static Future<void> debugResumeExtraction(String applicationId) async {
    try {
      debugPrint('🔍 Debug: Testing resume extraction for application: $applicationId');
      
      final application = await _getApplicationDetails(applicationId);
      if (application == null) {
        debugPrint('❌ Application not found');
        return;
      }
      
      debugPrint('🔍 Application found: ${application['id']}');
      debugPrint('🔍 Applicant ID: ${application['applicant_id']}');
      
      final applicantProfile = await _getApplicantProfile(application['applicant_id']);
      debugPrint('🔍 Applicant profile found: ${applicantProfile != null}');
      
      if (applicantProfile != null) {
        debugPrint('🔍 Profile keys: ${applicantProfile.keys.toList()}');
        debugPrint('🔍 Skills: ${applicantProfile['skills']}');
        debugPrint('🔍 Professional summary: ${applicantProfile['professional_summary']}');
        debugPrint('🔍 Years of experience: ${applicantProfile['years_of_experience']}');
        
        final structuredData = _buildStructuredResumeData(applicantProfile);
        debugPrint('🔍 Structured data length: ${structuredData.length}');
        debugPrint('🔍 Structured data preview: ${structuredData.substring(0, structuredData.length > 500 ? 500 : structuredData.length)}...');
      }
      
      final resumeContent = await _extractResumeContent(applicationId);
      debugPrint('🔍 Final resume content length: ${resumeContent?.length ?? 0}');
      debugPrint('🔍 Final resume content preview: ${resumeContent?.substring(0, resumeContent.length > 500 ? 500 : resumeContent.length) ?? 'null'}...');
      
    } catch (e) {
      debugPrint('❌ Error in debug resume extraction: $e');
    }
  }

  // Simple test to verify database connection and data
  static Future<void> testDatabaseConnection() async {
    try {
      debugPrint('🔍 Testing database connection...');
      
      // Test 1: Get latest application
      final latestApp = await _supabase
          .from('job_applications')
          .select('id, applicant_id')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      debugPrint('🔍 Latest application: ${latestApp != null ? 'Found' : 'Not found'}');
      if (latestApp != null) {
        debugPrint('🔍 Latest app ID: ${latestApp['id']}');
        debugPrint('🔍 Latest app applicant_id: ${latestApp['applicant_id']}');
        
        // Test 2: Get applicant profile
        final profile = await _supabase
            .from('applicant_profile')
            .select('user_id, full_name, skills')
            .eq('user_id', latestApp['applicant_id'])
            .maybeSingle();
        
        debugPrint('🔍 Profile lookup result: ${profile != null ? 'Found' : 'Not found'}');
        if (profile != null) {
          debugPrint('🔍 Profile name: ${profile['full_name']}');
          debugPrint('🔍 Profile skills: ${profile['skills']}');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Database connection test failed: $e');
    }
  }
}

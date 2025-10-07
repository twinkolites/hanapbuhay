import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/ai_screening_service.dart';

class AIInsightsPage extends StatefulWidget {
  final Map<String, dynamic>? job; // Optional job parameter
  
  const AIInsightsPage({super.key, this.job});

  @override
  State<AIInsightsPage> createState() => _AIInsightsPageState();
}

class _AIInsightsPageState extends State<AIInsightsPage> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allApplications = [];
  List<Map<String, dynamic>> _aiResults = [];
  bool _isLoading = true;
  bool _isGeneratingInsights = false;
  Map<String, dynamic>? _insightsSummary;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      List<Map<String, dynamic>> allApplications = [];
      List<Map<String, dynamic>> allAIResults = [];

      if (widget.job != null) {
        // Focus on specific job
        final applications = await JobService.getJobApplications(widget.job!['id']);
        for (final application in applications) {
          // Add job info to each application
          application['job'] = widget.job;
          allApplications.add(application);
        }
        
        final results = await AIScreeningService.getScreeningResults(widget.job!['id']);
        allAIResults.addAll(results);
      } else {
        // Get all jobs for the company
        final company = await JobService.getUserCompany(user.id);
        if (company == null) return;

        final jobs = await JobService.getJobsByCompany(company['id']);
        
        // Get applications for each job
        for (final job in jobs) {
          final applications = await JobService.getJobApplications(job['id']);
          for (final application in applications) {
            // Add job info to each application
            application['job'] = job;
            allApplications.add(application);
          }
        }

        // Get AI results for all jobs
        for (final job in jobs) {
          final results = await AIScreeningService.getScreeningResults(job['id']);
          allAIResults.addAll(results);
        }
      }

      setState(() {
        _allApplications = allApplications;
        _aiResults = allAIResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _generateInsights() async {
    setState(() {
      _isGeneratingInsights = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      int totalProcessed = 0;

      if (widget.job != null) {
        // Focus on specific job
        final results = await AIScreeningService.screenAllApplications(widget.job!['id']);
        totalProcessed = results.length;
      } else {
        // Get all jobs for the company
        final company = await JobService.getUserCompany(user.id);
        if (company == null) return;

        final jobs = await JobService.getJobsByCompany(company['id']);
        
        for (final job in jobs) {
          final results = await AIScreeningService.screenAllApplications(job['id']);
          totalProcessed += results.length;
        }
      }
      
      // Reload data after screening
      await _loadData();
      
      // Generate insights summary
      _generateInsightsSummary();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI insights generated! Processed $totalProcessed applications.'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating insights: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingInsights = false;
      });
    }
  }

  void _generateInsightsSummary() {
    if (_aiResults.isEmpty) return;

    // Calculate insights
    final totalApplications = _allApplications.length;
    final screenedApplications = _aiResults.length;
    final highScoreApplications = _aiResults.where((result) => (result['overall_score'] ?? 0) >= 8.0).length;
    final mediumScoreApplications = _aiResults.where((result) => (result['overall_score'] ?? 0) >= 6.0 && (result['overall_score'] ?? 0) < 8.0).length;
    final lowScoreApplications = _aiResults.where((result) => (result['overall_score'] ?? 0) < 6.0).length;
    
    final averageScore = _aiResults.isNotEmpty 
        ? _aiResults.map((r) => (r['overall_score'] as double?) ?? 0.0).reduce((a, b) => a + b) / _aiResults.length
        : 0.0;

    // Get top skills
    final allSkills = <String, int>{};
    for (final result in _aiResults) {
      if (result['skills_analysis'] != null) {
        final skills = result['skills_analysis'] as Map<String, dynamic>;
        skills.forEach((skill, value) {
          allSkills[skill] = (allSkills[skill] ?? 0) + 1;
        });
      }
    }
    
    final topSkills = allSkills.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5);

    setState(() {
      _insightsSummary = {
        'totalApplications': totalApplications,
        'screenedApplications': screenedApplications,
        'highScoreApplications': highScoreApplications,
        'mediumScoreApplications': mediumScoreApplications,
        'lowScoreApplications': lowScoreApplications,
        'averageScore': averageScore,
        'topSkills': topSkills.map((e) => e.key).toList(),
        'screeningRate': totalApplications > 0 ? (screenedApplications / totalApplications * 100) : 0.0,
      };
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        title: Text(
          widget.job != null 
              ? 'AI Resume Screening - ${widget.job!['title']}'
              : 'AI Resume Screening',
          style: const TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: darkTeal,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(
              Icons.refresh,
              color: mediumSeaGreen,
              size: 24,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Generate Insights Button
              _buildGenerateInsightsButton(),
              
              // Insights Summary
              if (_insightsSummary != null) ...[
                _buildInsightsSummary(),
                const SizedBox(height: 20),
              ],
              
              // Top Candidates
              if (_aiResults.isNotEmpty) ...[
                _buildTopCandidates(),
                const SizedBox(height: 20),
              ],
              
              // Skills Analysis
              if (_insightsSummary != null && (_insightsSummary!['topSkills'] as List).isNotEmpty) ...[
                _buildSkillsAnalysis(),
                const SizedBox(height: 20),
              ],
              
              // All Applications with AI Scores
              _buildApplicationsWithScores(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateInsightsButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: _isGeneratingInsights ? null : _generateInsights,
        icon: _isGeneratingInsights 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome, size: 24),
        label: Text(
          _isGeneratingInsights ? 'Generating Insights...' : 'Generate AI Insights',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildInsightsSummary() {
    final summary = _insightsSummary!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: mediumSeaGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Insights Summary',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Key Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Applications',
                  '${summary['totalApplications']}',
                  Icons.people,
                  darkTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Screened',
                  '${summary['screenedApplications']}',
                  Icons.psychology,
                  Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'High Score (8+)',
                  '${summary['highScoreApplications']}',
                  Icons.star,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Average Score',
                  '${summary['averageScore'].toStringAsFixed(1)}/10',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Screening Rate
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: mediumSeaGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Screening Rate: ${summary['screeningRate'].toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopCandidates() {
    // Sort by AI score
    final sortedResults = List<Map<String, dynamic>>.from(_aiResults)
      ..sort((a, b) => (b['overall_score'] as double).compareTo(a['overall_score'] as double));
    
    final topCandidates = sortedResults.take(5).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Top Candidates',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...topCandidates.asMap().entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            final application = _allApplications.firstWhere(
              (app) => app['id'] == result['application_id'],
              orElse: () => <String, dynamic>{},
            );
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paleGreen,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _getScoreColor(result['overall_score']),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Candidate info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getApplicantName(application),
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          application['job']?['title'] ?? 'Unknown Job',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScoreColor(result['overall_score']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${result['overall_score'] ?? 0}/10',
                      style: TextStyle(
                        color: _getScoreColor(result['overall_score']),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkillsAnalysis() {
    final topSkills = _insightsSummary!['topSkills'] as List<String>;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.purple,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Top Skills in Applications',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...topSkills.map((skill) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.purple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  skill,
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildApplicationsWithScores() {
    if (_aiResults.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: darkTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No AI Results Yet',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate AI insights to see detailed analysis of your applications',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Sort by AI score
    final sortedResults = List<Map<String, dynamic>>.from(_aiResults)
      ..sort((a, b) => (b['overall_score'] as double).compareTo(a['overall_score'] as double));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                color: mediumSeaGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All Applications (Sorted by AI Score)',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...sortedResults.map((result) {
            final application = _allApplications.firstWhere(
              (app) => app['id'] == result['application_id'],
              orElse: () => <String, dynamic>{},
            );
            
            // Check if this is an error result
            final isError = result['processing_status'] == 'error';
            
            return GestureDetector(
              onTap: isError ? null : () => _showDetailedAIAnalysis(result, application),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isError ? Colors.red.withValues(alpha: 0.1) : lightMint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isError ? Colors.red.withValues(alpha: 0.3) : paleGreen,
                    width: 1,
                  ),
                ),
                child: Row(
                children: [
                  // Score indicator or error icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isError ? Colors.red : _getScoreColor(result['overall_score']),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isError 
                        ? const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            '${result['overall_score'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Application info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getApplicantName(application),
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          application['job']?['title'] ?? 'Unknown Job',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        if (isError) ...[
                          Text(
                            '⚠️ Resume PDF not available',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Please ask applicant to upload resume',
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                        ] else ...[
                          Text(
                            _getRecommendationText(result['recommendation']),
                            style: TextStyle(
                              color: _getScoreColor(result['overall_score']),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ));
            }).toList(),
        ],
      ),
    );
  }

  Color _getScoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 8.0) return Colors.green;
    if (score >= 6.0) return Colors.orange;
    return Colors.red;
  }

  String _getRecommendationText(String? recommendation) {
    if (recommendation == null) return 'No Recommendation';
    
    switch (recommendation) {
      case 'strong_match': return 'Strong Match';
      case 'good_match': return 'Good Match';
      case 'weak_match': return 'Weak Match';
      case 'not_suitable': return 'Not Suitable';
      default: return 'Unknown';
    }
  }

  String _getApplicantName(Map<String, dynamic> application) {
    final profiles = application['profiles'];
    if (profiles == null) return 'Unknown Applicant';
    
    final fullName = profiles['full_name']?.toString().trim() ?? '';
    
    if (fullName.isEmpty) {
      return 'Unknown Applicant';
    }
    
    return fullName;
  }

  // Show detailed AI analysis
  void _showDetailedAIAnalysis(Map<String, dynamic> aiResult, Map<String, dynamic> application) {
    final isError = aiResult['processing_status'] == 'error';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isError 
                        ? Colors.red.withValues(alpha: 0.1)
                        : mediumSeaGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isError ? Icons.error_outline : Icons.psychology,
                      color: isError ? Colors.red : mediumSeaGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isError ? 'Analysis Error' : 'AI Analysis Report',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getApplicantName(application),
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isError 
                        ? Colors.red.withValues(alpha: 0.1)
                        : _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isError ? 'Error' : '${aiResult['overall_score']}/10',
                      style: TextStyle(
                        color: isError ? Colors.red : _getScoreColor(aiResult['overall_score']),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isError) ...[
                      // Error content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Resume Analysis Failed',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The AI screening could not analyze this application because:',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint('Resume PDF file is not available or accessible'),
                            _buildBulletPoint('Resume URL points to a placeholder or invalid file'),
                            _buildBulletPoint('No resume content was provided by the applicant'),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recommended Actions:',
                                    style: TextStyle(
                                      color: darkTeal,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBulletPoint('Contact the applicant to request a proper resume upload'),
                                  _buildBulletPoint('Ask them to upload their resume in PDF format'),
                                  _buildBulletPoint('Verify the resume file is accessible and not corrupted'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error Details:',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              aiResult['reasoning'] ?? 'No resume content available for analysis',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Normal AI analysis content
                      // Overall Assessment
                      _buildAnalysisSection(
                        'Overall Assessment',
                        Icons.assessment,
                        [
                          _buildInfoRow('Overall Score', '${aiResult['overall_score']}/10'),
                          _buildInfoRow('Recommendation', _getRecommendationText(aiResult['recommendation'])),
                          _buildInfoRow('Hiring Recommendation', aiResult['hiring_recommendation'] ?? 'Review Required'),
                          _buildInfoRow('Risk Assessment', aiResult['risk_assessment'] ?? 'Standard Risk'),
                        ],
                      ),
                      
                      // Detailed Scores
                      _buildAnalysisSection(
                        'Detailed Scores',
                        Icons.bar_chart,
                        [
                          _buildInfoRow('Skills Match', '${aiResult['skills_match_score'] ?? 0}/10'),
                          _buildInfoRow('Experience Match', '${aiResult['experience_match_score'] ?? 0}/10'),
                          _buildInfoRow('Education Match', '${aiResult['education_match_score'] ?? 0}/10'),
                          _buildInfoRow('Cultural Fit', '${aiResult['cultural_fit_score'] ?? 0}/10'),
                        ],
                      ),
                      
                      // Strengths
                      if (aiResult['strengths'] != null && (aiResult['strengths'] as List).isNotEmpty)
                        _buildAnalysisSection(
                          'Strengths',
                          Icons.thumb_up,
                          (aiResult['strengths'] as List).map((strength) => 
                            _buildBulletPoint(strength.toString())
                          ).toList(),
                        ),
                      
                      // Concerns
                      if (aiResult['concerns'] != null && (aiResult['concerns'] as List).isNotEmpty)
                        _buildAnalysisSection(
                          'Areas of Concern',
                          Icons.warning,
                          (aiResult['concerns'] as List).map((concern) => 
                            _buildBulletPoint(concern.toString())
                          ).toList(),
                        ),
                      
                      // Interview Questions
                      if (aiResult['interview_questions'] != null && (aiResult['interview_questions'] as List).isNotEmpty)
                        _buildAnalysisSection(
                          'Suggested Interview Questions',
                          Icons.question_answer,
                          (aiResult['interview_questions'] as List).map((question) => 
                            _buildBulletPoint(question.toString())
                          ).toList(),
                        ),
                      
                      // Analysis Reasoning
                      if (aiResult['reasoning'] != null && aiResult['reasoning'].toString().isNotEmpty)
                        _buildAnalysisSection(
                          'Analysis Reasoning',
                          Icons.lightbulb_outline,
                          [
                            Text(
                              aiResult['reasoning'],
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.8),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: mediumSeaGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

// Color palette
const Color lightMint = Color(0xFFEAF9E7);
const Color paleGreen = Color(0xFFC0E6BA);
const Color mediumSeaGreen = Color(0xFF4CA771);
const Color darkTeal = Color(0xFF013237);

class ApplicationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> application;
  final Map<String, dynamic>? aiResult;

  const ApplicationDetailsSheet({
    super.key,
    required this.application,
    this.aiResult,
  });

  @override
  Widget build(BuildContext context) {
    final applicant = application['profiles'] ?? {};
    final aiResultData = aiResult ?? _getAIResult(application['id']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.05),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(
                  color: paleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                        // Enhanced applicant avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        mediumSeaGreen.withValues(alpha: 0.1),
                        paleGreen.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: mediumSeaGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: applicant['avatar_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            applicant['avatar_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildAvatarPlaceholder(_getApplicantName(application));
                            },
                          ),
                        )
                      : _buildAvatarPlaceholder(_getApplicantName(application)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getApplicantName(application),
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Application Details',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Enhanced status with icon
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(application['status']).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(application['status']).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(application['status']),
                              color: _getStatusColor(application['status']),
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatStatusDisplay(application['status']),
                              style: TextStyle(
                                color: _getStatusColor(application['status']),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Enhanced Content with tabs
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  // Custom Tab Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: lightMint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: paleGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: mediumSeaGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: darkTeal.withValues(alpha: 0.7),
                      labelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Cover Letter'),
                        Tab(text: 'AI Analysis'),
                      ],
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Overview Tab
                        _buildOverviewTab(application, applicant),
                        // Cover Letter Tab
                        _buildCoverLetterTab(application),
                        // AI Analysis Tab
                        _buildAIAnalysisTab(aiResultData),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab Content Methods
  Widget _buildOverviewTab(Map<String, dynamic> application, Map<String, dynamic> applicant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information Card
          _buildInfoCard(
            'Contact Information',
            Icons.contact_phone,
            mediumSeaGreen,
            [
              _buildInfoRow('Email', applicant['email'] ?? 'N/A', Icons.email),
              _buildInfoRow('Phone', applicant['phone'] ?? 'N/A', Icons.phone),
              _buildInfoRow('Location', applicant['location'] ?? 'N/A', Icons.location_on),
            ],
          ),

          const SizedBox(height: 20),

          // Application Details Card
          _buildInfoCard(
            'Application Details',
            Icons.assignment,
            Colors.blue,
            [
              _buildInfoRow('Applied Date', _formatDate(application['created_at']), Icons.calendar_today),
              _buildInfoRow('Source', application['application_source'] ?? 'direct', Icons.source),
              _buildInfoRow('Profile Completeness', '${application['profile_completeness_score'] ?? 0}%', Icons.person_outline),
              if (application['application_notes'] != null)
                _buildInfoRow('Notes', application['application_notes'], Icons.note),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverLetterTab(Map<String, dynamic> application) {
    final coverLetter = application['cover_letter']?.toString() ?? '';

    if (coverLetter.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: darkTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Cover Letter',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This candidate did not provide a cover letter',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: paleGreen.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Letter Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description,
                    color: mediumSeaGreen,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Cover Letter',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Enhanced Cover Letter Content with better formatting
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightMint.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: SelectableText(
                coverLetter,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.4, // Better line spacing for readability
                  letterSpacing: 0.2, // Improved letter spacing
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cover Letter Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: mediumSeaGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cover Letter Statistics',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${coverLetter.length} characters',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisTab(Map<String, dynamic>? aiResult) {
    if (aiResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: darkTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No AI Analysis',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI analysis has not been performed yet',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // AI Score Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.psychology,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Analysis Score',
                            style: TextStyle(
                              color: darkTeal,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Overall candidate assessment',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${aiResult['overall_score'] ?? 0}/10',
                        style: TextStyle(
                          color: _getScoreColor(aiResult['overall_score']),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Recommendation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommendation',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRecommendationText(aiResult['recommendation']),
                        style: TextStyle(
                          color: _getScoreColor(aiResult['overall_score']),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData? icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: mediumSeaGreen,
                size: 12,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 11,
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

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: mediumSeaGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper methods
  String _getApplicantName(Map<String, dynamic> application) {
    final fullName = application['profiles']?['full_name']?.toString().trim() ?? '';
    return fullName.isEmpty ? 'Unknown Applicant' : fullName;
  }

  String _formatStatusDisplay(String status) {
    switch (status) {
      case 'applied':
        return 'Applied';
      case 'under_review':
        return 'Under Review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interview':
        return 'Interview';
      case 'hired':
        return 'Hired';
      case 'rejected':
        return 'Rejected';
      default:
        return status.split('_').map((word) =>
            word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applied':
        return mediumSeaGreen;
      case 'under_review':
        return Colors.orange;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.purple;
      case 'hired':
        return mediumSeaGreen;
      case 'rejected':
        return Colors.red;
      default:
        return darkTeal;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'applied':
        return Icons.send;
      case 'under_review':
        return Icons.visibility;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.event;
      case 'hired':
        return Icons.check_circle;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.work;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
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
      case 'strong_match':
        return 'Strong Match';
      case 'good_match':
        return 'Good Match';
      case 'weak_match':
        return 'Weak Match';
      case 'not_suitable':
        return 'Not Suitable';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic>? _getAIResult(String applicationId) {
    // This would need to be passed from the parent or fetched here
    // For now, returning null as placeholder
    return null;
  }
}

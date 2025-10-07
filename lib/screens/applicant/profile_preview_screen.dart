import 'package:flutter/material.dart';

class ProfilePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const ProfilePreviewScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header Card
            _buildProfileHeader(),
            const SizedBox(height: 20),
            
            // Professional Summary
            _buildSectionCard(
              'Professional Summary',
              Icons.description_outlined,
              _buildProfessionalSummary(),
            ),
            const SizedBox(height: 20),
            
            // Work Experience
            _buildSectionCard(
              'Work Experience',
              Icons.work_outline,
              _buildWorkExperience(),
            ),
            const SizedBox(height: 20),
            
            // Education
            _buildSectionCard(
              'Education',
              Icons.school_outlined,
              _buildEducation(),
            ),
            const SizedBox(height: 20),
            
            // Skills
            _buildSectionCard(
              'Skills',
              Icons.star_outline,
              _buildSkills(),
            ),
            const SizedBox(height: 20),
            
            // Certifications
            _buildSectionCard(
              'Certifications',
              Icons.verified_outlined,
              _buildCertifications(),
            ),
            const SizedBox(height: 20),
            
            // Languages
            _buildSectionCard(
              'Languages',
              Icons.language_outlined,
              _buildLanguages(),
            ),
            const SizedBox(height: 20),
            
            // Contact & Links
            _buildSectionCard(
              'Contact & Links',
              Icons.contact_page_outlined,
              _buildContactLinks(),
            ),
            const SizedBox(height: 20),
            
            // Job Preferences
            _buildSectionCard(
              'Job Preferences',
              Icons.settings_outlined,
              _buildJobPreferences(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Profile Preview',
        style: TextStyle(
          color: Color(0xFF2C3E50),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Color(0xFF3498DB)),
          onPressed: () {
            // TODO: Implement share functionality
          },
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Color(0xFF3498DB)),
          onPressed: () {
            // TODO: Implement print functionality
          },
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Picture Placeholder
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: const Color(0xFF3498DB).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: Color(0xFF3498DB),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Name and Title
          Text(
            profile['full_name'] ?? 'Your Name',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            profile['current_position'] ?? 'Professional Title',
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFF7F8C8D),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (profile['current_company'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'at ${profile['current_company']}',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF95A5A6),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Contact Info Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              if (profile['location'] != null)
                _buildContactItem(Icons.location_on, profile['location']),
              if (profile['phone_number'] != null)
                _buildContactItem(Icons.phone, profile['phone_number']),
              if (profile['email'] != null)
                _buildContactItem(Icons.email, profile['email']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7F8C8D)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF3498DB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Section Content
          content,
        ],
      ),
    );
  }

  Widget _buildProfessionalSummary() {
    final summary = profile['professional_summary'];
    if (summary == null || summary.toString().isEmpty) {
      return const Text(
        'No professional summary provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Text(
      summary,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF2C3E50),
        height: 1.6,
      ),
    );
  }

  Widget _buildWorkExperience() {
    final experiences = profile['work_experience'] as List<dynamic>? ?? [];
    
    if (experiences.isEmpty) {
      return const Text(
        'No work experience provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Column(
      children: experiences.map<Widget>((exp) {
        final experience = exp as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      experience['title'] ?? 'Position Title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (experience['duration'] != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          experience['duration'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3498DB),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 4),
              
              Text(
                experience['company'] ?? 'Company Name',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              if (experience['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  experience['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEducation() {
    final education = profile['education'] as List<dynamic>? ?? [];
    
    if (education.isEmpty) {
      return const Text(
        'No education information provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Column(
      children: education.map<Widget>((edu) {
        final educationItem = edu as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                educationItem['degree'] ?? 'Degree',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                educationItem['institution'] ?? 'Institution',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              if (educationItem['year'] != null || educationItem['field'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (educationItem['year'] != null) ...[
                      Text(
                        educationItem['year'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF95A5A6),
                        ),
                      ),
                      if (educationItem['field'] != null) ...[
                        const Text(' • ', style: TextStyle(color: Color(0xFF95A5A6))),
                        Text(
                          educationItem['field'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF95A5A6),
                          ),
                        ),
                      ],
                    ] else if (educationItem['field'] != null)
                      Text(
                        educationItem['field'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF95A5A6),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkills() {
    final skills = profile['skills'] as List<dynamic>? ?? [];
    
    if (skills.isEmpty) {
      return const Text(
        'No skills provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map<Widget>((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF3498DB).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            skill.toString(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF3498DB),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCertifications() {
    final certifications = profile['certifications'] as List<dynamic>? ?? [];
    
    if (certifications.isEmpty) {
      return const Text(
        'No certifications provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Column(
      children: certifications.map<Widget>((cert) {
        final certification = cert as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Color(0xFF27AE60),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certification['name'] ?? 'Certification',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (certification['issuer'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        certification['issuer'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                    ],
                    if (certification['date'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        certification['date'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF95A5A6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLanguages() {
    final languages = profile['languages'] as List<dynamic>? ?? [];
    
    if (languages.isEmpty) {
      return const Text(
        'No languages provided.',
        style: TextStyle(
          color: Color(0xFF95A5A6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Column(
      children: languages.map<Widget>((lang) {
        final language = lang as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language['name'] ?? 'Language',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  language['proficiency'] ?? 'Proficiency',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE74C3C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContactLinks() {
    return Column(
      children: [
        if (profile['linkedin_url'] != null)
          _buildLinkItem(Icons.link, 'LinkedIn', profile['linkedin_url']),
        if (profile['portfolio_url'] != null)
          _buildLinkItem(Icons.web, 'Portfolio', profile['portfolio_url']),
        if (profile['github_url'] != null)
          _buildLinkItem(Icons.code, 'GitHub', profile['github_url']),
        if (profile['linkedin_url'] == null && 
            profile['portfolio_url'] == null && 
            profile['github_url'] == null)
          const Text(
            'No social links provided.',
            style: TextStyle(
              color: Color(0xFF95A5A6),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildLinkItem(IconData icon, String label, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3498DB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Flexible(
            child: Text(
              url,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile['availability'] != null) ...[
          _buildPreferenceItem('Availability', profile['availability']),
          const SizedBox(height: 12),
        ],
        if (profile['salary_expectation_min'] != null || profile['salary_expectation_max'] != null) ...[
          _buildPreferenceItem(
            'Salary Expectation',
            '₱${profile['salary_expectation_min'] ?? '0'} - ₱${profile['salary_expectation_max'] ?? '0'}',
          ),
        ],
        if (profile['availability'] == null && 
            profile['salary_expectation_min'] == null && 
            profile['salary_expectation_max'] == null)
          const Text(
            'No job preferences provided.',
            style: TextStyle(
              color: Color(0xFF95A5A6),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildPreferenceItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

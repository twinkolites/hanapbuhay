import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import '../../services/employer_registration_service.dart';

final supabase = Supabase.instance.client;

class EnhancedEditCompanyScreen extends StatefulWidget {
  final Map<String, dynamic>? company;
  final Map<String, dynamic>? companyDetails;
  
  const EnhancedEditCompanyScreen({
    super.key,
    this.company,
    this.companyDetails,
  });

  @override
  State<EnhancedEditCompanyScreen> createState() => _EnhancedEditCompanyScreenState();
}

class _EnhancedEditCompanyScreenState extends State<EnhancedEditCompanyScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Company basic info controllers
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _websiteController = TextEditingController();
  
  // Company details controllers
  final _businessAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _contactPersonPositionController = TextEditingController();
  final _contactPersonEmailController = TextEditingController();
  final _contactPersonPhoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _instagramController = TextEditingController();
  final _companyBenefitsController = TextEditingController();
  final _companyCultureController = TextEditingController();
  final _companyMissionController = TextEditingController();
  final _companyVisionController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  bool _isPublic = true;
  String? _logoUrl;
  String _selectedIndustry = '';
  String _selectedCompanySize = '';
  String _selectedBusinessType = '';
  int _currentPage = 0;
  
  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _pageAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  // Form options
  static const List<String> _industries = [
    'Technology & Software',
    'Healthcare & Medical',
    'Finance & Banking',
    'Education & Training',
    'Manufacturing',
    'Retail & E-commerce',
    'Construction & Engineering',
    'Marketing & Advertising',
    'Consulting',
    'Non-profit',
    'Government',
    'Other'
  ];

  static const List<String> _companySizes = [
    '1-10 employees',
    '11-50 employees',
    '51-200 employees',
    '201-500 employees',
    '501-1000 employees',
    '1000+ employees'
  ];

  static const List<String> _businessTypes = [
    'Sole Proprietorship',
    'Partnership',
    'Corporation',
    'LLC',
    'Non-profit',
    'Government',
    'Other'
  ];

  // Ensure dropdown current value exists in items; otherwise return empty
  String _normalizeDropdownValue(String? value, List<String> items) {
    if (value == null) return '';
    return items.contains(value) ? value : '';
  }

  // Map legacy/seeded values to the closest option in our dropdown lists
  String _mapIndustryAlias(String? value) {
    switch (value) {
      case 'Information Technology & Software Development':
        return 'Technology & Software';
      case 'Healthcare & Medical Services':
        return 'Healthcare & Medical';
      case 'Education Technology & Consulting':
        return 'Education & Training';
      case 'Environmental Technology & Sustainability':
        return 'Technology & Software'; // closest fit among defaults
      default:
        return value ?? '';
    }
  }

  String _mapCompanySizeAlias(String? value) {
    switch (value) {
      case '35-50 employees':
        return '11-50 employees';
      case '45-60 employees':
      case '60-80 employees':
      case '150-200 employees':
        return '51-200 employees';
      default:
        return value ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _initializeCompanyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageAnimationController.dispose();
    _pageController.dispose();
    
    // Dispose all controllers
    _nameController.dispose();
    _aboutController.dispose();
    _websiteController.dispose();
    _businessAddressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _contactPersonNameController.dispose();
    _contactPersonPositionController.dispose();
    _contactPersonEmailController.dispose();
    _contactPersonPhoneController.dispose();
    _linkedinController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _companyBenefitsController.dispose();
    _companyCultureController.dispose();
    _companyMissionController.dispose();
    _companyVisionController.dispose();
    
    super.dispose();
  }

  void _initializeCompanyData() {
    if (widget.company != null) {
      _nameController.text = widget.company!['name'] ?? '';
      _aboutController.text = widget.company!['about'] ?? '';
      _websiteController.text = widget.company!['profile_url'] ?? '';
      _isPublic = widget.company!['is_public'] ?? true;
      _logoUrl = widget.company!['logo_url'];
    }

    if (widget.companyDetails != null) {
      final details = widget.companyDetails!;
      _businessAddressController.text = details['business_address'] ?? '';
      _cityController.text = details['city'] ?? '';
      _provinceController.text = details['province'] ?? '';
      _postalCodeController.text = details['postal_code'] ?? '';
      _countryController.text = details['country'] ?? '';
      _contactPersonNameController.text = details['contact_person_name'] ?? '';
      _contactPersonPositionController.text = details['contact_person_position'] ?? '';
      _contactPersonEmailController.text = details['contact_person_email'] ?? '';
      _contactPersonPhoneController.text = details['contact_person_phone'] ?? '';
      _linkedinController.text = details['linkedin_url'] ?? '';
      _facebookController.text = details['facebook_url'] ?? '';
      _twitterController.text = details['twitter_url'] ?? '';
      _instagramController.text = details['instagram_url'] ?? '';
      _companyBenefitsController.text = (details['company_benefits'] as List?)?.join(', ') ?? '';
      _companyCultureController.text = details['company_culture'] ?? '';
      _companyMissionController.text = details['company_mission'] ?? '';
      _companyVisionController.text = details['company_vision'] ?? '';
      
      // Normalize dropdown selections to avoid invalid preset values
      _selectedIndustry = _normalizeDropdownValue(
        _mapIndustryAlias(details['industry']),
        _industries,
      );
      _selectedCompanySize = _normalizeDropdownValue(
        _mapCompanySizeAlias(details['company_size']),
        _companySizes,
      );
      _selectedBusinessType = _normalizeDropdownValue(details['business_type'], _businessTypes);
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare company data
      final companyData = {
        'name': _nameController.text.trim(),
        'about': _aboutController.text.trim(),
        'profile_url': _websiteController.text.trim(),
        'is_public': _isPublic,
        'logo_url': _logoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Prepare company details data
      final companyDetailsData = {
        'business_address': _businessAddressController.text.trim(),
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'country': _countryController.text.trim(),
        'industry': _selectedIndustry,
        'company_size': _selectedCompanySize,
        'business_type': _selectedBusinessType,
        'contact_person_name': _contactPersonNameController.text.trim(),
        'contact_person_position': _contactPersonPositionController.text.trim(),
        'contact_person_email': _contactPersonEmailController.text.trim(),
        'contact_person_phone': _contactPersonPhoneController.text.trim(),
        'website': _websiteController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'facebook_url': _facebookController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
        'company_benefits': _companyBenefitsController.text.trim().split(', ').where((e) => e.isNotEmpty).toList(),
        'company_culture': _companyCultureController.text.trim(),
        'company_mission': _companyMissionController.text.trim(),
        'company_vision': _companyVisionController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Use the enhanced update method
      final success = await EmployerRegistrationService.updateCompanyAndDetails(
        ownerId: user.id,
        companyId: widget.company?['id'],
        companyUpdates: companyData,
        detailsUpdates: companyDetailsData,
      );

      if (!success) throw Exception('Failed to update company');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Company updated successfully!'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating company: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _isLoading = true;
          });

          // Upload to Supabase Storage using the correct method
          final uploadedUrl = await StorageService.uploadCompanyLogo(
            ownerId: supabase.auth.currentUser!.id,
            file: file,
          );

          if (uploadedUrl != null) {
            setState(() {
              _logoUrl = uploadedUrl;
              _isLoading = false;
            });
          } else {
            throw Exception('Failed to upload image');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.company != null ? 'Edit Company' : 'Create Company',
          style: const TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkTeal.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: darkTeal,
              size: 20,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: mediumSeaGreen,
                    ),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildBasicInfoPage(),
                _buildCompanyDetailsPage(),
                _buildCompanyCulturePage(),
              ],
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildProgressStep(0, 'Basic Info', Icons.business),
              ),
              Expanded(
                child: _buildProgressStep(1, 'Details', Icons.location_on),
              ),
              Expanded(
                child: _buildProgressStep(2, 'Culture', Icons.people),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: paleGreen.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(mediumSeaGreen),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String title, IconData icon) {
    final isActive = _currentPage == step;
    final isCompleted = _currentPage > step;
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? mediumSeaGreen : paleGreen.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Logo Section
          _buildLogoSection(),
          
          const SizedBox(height: 32),
          
          // Company Name
          _buildTextField(
            controller: _nameController,
            label: 'Company Name',
            hint: 'Enter your company name',
            icon: Icons.business,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company name is required';
              }
              if (value.trim().length < 2) {
                return 'Company name must be at least 2 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // About Company
          _buildTextField(
            controller: _aboutController,
            label: 'About Company',
            hint: 'Tell us about your company, its mission, and what makes it unique...',
            icon: Icons.description,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company description is required';
              }
              if (value.trim().length < 50) {
                return 'Description must be at least 50 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Website
          _buildTextField(
            controller: _websiteController,
            label: 'Company Website',
            hint: 'https://yourcompany.com',
            icon: Icons.link,
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasAbsolutePath) {
                  return 'Please enter a valid URL';
                }
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Industry Selection
          _buildDropdownField(
            label: 'Industry',
            value: _selectedIndustry,
            items: _industries,
            icon: Icons.category,
            onChanged: (value) {
              setState(() {
                _selectedIndustry = value ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an industry';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Company Size
          _buildDropdownField(
            label: 'Company Size',
            value: _selectedCompanySize,
            items: _companySizes,
            icon: Icons.group,
            onChanged: (value) {
              setState(() {
                _selectedCompanySize = value ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select company size';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Business Type
          _buildDropdownField(
            label: 'Business Type',
            value: _selectedBusinessType,
            items: _businessTypes,
            icon: Icons.business_center,
            onChanged: (value) {
              setState(() {
                _selectedBusinessType = value ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select business type';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Visibility Toggle
          _buildVisibilityToggle(),
        ],
      ),
    );
  }

  Widget _buildCompanyDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Address',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Business Address
          _buildTextField(
            controller: _businessAddressController,
            label: 'Street Address',
            hint: 'Enter your business address',
            icon: Icons.location_on,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Business address is required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'City',
                  icon: Icons.location_city,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _provinceController,
                  label: 'Province/State',
                  hint: 'Province/State',
                  icon: Icons.map,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Province is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _postalCodeController,
                  label: 'Postal Code',
                  hint: 'Postal Code',
                  icon: Icons.local_post_office,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Postal code is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'Country',
                  icon: Icons.public,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Country is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Contact Information',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Contact Person Name
          _buildTextField(
            controller: _contactPersonNameController,
            label: 'Contact Person Name',
            hint: 'Full name of the contact person',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact person name is required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _contactPersonPositionController,
                  label: 'Position/Title',
                  hint: 'e.g., HR Manager',
                  icon: Icons.work,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Position is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _contactPersonPhoneController,
                  label: 'Phone Number',
                  hint: '09XXXXXXXXX',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!_isValidPhilippinesPhoneNumber(value.trim())) {
                      return 'Phone number must be 11 digits starting with 09';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Contact Email
          _buildTextField(
            controller: _contactPersonEmailController,
            label: 'Contact Email',
            hint: 'contact@yourcompany.com',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Social Media Links',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Social media links
          _buildTextField(
            controller: _linkedinController,
            label: 'LinkedIn URL',
            hint: 'https://linkedin.com/company/yourcompany',
            icon: Icons.link,
            keyboardType: TextInputType.url,
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _facebookController,
            label: 'Facebook URL',
            hint: 'https://facebook.com/yourcompany',
            icon: Icons.link,
            keyboardType: TextInputType.url,
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _twitterController,
                  label: 'Twitter URL',
                  hint: 'https://twitter.com/yourcompany',
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _instagramController,
                  label: 'Instagram URL',
                  hint: 'https://instagram.com/yourcompany',
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCulturePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company Culture & Values',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Company Mission
          _buildTextField(
            controller: _companyMissionController,
            label: 'Company Mission',
            hint: 'Describe your company\'s mission and purpose...',
            icon: Icons.flag,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company mission is required';
              }
              if (value.trim().length < 20) {
                return 'Mission must be at least 20 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Company Vision
          _buildTextField(
            controller: _companyVisionController,
            label: 'Company Vision',
            hint: 'Describe your company\'s vision for the future...',
            icon: Icons.visibility,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company vision is required';
              }
              if (value.trim().length < 20) {
                return 'Vision must be at least 20 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Company Culture
          _buildTextField(
            controller: _companyCultureController,
            label: 'Company Culture',
            hint: 'Describe your company culture, values, and work environment...',
            icon: Icons.people,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company culture description is required';
              }
              if (value.trim().length < 30) {
                return 'Culture description must be at least 30 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Company Benefits
          _buildTextField(
            controller: _companyBenefitsController,
            label: 'Company Benefits',
            hint: 'List benefits separated by commas (e.g., Health Insurance, Flexible Hours, Professional Development)',
            icon: Icons.card_giftcard,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company benefits are required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mediumSeaGreen,
                  side: const BorderSide(color: mediumSeaGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (_currentPage > 0) const SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage < 2 ? _nextPage : _saveCompany,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _currentPage < 2 ? 'Next' : (widget.company != null ? 'Update Company' : 'Create Company'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.1),
                  paleGreen.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mediumSeaGreen.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: _logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      _logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildLogoPlaceholder();
                      },
                    ),
                  )
                : _buildLogoPlaceholder(),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _pickLogoImage,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text(
              'Upload Logo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Recommended: 200x200px, PNG or JPG',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.business,
          size: 48,
          color: darkTeal.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Company Logo',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _isValidPhilippinesPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid Philippines mobile number (11 digits starting with 09)
    return RegExp(r'^09\d{9}$').hasMatch(digitsOnly);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: mediumSeaGreen,
              size: 20,
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: mediumSeaGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: mediumSeaGreen,
              size: 20,
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: mediumSeaGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPublic ? Icons.visibility : Icons.visibility_off,
            color: mediumSeaGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPublic ? 'Public Company' : 'Private Company',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isPublic 
                      ? 'Your company profile will be visible to job seekers'
                      : 'Your company profile will be hidden from job seekers',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: (value) {
              setState(() {
                _isPublic = value;
              });
            },
            activeColor: mediumSeaGreen,
            inactiveThumbColor: paleGreen,
            inactiveTrackColor: paleGreen.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

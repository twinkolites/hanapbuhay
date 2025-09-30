import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';

final supabase = Supabase.instance.client;

class EditCompanyScreen extends StatefulWidget {
  final Map<String, dynamic>? company;
  
  const EditCompanyScreen({
    super.key,
    this.company,
  });

  @override
  State<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends State<EditCompanyScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _profileUrlController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPublic = true;
  String? _logoUrl;
  
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
    
    _initializeCompanyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _profileUrlController.dispose();
    super.dispose();
  }

  void _initializeCompanyData() {
    if (widget.company != null) {
      _nameController.text = widget.company!['name'] ?? '';
      _aboutController.text = widget.company!['about'] ?? '';
      _profileUrlController.text = widget.company!['profile_url'] ?? '';
      _isPublic = widget.company!['is_public'] ?? true;
      _logoUrl = widget.company!['logo_url'];
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final companyData = {
        'name': _nameController.text.trim(),
        'about': _aboutController.text.trim(),
        'profile_url': _profileUrlController.text.trim(),
        'is_public': _isPublic,
        'logo_url': _logoUrl,
      };

      if (widget.company != null) {
        // Update existing company
        final result = await JobService.updateCompany(widget.company!['id'], companyData);
        if (result == null) throw Exception('Failed to update company');
      } else {
        // Create new company
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception('User not authenticated');
        
        final result = await JobService.createCompany(
          ownerId: user.id,
          name: companyData['name'] as String,
          about: companyData['about'] as String?,
          logoUrl: companyData['logo_url'] as String?,
        );
        if (result == null) throw Exception('Failed to create company');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.company != null 
                ? 'Company updated successfully!' 
                : 'Company created successfully!',
            ),
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
        _showErrorDialog('Error saving company: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Error',
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: mediumSeaGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadLogo() async {
    // TODO: Implement logo upload functionality
    // This would typically involve:
    // 1. Image picker
    // 2. File upload to Supabase storage
    // 3. Getting the public URL
    // 4. Setting _logoUrl
    
    ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
          content: const Text('Logo upload feature coming soon!'),
        backgroundColor: mediumSeaGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        title: Text(
          widget.company != null ? 'Edit Company' : 'Create Company',
          style: const TextStyle(
            color: darkTeal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveCompany,
              child: Text(
                'Save',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
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
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // About Company
            _buildTextField(
              controller: _aboutController,
              label: 'About Company',
              hint: 'Tell us about your company...',
              icon: Icons.description,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company description is required';
                }
                if (value.trim().length < 20) {
                  return 'Description must be at least 20 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Profile URL
            _buildTextField(
              controller: _profileUrlController,
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
            
            // Visibility Toggle
            _buildVisibilityToggle(),
            
            const SizedBox(height: 32),
            
            // Save Button
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: mediumSeaGreen,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mediumSeaGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.company != null ? 'Update Company' : 'Create Company',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Column(
        children: [
          // Logo Display
          GestureDetector(
            onTap: _uploadLogo,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: paleGreen,
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
          ),
          
          const SizedBox(height: 16),
          
          // Upload Button
          TextButton.icon(
            onPressed: _uploadLogo,
            icon: const Icon(
              Icons.upload,
              color: mediumSeaGreen,
              size: 20,
            ),
            label: Text(
              _logoUrl != null ? 'Change Logo' : 'Upload Logo',
              style: const TextStyle(
                color: mediumSeaGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
          size: 40,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
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
            fillColor: lightMint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
              borderSide: BorderSide(
                color: Colors.red.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen,
          width: 1,
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
                  'Public Profile',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isPublic 
                    ? 'Your company profile is visible to job seekers'
                    : 'Your company profile is private',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 14,
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
            activeTrackColor: paleGreen,
          ),
        ],
      ),
    );
  }
}

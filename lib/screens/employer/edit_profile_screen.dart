import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../services/image_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/age_validation_utils.dart';

final supabase = Supabase.instance.client;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _usernameController = TextEditingController();

  DateTime? _selectedBirthday;
  bool _isLoading = false;
  bool _showChangePassword = false;
  bool _isImageLoading = false;
  File? _selectedImage;
  
  // Phone number validation
  bool _isPhoneNumber = false;
  String _formattedPhoneNumber = '';
  
  // Password change controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _initializeFormData();

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
  }

  void _initializeFormData() {
    _fullNameController.text = widget.profile['full_name'] ?? '';
    _displayNameController.text = widget.profile['display_name'] ?? '';
    _emailController.text = widget.profile['email'] ?? '';
    _phoneNumberController.text = widget.profile['phone_number'] ?? '';
    _usernameController.text = widget.profile['username'] ?? '';
    
    if (widget.profile['birthday'] != null) {
      _selectedBirthday = DateTime.parse(widget.profile['birthday']);
    }
    
    // Validate existing phone number
    if (_phoneNumberController.text.isNotEmpty) {
      _validateInput(_phoneNumberController.text);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Phone number validation methods
  bool _isValidPhilippinesPhoneNumber(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's exactly 10 digits and starts with 9
    if (digitsOnly.length == 10 && digitsOnly.startsWith('9')) {
      return true;
    }
    
    // Check if it's 13 digits starting with +63 or 63
    if (digitsOnly.length == 13 && digitsOnly.startsWith('63')) {
      String withoutCountryCode = digitsOnly.substring(2);
      return withoutCountryCode.startsWith('9') && withoutCountryCode.length == 10;
    }
    
    return false;
  }

  String _formatPhoneNumber(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it starts with 63, remove it
    if (digitsOnly.startsWith('63') && digitsOnly.length == 13) {
      digitsOnly = digitsOnly.substring(2);
    }
    
    // Format as +63 9XX XXX XXXX
    if (digitsOnly.length == 10 && digitsOnly.startsWith('9')) {
      return '+63 ${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6)}';
    }
    
    return input;
  }

  void _validateInput(String input) {
    setState(() {
      _isPhoneNumber = _isValidPhilippinesPhoneNumber(input);
      if (_isPhoneNumber) {
        _formattedPhoneNumber = _formatPhoneNumber(input);
      } else {
        _formattedPhoneNumber = '';
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await ImageService.showImageSourceDialog(context);
      if (source == null) return;

      final XFile? image = await ImageService.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Validate image
        if (!ImageService.validateImage(imageFile)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ImageService.getImageValidationError(imageFile)),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = imageFile;
          _isImageLoading = true;
        });

        // Upload image
        final user = supabase.auth.currentUser;
        if (user != null) {
          final String? imageUrl = await ImageService.uploadProfileImage(
            imageFile: imageFile,
            userId: user.id,
          );

          if (imageUrl != null) {
            // Update profile with new image URL
            await supabase
                .from('profiles')
                .update({'avatar_url': imageUrl})
                .eq('id', user.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile photo updated successfully!'),
                  backgroundColor: mediumSeaGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to upload image. Please try again.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate phone number if it's provided
    if (_phoneNumberController.text.trim().isNotEmpty) {
      if (!_isValidPhilippinesPhoneNumber(_phoneNumberController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid Philippines phone number! Must start with 9 and be exactly 10 digits.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final updateData = {
        'full_name': _fullNameController.text.trim(),
        'display_name': _displayNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneNumberController.text.trim().isNotEmpty 
            ? _phoneNumberController.text.trim() 
            : null,
        'username': _usernameController.text.trim().isNotEmpty 
            ? _usernameController.text.trim() 
            : null,
        'birthday': _selectedBirthday?.toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all password fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New passwords do not match'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New password must be at least 6 characters'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPasswordLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: _newPasswordController.text,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully!'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _showChangePassword = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isPasswordLoading = false;
      });
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? AgeValidationUtils.getMinimumBirthDate(), // Exactly 18 years ago
      firstDate: DateTime(1900),
      lastDate: AgeValidationUtils.getMinimumBirthDate(), // Must be at least 18 years old
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: mediumSeaGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: darkTeal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
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
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: darkTeal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
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
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            
            const SizedBox(height: 32),
            
            // Personal Information Section
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              children: [
                _buildModernTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Full name must be at least 2 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                      return 'Full name can only contain letters and spaces';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildModernTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  hint: 'How you want to be shown to others',
                  icon: Icons.badge_outlined,
                ),
                
                const SizedBox(height: 20),
                
                _buildModernTextField(
                  controller: _usernameController,
                  label: 'Username (Optional)',
                  hint: 'Choose a unique username',
                  icon: Icons.alternate_email,
                ),
                
                const SizedBox(height: 20),
                
                _buildModernBirthdayField(),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Contact Information Section
            _buildSectionCard(
              title: 'Contact Information',
              icon: Icons.contact_phone_outlined,
              children: [
                _buildModernTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'Enter your email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildModernTextField(
                  controller: _phoneNumberController,
                  label: 'Phone Number (Optional)',
                  hint: 'Enter your Philippines phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-\(\)]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: _validateInput,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Security Section
            _buildSecuritySection(),
            
            const SizedBox(height: 32),
            
            _buildModernUpdateButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isImageLoading ? null : _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        mediumSeaGreen.withValues(alpha: 0.1),
                        paleGreen.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: mediumSeaGreen,
                      width: 3,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(37),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          ),
                        )
                      : widget.profile['avatar_url'] != null && widget.profile['avatar_url'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(37),
                              child: Image.network(
                                widget.profile['avatar_url'],
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildProfilePlaceholder();
                                },
                              ),
                            )
                          : _buildProfilePlaceholder(),
                ),
                if (_isImageLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: mediumSeaGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isImageLoading ? Icons.hourglass_empty : Icons.camera_alt,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Edit Your Profile',
            style: const TextStyle(
              color: darkTeal,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            'Update your personal information',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person,
          size: 30,
          color: darkTeal.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Profile',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: mediumSeaGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 11,
            color: darkTeal,
            letterSpacing: 0.1,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 0.1,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: mediumSeaGreen,
                size: 16,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
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
                width: 1,
              ),
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.2),
          ),
        ),
        // Phone number validation feedback
        if (onChanged != null && controller == _phoneNumberController && controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildPhoneValidation(),
          ),
      ],
    );
  }

  Widget _buildPhoneValidation() {
    if (_isPhoneNumber && _formattedPhoneNumber.isNotEmpty) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            color: mediumSeaGreen,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Valid: $_formattedPhoneNumber',
            style: TextStyle(
              color: mediumSeaGreen,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      );
    } else if (!_isPhoneNumber && _phoneNumberController.text.length > 3) {
      return Text(
        'For Philippines: Enter 9XXXXXXXXX or +63 9XX XXX XXXX',
        style: TextStyle(
          color: Colors.red.withValues(alpha: 0.7),
          fontSize: 10,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.1,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildModernBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Birthday (Optional)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectBirthday,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: lightMint.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cake_outlined,
                    color: mediumSeaGreen,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    _selectedBirthday != null
                        ? '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}'
                        : 'Select your birthday',
                    style: TextStyle(
                      color: _selectedBirthday != null 
                          ? darkTeal 
                          : darkTeal.withValues(alpha: 0.5),
                      fontSize: 11,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (_selectedBirthday != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedBirthday = null;
                      });
                    },
                    icon: Icon(
                      Icons.clear,
                      color: darkTeal.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.security_outlined,
                    color: mediumSeaGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security',
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Manage your account security',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.6),
                          fontSize: 10,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lock_outline,
                color: mediumSeaGreen,
                size: 18,
              ),
            ),
            title: Text(
              'Change Password',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            subtitle: Text(
              'Update your account password',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 10,
                letterSpacing: 0.1,
              ),
            ),
            trailing: Switch(
              value: _showChangePassword,
              onChanged: (value) {
                setState(() {
                  _showChangePassword = value;
                  if (!value) {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  }
                });
              },
              activeColor: mediumSeaGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_showChangePassword) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildModernPasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    hint: 'Enter your current password',
                  ),
                  const SizedBox(height: 16),
                  _buildModernPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    hint: 'Enter your new password',
                  ),
                  const SizedBox(height: 16),
                  _buildModernPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    hint: 'Confirm your new password',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPasswordLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mediumSeaGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isPasswordLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Update Password',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(
            fontSize: 11,
            color: darkTeal,
            letterSpacing: 0.1,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 0.1,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lock_outline,
                color: mediumSeaGreen,
                size: 16,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
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
                width: 1,
              ),
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildModernUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _updateProfile,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(
          _isLoading ? 'Updating Profile...' : 'Update Profile',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: mediumSeaGreen.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

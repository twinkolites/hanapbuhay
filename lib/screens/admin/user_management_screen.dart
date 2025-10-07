import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_service.dart';
import '../../utils/safe_snackbar.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _selectedRole = 'all';

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await AdminService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedRole == 'all') return _users;
    return _users.where((user) => user['role'] == _selectedRole).toList();
  }

  Future<void> _suspendUser(Map<String, dynamic> user) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final success = await AdminService.suspendUser(
        userId: user['id'],
        adminId: currentUser.id,
        reason: 'Suspended by admin',
      );

      if (success) {
        SafeSnackBar.showWarning(
          context,
          message: '${user['full_name']} suspended',
        );
        _loadUsers(); // Refresh the list
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to suspend user',
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: mediumSeaGreen),
      );
    }

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                'Filter by role:',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'applicant', child: Text('Applicants')),
                    DropdownMenuItem(value: 'employer', child: Text('Employers')),
                    DropdownMenuItem(value: 'admin', child: Text('Admins')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value!);
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              final company = user['companies'] as List?;
              final companyData = company?.isNotEmpty == true ? company![0] : null;
              final applicantProfile = user['applicant_profile'] as List?;
              final profileData = applicantProfile?.isNotEmpty == true ? applicantProfile![0] : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getRoleColor(user['role']).withValues(alpha: 0.1),
                            child: Text(
                              user['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                color: _getRoleColor(user['role']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['full_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: darkTeal,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: darkTeal.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user['role']).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getRoleDisplayName(user['role']),
                              style: TextStyle(
                                color: _getRoleColor(user['role']),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Additional info based on role
                      if (companyData != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightMint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Company: ${companyData['name'] ?? 'Not provided'}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      
                      if (profileData != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightMint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Experience: ${profileData['years_of_experience'] ?? 0} years',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Text(
                            'Joined: ${_formatDate(user['created_at'])}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (user['role'] != 'admin') ...[
                            IconButton(
                              onPressed: () => _suspendUser(user),
                              icon: Icon(
                                Icons.block,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip: 'Suspend User',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'employer':
        return Colors.blue;
      case 'applicant':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'employer':
        return 'Employer';
      case 'applicant':
        return 'Applicant';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

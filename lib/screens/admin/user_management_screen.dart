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

  Future<void> _showSuspensionConfirmationDialog(Map<String, dynamic> user) async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirm Suspension',
                  style: TextStyle(
                    fontSize: 16, // Max size
                    fontWeight: FontWeight.bold,
                    color: darkTeal,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are about to suspend:',
                        style: TextStyle(
                          fontSize: 11, // Body size
                          color: darkTeal.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['full_name'] ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: 13, // Title size
                          fontWeight: FontWeight.bold,
                          color: darkTeal,
                        ),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          fontSize: 11, // Body size
                          color: darkTeal.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Consequences explanation
                Text(
                  'This action will:',
                  style: TextStyle(
                    fontSize: 13, // Title size
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                const SizedBox(height: 8),
                
                _buildConsequenceItem('Immediately block user access'),
                _buildConsequenceItem('Prevent user from logging in'),
                _buildConsequenceItem('Deactivate all user activities'),
                _buildConsequenceItem('Require admin action to restore access'),
                
                const SizedBox(height: 16),
                
                // Reason input
                Text(
                  'Suspension Reason (Required):',
                  style: TextStyle(
                    fontSize: 13, // Title size
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 11, // Body size
                    color: darkTeal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter the reason for suspension...',
                    hintStyle: TextStyle(
                      fontSize: 11, // Body size
                      color: darkTeal.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: mediumSeaGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Cancel button
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13, // Title size
                  color: darkTeal.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            
            // Suspend button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Suspend User',
                    style: TextStyle(
                      fontSize: 13, // Title size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                
                if (reason.isEmpty) {
                  SafeSnackBar.showError(
                    dialogContext,
                    message: 'Please provide a reason for suspension',
                  );
                  return;
                }
                
                Navigator.of(dialogContext).pop();
                _suspendUser(user, reason);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11, // Body size
                color: darkTeal.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendUser(Map<String, dynamic> user, String reason) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: mediumSeaGreen),
                const SizedBox(height: 16),
                Text(
                  'Suspending user...',
                  style: TextStyle(
                    fontSize: 11, // Body size
                    color: darkTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final success = await AdminService.suspendUser(
        userId: user['id'],
        adminId: currentUser.id,
        reason: reason,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        SafeSnackBar.showSuccess(
          context,
          message: '${user['full_name']} has been suspended',
        );
        _loadUsers(); // Refresh the list
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to suspend user',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      SafeSnackBar.showError(
        context,
        message: 'Error: $e',
      );
    }
  }

  Future<void> _showRestoreConfirmationDialog(Map<String, dynamic> user) async {
    final TextEditingController notesController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restore User Access',
                  style: TextStyle(
                    fontSize: 16, // Max size
                    fontWeight: FontWeight.bold,
                    color: darkTeal,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are about to restore access for:',
                        style: TextStyle(
                          fontSize: 11, // Body size
                          color: darkTeal.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['full_name'] ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: 13, // Title size
                          fontWeight: FontWeight.bold,
                          color: darkTeal,
                        ),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          fontSize: 11, // Body size
                          color: darkTeal.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Suspension info
                if (user['suspension_reason'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suspended for:',
                          style: TextStyle(
                            fontSize: 11, // Body size
                            fontWeight: FontWeight.w600,
                            color: darkTeal.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['suspension_reason'] ?? 'No reason provided',
                          style: TextStyle(
                            fontSize: 11, // Body size
                            color: darkTeal.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // What will happen
                Text(
                  'This action will:',
                  style: TextStyle(
                    fontSize: 13, // Title size
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                const SizedBox(height: 8),
                
                _buildRestoreConsequenceItem('Restore full user access'),
                _buildRestoreConsequenceItem('Allow user to login again'),
                _buildRestoreConsequenceItem('Reactivate all user activities'),
                _buildRestoreConsequenceItem('Clear suspension record'),
                
                const SizedBox(height: 16),
                
                // Optional notes
                Text(
                  'Restoration Notes (Optional):',
                  style: TextStyle(
                    fontSize: 13, // Title size
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11, // Body size
                    color: darkTeal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add any notes about the restoration...',
                    hintStyle: TextStyle(
                      fontSize: 11, // Body size
                      color: darkTeal.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: mediumSeaGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13, // Title size
                  color: darkTeal.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Restore Access',
                    style: TextStyle(
                      fontSize: 13, // Title size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _unsuspendUser(user, notesController.text.trim());
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRestoreConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: Colors.green.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11, // Body size
                color: darkTeal.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unsuspendUser(Map<String, dynamic> user, String? notes) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: mediumSeaGreen),
                const SizedBox(height: 16),
                Text(
                  'Restoring user access...',
                  style: TextStyle(
                    fontSize: 11, // Body size
                    color: darkTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final success = await AdminService.unsuspendUser(
        userId: user['id'],
        adminId: currentUser.id,
        notes: notes,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        SafeSnackBar.showSuccess(
          context,
          message: '${user['full_name']} access has been restored',
        );
        _loadUsers(); // Refresh the list
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to restore user access',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
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
                  fontSize: 13, // Title size
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
                color: Colors.white,
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
                                    fontSize: 13, // Title size
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: darkTeal.withValues(alpha: 0.7),
                                    fontSize: 11, // Body size
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
                                fontSize: 11, // Body size
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
                              fontSize: 11, // Body size
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
                              fontSize: 11, // Body size
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          // Suspension badge if suspended
                          if (user['is_suspended'] == true) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SUSPENDED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Joined: ${_formatDate(user['created_at'])}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.6),
                              fontSize: 11, // Body size
                            ),
                          ),
                          const Spacer(),
                          if (user['role'] != 'admin') ...[
                            // Show Restore button if suspended, Suspend button if not
                            if (user['is_suspended'] == true)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showRestoreConfirmationDialog(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Restore',
                                          style: TextStyle(
                                            fontSize: 11, // Body size
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showSuspensionConfirmationDialog(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.block,
                                          color: Colors.red,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Suspend',
                                          style: TextStyle(
                                            fontSize: 11, // Body size
                                            color: Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../utils/safe_snackbar.dart';

class EmployerApprovalScreen extends StatefulWidget {
  const EmployerApprovalScreen({super.key});

  @override
  State<EmployerApprovalScreen> createState() => _EmployerApprovalScreenState();
}

class _EmployerApprovalScreenState extends State<EmployerApprovalScreen> {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  final int _pageSize = 10;
  int _currentPage = 1;
  final Set<String> _selectedEmployerIds = <String>{};
  final Set<String> _expandedDetails = <String>{}; // Track which cards have expanded details

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _statusFilter = 'All';
    _loadPendingApprovals();
  }

  Future<void> _confirmDeleteDocument(String filePath, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('This will permanently delete "$fileName" from storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await AdminService.deleteEmployerDocument(filePath: filePath);
      if (ok) {
        SafeSnackBar.showSuccess(context, message: 'Document deleted');
        await _viewEmployerDocuments({'employer_id': Supabase.instance.client.auth.currentUser?.id});
      } else {
        SafeSnackBar.showError(context, message: 'Failed to delete document');
      }
    } catch (e) {
      SafeSnackBar.showError(context, message: 'Error deleting: $e');
    }
  }

  Future<void> _loadPendingApprovals() async {
    try {
      // Load all employer approvals since default filter is 'All'
      final approvals = await AdminService.getAllEmployerApprovals();
      
      // Debug logging to see the actual data structure
      debugPrint('🔍 Loaded ${approvals.length} employer approvals');
      if (approvals.isNotEmpty) {
        debugPrint('🔍 First approval data structure: ${approvals[0]}');
        debugPrint('🔍 Profiles data: ${approvals[0]['profiles']}');
        debugPrint('🔍 Companies data: ${approvals[0]['companies']}');
      }
      
      if (mounted) {
        setState(() {
          _pendingApprovals = approvals;
          _isLoading = false;
          _currentPage = 1;
          _selectedEmployerIds.clear();
        });
      }
    } catch (e) {
      debugPrint('Error loading pending approvals: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelect(String employerId, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedEmployerIds.add(employerId);
      } else {
        _selectedEmployerIds.remove(employerId);
      }
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> pageItems, bool? checked) {
    setState(() {
      if (checked == true) {
        for (final item in pageItems) {
          final id = item['employer_id'] as String?;
          if (id != null) _selectedEmployerIds.add(id);
        }
      } else {
        for (final item in pageItems) {
          final id = item['employer_id'] as String?;
          if (id != null) _selectedEmployerIds.remove(id);
        }
      }
    });
  }

  Future<void> _bulkApprove(List<String> employerIds) async {
    if (employerIds.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    int success = 0;
    for (final id in employerIds) {
      final ok = await AdminService.approveEmployer(employerId: id, adminId: user.id, notes: 'Bulk approved');
      if (ok) success++;
    }
    SafeSnackBar.showSuccess(context, message: 'Approved $success/${employerIds.length}');
    await _loadPendingApprovals();
  }

  Future<void> _bulkReject(List<String> employerIds) async {
    if (employerIds.isEmpty) return;
    final controller = TextEditingController();
    final confirm = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Reject selected?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to reject ${employerIds.length} application(s). Provide a reason:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Reason (visible to employer)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, {'reason': controller.text.trim()}), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm == null) return;
    final reason = (confirm['reason'] as String?)?.trim() ?? '';
    if (reason.isEmpty) {
      SafeSnackBar.showInfo(context, message: 'Rejection requires a reason');
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    int success = 0;
    for (final id in employerIds) {
      final ok = await AdminService.rejectEmployer(employerId: id, adminId: user.id, reason: reason);
      if (ok) success++;
    }
    SafeSnackBar.showWarning(context, message: 'Rejected $success/${employerIds.length}');
    await _loadPendingApprovals();
  }

  void _openDetailsSheet(Map<String, dynamic> verification) async {
    final employerName = verification['employer_full_name'] ?? 'Unknown';
    final employerEmail = verification['employer_email'] ?? '';
    final companyName = verification['company_name'] ?? 'Not provided';
    final status = verification['verification_status'] as String? ?? 'pending';
    final employerId = verification['employer_id'] as String?;
    // Optional extended fields coming from registration
    final companyAbout = (verification['company_about'] ?? '').toString(); // used as fallback when details missing
    final businessAddress = (verification['business_address'] ?? '').toString();
    final city = (verification['city'] ?? '').toString();
    final province = (verification['province'] ?? '').toString();
    final postalCode = (verification['postal_code'] ?? '').toString();
    final country = (verification['country'] ?? '').toString();
    final industry = (verification['industry'] ?? '').toString();
    final companySize = (verification['company_size'] ?? '').toString();
    final businessType = (verification['business_type'] ?? '').toString();
    final contactName = (verification['contact_person_name'] ?? '').toString();
    final contactPosition = (verification['contact_person_position'] ?? '').toString();
    final contactEmail = (verification['contact_person_email'] ?? '').toString();
    // Access employerId when needed; available via verification map
    // Prefetch intentionally removed to avoid unused local variable; documents are loaded on demand in the dialog
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: mediumSeaGreen.withValues(alpha: 0.12),
                            border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (employerName.toString().isNotEmpty ? employerName.substring(0, 1) : '?').toUpperCase(),
                            style: TextStyle(color: mediumSeaGreen, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(employerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.alternate_email, size: 14, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(employerEmail, style: const TextStyle(color: Colors.black54))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: employerId != null ? AdminService.getEmployerFullDetails(employerId: employerId) : Future.value(null),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final full = snapshot.data;
                        Map<String, dynamic>? company;
                        Map<String, dynamic>? details;
                        if (full != null) {
                          final comp = full['companies'];
                          if (comp is List) {
                            company = comp.isNotEmpty ? Map<String, dynamic>.from(comp.first) : null;
                          } else if (comp is Map) {
                            company = Map<String, dynamic>.from(comp);
                          }
                          if (company != null) {
                            final det = company['company_details'];
                            if (det is List) {
                              details = det.isNotEmpty ? Map<String, dynamic>.from(det.first) : null;
                            } else if (det is Map) {
                              details = Map<String, dynamic>.from(det);
                            }
                          }
                        }

                        final resolvedCompanyName = company?['name']?.toString().trim().isNotEmpty == true ? company!['name'] as String : companyName;
                        final aboutText = company?['about']?.toString().trim().isNotEmpty == true
                            ? company!['about'] as String
                            : companyAbout;

                        final businessAddressF = (details?['business_address'] ?? businessAddress).toString();
                        final cityF = (details?['city'] ?? city).toString();
                        final provinceF = (details?['province'] ?? province).toString();
                        final postalCodeF = (details?['postal_code'] ?? postalCode).toString();
                        final countryF = (details?['country'] ?? country).toString();
                        final industryF = (details?['industry'] ?? industry).toString();
                        final companySizeF = (details?['company_size'] ?? companySize).toString();
                        final businessTypeF = (details?['business_type'] ?? businessType).toString();
                        final contactNameF = (details?['contact_person_name'] ?? contactName).toString();
                        final contactPositionF = (details?['contact_person_position'] ?? contactPosition).toString();
                        final contactEmailF = (details?['contact_person_email'] ?? contactEmail).toString();
                        final linkedinUrl = (details?['linkedin_url'] ?? '').toString();
                        final facebookUrl = (details?['facebook_url'] ?? '').toString();
                        final twitterUrl = (details?['twitter_url'] ?? '').toString();
                        final instagramUrl = (details?['instagram_url'] ?? '').toString();
                        final companyBenefitsF = details?['company_benefits'] is List ? List<String>.from(details!['company_benefits'] as List) : <String>[];
                        final companyCultureF = (details?['company_culture'] ?? '').toString();
                        final companyMissionF = (details?['company_mission'] ?? '').toString();
                        final companyVisionF = (details?['company_vision'] ?? '').toString();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (resolvedCompanyName != 'Not provided')
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.business, color: Colors.black54),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Company', style: TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 4),
                                          Text(resolvedCompanyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Details from company_details
                            if ([aboutText, industryF, businessTypeF, companySizeF, businessAddressF, cityF, provinceF, postalCodeF, countryF, contactNameF, contactPositionF, contactEmailF].any((e) => e.toString().trim().isNotEmpty))
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.info_outline, size: 18, color: Colors.black54),
                                        SizedBox(width: 8),
                                        Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (aboutText.trim().isNotEmpty) _infoRow('About', aboutText),
                                    if (industryF.trim().isNotEmpty) _infoRow('Industry', industryF),
                                    if (businessTypeF.trim().isNotEmpty) _infoRow('Business type', businessTypeF),
                                    if (companySizeF.trim().isNotEmpty) _infoRow('Company size', companySizeF),
                                    if ([businessAddressF, cityF, provinceF, postalCodeF, countryF].any((e) => e.trim().isNotEmpty))
                                      _infoRow('Address', [businessAddressF, cityF, provinceF, postalCodeF, countryF].where((e) => e.trim().isNotEmpty).join(', ')),
                                    if ([contactNameF, contactPositionF, contactEmailF].any((e) => e.trim().isNotEmpty)) ...[
                                      const SizedBox(height: 6),
                                      const Text('Contact person', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      if (contactNameF.trim().isNotEmpty) _infoRow('Name', contactNameF),
                                      if (contactPositionF.trim().isNotEmpty) _infoRow('Position', contactPositionF),
                                      if (contactEmailF.trim().isNotEmpty) _infoRow('Email', contactEmailF),
                                    ],
                                    if ([linkedinUrl, facebookUrl, twitterUrl, instagramUrl].any((e) => e.trim().isNotEmpty)) ...[
                                      const SizedBox(height: 6),
                                      const Text('Socials', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      if (linkedinUrl.trim().isNotEmpty) _linkRow('LinkedIn', linkedinUrl),
                                      if (facebookUrl.trim().isNotEmpty) _linkRow('Facebook', facebookUrl),
                                      if (twitterUrl.trim().isNotEmpty) _linkRow('Twitter', twitterUrl),
                                      if (instagramUrl.trim().isNotEmpty) _linkRow('Instagram', instagramUrl),
                                    ],
                                    if (companyBenefitsF.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      _bulletList('Benefits', companyBenefitsF),
                                    ],
                                    if ([companyCultureF, companyMissionF, companyVisionF].any((e) => e.trim().isNotEmpty)) ...[
                                      const SizedBox(height: 6),
                                      const Text('Culture & Values', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      if (companyCultureF.trim().isNotEmpty) _infoRow('Culture', companyCultureF),
                                      if (companyMissionF.trim().isNotEmpty) _infoRow('Mission', companyMissionF),
                                      if (companyVisionF.trim().isNotEmpty) _infoRow('Vision', companyVisionF),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewEmployerDocuments(verification),
                        icon: const Icon(Icons.description),
                        label: const Text('View documents'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveEmployer(Map<String, dynamic> verification) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final employerName = verification['employer_full_name'] ?? 'Unknown';

      // lightweight loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final success = await AdminService.approveEmployer(
        employerId: verification['employer_id'],
        adminId: user.id,
        notes: 'Approved by admin',
      );

      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();

      if (success) {
        SafeSnackBar.showSuccess(
          context,
          message: '$employerName approved successfully',
        );
        if (mounted) {
          setState(() {
            final id = verification['employer_id'];
            final idx = _pendingApprovals.indexWhere((v) => v['employer_id'] == id);
            if (idx != -1) {
              _pendingApprovals[idx] = {
                ..._pendingApprovals[idx],
                'verification_status': 'approved',
              };
            }
          });
        }
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to approve employer',
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).maybePop();
      SafeSnackBar.showError(
        context,
        message: 'Error: $e',
      );
    }
  }

  Future<void> _confirmApprove(Map<String, dynamic> verification) async {
    final employerName = verification['employer_full_name'] ?? 'Unknown';
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: const [
            Icon(Icons.verified_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve employer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to approve $employerName.', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFAF1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCFE8D5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('What happens next', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
                  SizedBox(height: 6),
                  _ApproveBullet(text: 'The company profile becomes public.'),
                  _ApproveBullet(text: 'The employer gains access to posting jobs.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: mediumSeaGreen, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _approveEmployer(verification);
    }
  }

  Future<void> _viewEmployerDocuments(Map<String, dynamic> verification) async {
    try {
      final employerId = verification['employer_id'];
      // lightweight loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final documents = await AdminService.getEmployerDocuments(employerId: employerId);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (documents.isEmpty) {
        SafeSnackBar.showInfo(context, message: 'No documents uploaded yet');
        return;
      }

      showDialog(
        context: context,
        builder: (context) => _buildDocumentsDialog(verification, documents),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        SafeSnackBar.showError(context, message: 'Error loading documents: $e');
      }
    }
  }

  // Request additional information (moves verification into an "under_review" state with admin notes)
  Future<void> _confirmRequestInfo(Map<String, dynamic> verification) async {
    final employerName = verification['employer_full_name'] ?? 'Unknown';
    final controller = TextEditingController();
    const maxLen = 500;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void insertTemplate(String text) {
              final base = controller.text.trim();
              final next = base.isEmpty ? text : '$base\n\n$text';
              if (next.length <= maxLen) {
                controller.text = next;
                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                setState(() {});
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Row(
                children: [
                  Icon(Icons.outgoing_mail, color: darkTeal),
                  const SizedBox(width: 8),
                  const Text('Request more information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Let $employerName know what is missing or unclear.', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightMint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tips', style: TextStyle(fontWeight: FontWeight.w700, color: darkTeal)),
                        const SizedBox(height: 6),
                        const Text('Be specific and actionable. Mention exactly which document or field is missing.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(label: const Text('Upload business registration PDF'), onPressed: () => insertTemplate('Please upload a clear business registration PDF.')),
                      ActionChip(label: const Text('Provide Tax ID'), onPressed: () => insertTemplate('Kindly provide a readable Tax ID document.')),
                      ActionChip(label: const Text('Resubmit blurry license'), onPressed: () => insertTemplate('Your business license image was blurry. Please resubmit a clearer copy.')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    maxLength: maxLen,
                    decoration: InputDecoration(
                      labelStyle: TextStyle(color: darkTeal),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkTeal)),
                      labelText: 'Describe what you need (visible to employer)',
                      alignLabelWithHint: true,
                      hintText: 'E.g., Please upload a clear business registration PDF.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: darkTeal),
                      ),
                      counterText: '${controller.text.length}/$maxLen',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Cancel' , style: TextStyle(color: darkTeal))),
                ElevatedButton(
                  onPressed: controller.text.trim().isEmpty ? null : () => Navigator.pop(context, {'notes': controller.text.trim()}),
                  style: ElevatedButton.styleFrom(backgroundColor: darkTeal, foregroundColor: Colors.white),
                  child: const Text('Send request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final notes = (result['notes'] as String?)?.trim() ?? '';
    if (notes.isEmpty) {
      SafeSnackBar.showInfo(context, message: 'Please add details for your request');
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Update verification to under_review with admin notes
      await Supabase.instance.client
          .from('employer_verification')
          .update({
            'verification_status': 'under_review',
            'admin_notes': notes,
            'verified_by': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employer_id', verification['employer_id']);

      SafeSnackBar.showWarning(context, message: 'Requested more info from $employerName');
      if (mounted) {
        setState(() {
          final id = verification['employer_id'];
          final idx = _pendingApprovals.indexWhere((v) => v['employer_id'] == id);
          if (idx != -1) {
            _pendingApprovals[idx] = {
              ..._pendingApprovals[idx],
              'verification_status': 'under_review',
              'admin_notes': notes,
            };
          }
        });
      }
    } catch (e) {
      SafeSnackBar.showError(context, message: 'Failed to request info: $e');
    }
  }

  Widget _buildDocumentsDialog(Map<String, dynamic> verification, List<Map<String, dynamic>> documents) {
    final employerName = verification['employer_full_name'] ?? 'Unknown';
    final businessLicenseUrl = verification['business_license_url'] as String?;
    final taxIdUrl = verification['tax_id_document_url'] as String?;
    final businessRegUrl = verification['business_registration_url'] as String?;

    int total = 3;
    int done = 0;
    if ((businessLicenseUrl ?? '').isNotEmpty) done++;
    if ((taxIdUrl ?? '').isNotEmpty) done++;
    if ((businessRegUrl ?? '').isNotEmpty) done++;
    final completion = total == 0 ? 0.0 : done / total;
    
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Documents - $employerName'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checklist and progress (styled card)
            Container(
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined, color: darkTeal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Required documents', style: TextStyle(fontWeight: FontWeight.w700, color: darkTeal)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: mediumSeaGreen, size: 14),
                        const SizedBox(width: 6),
                        Text('${(completion * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _docChecklistTile('Business license document', businessLicenseUrl),
                  _docChecklistTile('Tax ID document', taxIdUrl),
                  _docChecklistTile('Business registration document', businessRegUrl),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Raw file list
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: documents.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  final fileName = (doc['name'] ?? 'Unknown file').toString();
                  final filePath = (doc['path'] ?? '').toString();
                  final size = (doc['size'] is int) ? doc['size'] as int : 0;
                  final type = (doc['docType'] ?? '').toString();
                  final canView = filePath.isNotEmpty && size > 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF2F2F2),
                      child: Text(_getFileIcon(fileName), style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${type.isNotEmpty ? '$type · ' : ''}${_formatFileSize(size)}'),
                    onTap: canView
                        ? () {
                            if (_isImageFile(fileName)) {
                              _previewImage(filePath);
                            } else if (_isPdfFile(fileName)) {
                              _openDocument(filePath); // opens in browser (or viewer)
                            } else {
                              _openDocument(filePath);
                            }
                          }
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDeleteDocument(filePath, fileName),
                        ),
                        Icon(Icons.chevron_right, color: canView ? Colors.black54 : Colors.black26),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: darkTeal)),
        ),
      ],
    );
  }

  Widget _docChecklistTile(String label, String? url) {
    final complete = (url ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(complete ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: complete ? mediumSeaGreen : darkTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label),
          ),
          if (complete)
            IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => _openDocument(url!),
            ),
        ],
      ),
    );
  }

  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  bool _isPdfFile(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  Future<void> _previewImage(String filePath) async {
    try {
      final url = await AdminService.getEmployerDocumentUrl(filePath: filePath);
      if (!mounted || url == null || url.isEmpty) return;
      // Show simple full-screen image preview
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  // helper for labeled value rows in details sheet
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _linkRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _openExternalUrl(url),
              child: Text(url, style: TextStyle(color: darkTeal)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(e)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDocument(String filePath) async {
    try {
      final isUrl = filePath.startsWith('http://') || filePath.startsWith('https://');
      final urlToOpen = isUrl ? filePath : await AdminService.getEmployerDocumentUrl(filePath: filePath);
      if (urlToOpen == null || urlToOpen.isEmpty) {
        SafeSnackBar.showError(context, message: 'File not found or access denied');
        return;
      }
      // Ensure the URL is properly encoded
      final uri = Uri.tryParse(urlToOpen) ?? Uri.parse(Uri.encodeFull(urlToOpen));
      // Try external app first, then fall back to in-app browser view
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!launched) {
        SafeSnackBar.showError(context, message: 'Cannot open document');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('404') || msg.contains('not_found') || msg.contains('object not found')) {
        SafeSnackBar.showError(context, message: 'Document is missing in storage (404)');
      } else {
        SafeSnackBar.showError(context, message: 'Error opening document: $e');
      }
    }
  }

  // _rejectEmployer is superseded by _confirmReject which collects a reason first

  Future<void> _confirmReject(Map<String, dynamic> verification) async {
    final employerName = verification['employer_full_name'] ?? 'Unknown';
    final controller = TextEditingController();
    const maxLen = 400;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void insertTemplate(String text) {
              final base = controller.text.trim();
              final next = base.isEmpty ? text : '$base\n\n$text';
              if (next.length <= maxLen) {
                controller.text = next;
                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                setState(() {});
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  Icon(Icons.report_gmailerrorred_outlined, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('Reject employer'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please provide a reason for rejecting $employerName.', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightMint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Guidance', style: TextStyle(fontWeight: FontWeight.w700, color: darkTeal)),
                        const SizedBox(height: 6),
                        const Text('Explain what failed the review and how to fix it. Keep it respectful and specific.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(label: const Text('Blurry/Unreadable document'), onPressed: () => insertTemplate('The submitted document is blurry/unreadable. Please upload a clearer copy.')),
                      ActionChip(label: const Text('Mismatched information'), onPressed: () => insertTemplate('The information on the document does not match your company profile. Please correct and resubmit.')),
                      ActionChip(label: const Text('Missing required document'), onPressed: () => insertTemplate('A required document is missing (e.g., business registration). Please upload it to proceed.')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    maxLength: maxLen,
                    cursorColor: darkTeal,
                    decoration: InputDecoration(
                      labelText: 'Reason (visible to employer)',
                      alignLabelWithHint: true,
                      hintText: 'Describe the issue and what to do next...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: darkTeal),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: darkTeal, width: 2),
                      ),
                      labelStyle: TextStyle(color: darkTeal),
                      floatingLabelStyle: TextStyle(color: darkTeal),
                      counterStyle: TextStyle(color: darkTeal),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Cancel', style: TextStyle(color: darkTeal),)),
                ElevatedButton(
                  onPressed: controller.text.trim().isEmpty ? null : () => Navigator.pop(context, {'reason': controller.text.trim()}),
                  style: ElevatedButton.styleFrom(backgroundColor: darkTeal, foregroundColor: Colors.white),
                  child: const Text('Confirm rejection'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null && (result['reason'] as String).trim().isNotEmpty) {
      // do reject with reason via AdminService
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        final success = await AdminService.rejectEmployer(
          employerId: verification['employer_id'],
          adminId: user.id,
          reason: (result['reason'] as String).trim(),
        );
        if (success) {
          SafeSnackBar.showWarning(context, message: '$employerName rejected');
          if (mounted) {
            setState(() {
              final id = verification['employer_id'];
              final idx = _pendingApprovals.indexWhere((v) => v['employer_id'] == id);
              if (idx != -1) {
                _pendingApprovals[idx] = {
                  ..._pendingApprovals[idx],
                  'verification_status': 'rejected',
                  'rejection_reason': (result['reason'] as String).trim(),
                };
              }
            });
          }
        } else {
          SafeSnackBar.showError(context, message: 'Failed to reject employer');
        }
      } catch (e) {
        SafeSnackBar.showError(context, message: 'Error: $e');
      }
    } else if (result != null) {
      SafeSnackBar.showInfo(context, message: 'Rejection requires a reason');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: mediumSeaGreen),
      );
    }

    if (_pendingApprovals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: mediumSeaGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Employers Found',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the search or status filter',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _pendingApprovals.where((v) {
      if (_searchQuery.isEmpty) return true;
      final name = (v['employer_full_name'] ?? '').toString().toLowerCase();
      final email = (v['employer_email'] ?? '').toString().toLowerCase();
      final company = (v['company_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q) || company.contains(q);
    }).toList();

    // Status filter
    final status = _statusFilter.toLowerCase();
    final filteredByStatus = status == 'all'
        ? filtered
        : filtered.where((v) => ((v['verification_status'] as String? ?? 'pending').toLowerCase()) == (status == 'under review' ? 'under_review' : status)).toList();

    // Paging
    final totalItems = filteredByStatus.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999999);
    final start = ((_currentPage - 1) * _pageSize).clamp(0, totalItems);
    final end = (start + _pageSize).clamp(0, totalItems);
    final pageSlice = filteredByStatus.sublist(start, end);

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: pageSlice.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              // Search + Filters row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: mediumSeaGreen),
                        hintText: 'Search by name, email, or company',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: mediumSeaGreen.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: mediumSeaGreen.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: mediumSeaGreen, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        hintStyle: TextStyle(
                          color: darkTeal.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120, // Fixed width for dropdown
                    height: 56, // Match the search bar height
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _statusFilter,
                        underline: const SizedBox.shrink(),
                        icon: Icon(Icons.keyboard_arrow_down, color: mediumSeaGreen),
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Under review', child: Text('Under review')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                        ],
                        onChanged: (v) => setState(() { _statusFilter = v ?? 'All'; _currentPage = 1; }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bulk bar
              if (_selectedEmployerIds.isNotEmpty)
                Row(
                  children: [
                    Text('${_selectedEmployerIds.length} selected'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _bulkApprove(_selectedEmployerIds.toList()),
                      icon: const Icon(Icons.check, color: Colors.green),
                      label: const Text('Approve selected'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _bulkReject(_selectedEmployerIds.toList()),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject selected'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Select all on page + paging controls
              Row(
                children: [
                  Checkbox(
                    value: pageSlice.isNotEmpty && pageSlice.every((e) => _selectedEmployerIds.contains(e['employer_id'] as String? ?? '')),
                    onChanged: (v) => _toggleSelectAll(pageSlice, v),
                  ),
                  const Text('Select all on page'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_currentPage of $totalPages'),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        }

        if (index == pageSlice.length + 1) {
          return const SizedBox(height: 8);
        }

        final verification = pageSlice[index - 1];
        
        // Debug logging for data extraction
        debugPrint('🔍 Processing verification $index: ${verification.keys}');
        debugPrint('🔍 Verification data: $verification');
        
        // Extract flattened data from the custom function
        final employerName = verification['employer_full_name'] ?? 'Unknown';
        final employerEmail = verification['employer_email'] ?? '';
        final companyName = verification['company_name'] ?? 'Not provided';
        final companyAbout = verification['company_about'] ?? '';
        final status = verification['verification_status'] as String? ?? 'pending';
        final submittedAtIso = verification['submitted_at'] as String? ?? verification['created_at'] as String?;
        final submittedAt = submittedAtIso != null ? DateTime.tryParse(submittedAtIso) : null;

        debugPrint('🔍 Final values - Name: $employerName, Email: $employerEmail, Company: $companyName');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
          ),
          child: Stack(
            children: [
              // decorative top accent
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.6)]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _selectedEmployerIds.contains(verification['employer_id'] as String? ?? ''),
                          onChanged: (v) => _toggleSelect(verification['employer_id'] as String? ?? '', v),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: mediumSeaGreen.withValues(alpha: 0.12),
                            border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            employerName.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: mediumSeaGreen, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      employerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: darkTeal,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusChip(status),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.alternate_email, size: 14, color: darkTeal.withValues(alpha: 0.6)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      employerEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: darkTeal.withValues(alpha: 0.7), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (companyName != 'Not provided') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.business_rounded, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company Information', style: TextStyle(color: darkTeal, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('Name: $companyName', style: TextStyle(color: darkTeal.withValues(alpha: 0.8), fontSize: 13)),
                                  if (companyAbout.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'About: $companyAbout',
                                      maxLines: _isDetailsExpanded(verification['employer_id']) ? null : 3,
                                      overflow: _isDetailsExpanded(verification['employer_id']) ? null : TextOverflow.ellipsis,
                                      style: TextStyle(color: darkTeal.withValues(alpha: 0.8), fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (submittedAt != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('In queue ${_formatTimeAgo(submittedAt)}', style: TextStyle(color: darkTeal.withValues(alpha: 0.7), fontSize: 12)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    
                    // Show different UI based on status
                    if (status.toLowerCase() == 'approved' || status.toLowerCase() == 'rejected') ...[
                      // Dropdown for approved/rejected employers
                      _buildDetailsDropdown(verification, status),
                    ] else ...[
                      // Regular action buttons for pending/under review
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openDetailsSheet(verification),
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Details'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _viewEmployerDocuments(verification),
                              icon: const Icon(Icons.description, size: 18),
                              label: const Text('Docs'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mediumSeaGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _shouldDisableRequestButton(status) ? null : () => _confirmRequestInfo(verification),
                              icon: Icon(Icons.outgoing_mail, color: _shouldDisableRequestButton(status) ? Colors.grey : darkTeal),
                              label: Text('Request', style: TextStyle(color: _shouldDisableRequestButton(status) ? Colors.grey : darkTeal)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _shouldDisableRequestButton(status) ? Colors.grey : darkTeal),
                                foregroundColor: _shouldDisableRequestButton(status) ? Colors.grey : darkTeal,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _shouldDisableApproveButton(status) ? null : () => _confirmApprove(verification),
                              icon: Icon(Icons.check_circle_outline, color: _shouldDisableApproveButton(status) ? Colors.grey : Colors.white),
                              label: Text('Approve', style: TextStyle(color: _shouldDisableApproveButton(status) ? Colors.grey : Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _shouldDisableApproveButton(status) ? Colors.grey.shade300 : mediumSeaGreen,
                                foregroundColor: _shouldDisableApproveButton(status) ? Colors.grey : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _shouldDisableRejectButton(status) ? null : () => _confirmReject(verification),
                              icon: Icon(Icons.cancel_outlined, color: _shouldDisableRejectButton(status) ? Colors.grey : darkTeal),
                              label: Text('Reject', style: TextStyle(color: _shouldDisableRejectButton(status) ? Colors.grey : darkTeal)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _shouldDisableRejectButton(status) ? Colors.grey : darkTeal),
                                foregroundColor: _shouldDisableRejectButton(status) ? Colors.grey : darkTeal,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String statusRaw) {
    final status = statusRaw.toLowerCase();
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = mediumSeaGreen; label = 'Approved'; break;
      case 'rejected':
        color = Colors.red; label = 'Rejected'; break;
      case 'under_review':
      case 'needs_info':
        color = darkTeal; label = 'Needs info'; break;
      case 'pending':
      default:
        color = darkTeal; label = 'Pending'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    Duration diff = now.difference(dateTime.toLocal());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }

  /// Determine if the Request button should be disabled
  bool _shouldDisableRequestButton(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'rejected':
        return true; // Can't request more info for approved/rejected applications
      case 'pending':
      case 'under_review':
      default:
        return false; // Can request more info for pending/under review
    }
  }

  /// Determine if the Approve button should be disabled
  bool _shouldDisableApproveButton(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return true; // Already approved, can't approve again
      case 'pending':
      case 'under_review':
      case 'rejected':
        return false; // Can approve pending/under review/rejected applications
      default:
        return false;
    }
  }

  /// Determine if the Reject button should be disabled
  bool _shouldDisableRejectButton(String status) {
    switch (status.toLowerCase()) {
      case 'rejected':
        return true; // Already rejected, can't reject again
      case 'pending':
      case 'under_review':
      case 'approved':
        return false; // Can reject pending/under review/approved applications
      default:
        return false;
    }
  }

  /// Check if details are expanded for a specific employer
  bool _isDetailsExpanded(String? employerId) {
    return employerId != null && _expandedDetails.contains(employerId);
  }

  /// Toggle details expansion for a specific employer
  void _toggleDetailsExpansion(String? employerId) {
    if (employerId == null) return;
    setState(() {
      if (_expandedDetails.contains(employerId)) {
        _expandedDetails.remove(employerId);
      } else {
        _expandedDetails.add(employerId);
      }
    });
  }

  /// Build details dropdown for approved/rejected employers
  Widget _buildDetailsDropdown(Map<String, dynamic> verification, String status) {
    final employerId = verification['employer_id'] as String?;
    final isExpanded = _isDetailsExpanded(employerId);
    final isApproved = status.toLowerCase() == 'approved';
    
    return Column(
      children: [
        // Dropdown header button
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isApproved ? mediumSeaGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isApproved ? mediumSeaGreen.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: InkWell(
            onTap: () => _toggleDetailsExpansion(employerId),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isApproved ? Icons.check_circle : Icons.cancel,
                    color: isApproved ? mediumSeaGreen : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isApproved ? 'Approved - View Details' : 'Rejected - View Details',
                      style: TextStyle(
                        color: isApproved ? mediumSeaGreen : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isApproved ? mediumSeaGreen : Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Expandable details section
        if (isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openDetailsSheet(verification),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Full Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewEmployerDocuments(verification),
                        icon: const Icon(Icons.description, size: 16),
                        label: const Text('Documents'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mediumSeaGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Additional info for approved/rejected
                const SizedBox(height: 12),
                if (isApproved) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mediumSeaGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: mediumSeaGreen, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This employer has been approved and can now post jobs and manage their company profile.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This employer application has been rejected. They can resubmit with corrections.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ApproveBullet extends StatelessWidget {
  final String text;
  const _ApproveBullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

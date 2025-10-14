import 'package:flutter/material.dart';
import '../models/calendar_models.dart';
import '../services/post_meeting_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostMeetingSummarySheet extends StatefulWidget {
  final CalendarEvent event;
  final String? applicationId; // If this was an interview
  
  const PostMeetingSummarySheet({
    super.key,
    required this.event,
    this.applicationId,
  });

  @override
  State<PostMeetingSummarySheet> createState() => _PostMeetingSummarySheetState();
}

class _PostMeetingSummarySheetState extends State<PostMeetingSummarySheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _nextStepsController = TextEditingController();
  final _actionItemController = TextEditingController();
  
  int _rating = 3;
  String _decision = 'pending';
  final List<String> _actionItems = [];
  bool _isSaving = false;
  
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void dispose() {
    _notesController.dispose();
    _nextStepsController.dispose();
    _actionItemController.dispose();
    super.dispose();
  }

  Future<void> _saveSummary() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      // Create meeting summary
      final summaryId = await PostMeetingService.createMeetingSummary(
        eventId: widget.event.id,
        createdBy: currentUser.id,
        notes: _notesController.text.trim(),
        rating: _rating,
        actionItems: _actionItems,
        nextSteps: _nextStepsController.text.trim(),
        decision: _decision,
      );
      
      if (summaryId != null) {
        // If this was an interview, update application status
        if (widget.applicationId != null && _decision != 'pending') {
          final newStatus = _getApplicationStatus(_decision);
          await PostMeetingService.updateApplicationAfterInterview(
            applicationId: widget.applicationId!,
            newStatus: newStatus,
            updatedBy: currentUser.id,
            interviewNotes: _notesController.text.trim(),
            rating: _rating,
          );
        }
        
        // Mark meeting as completed
        await PostMeetingService.markMeetingCompleted(widget.event.id);
        
        // Send follow-up notification to other participant
        if (widget.event.applicantId != null && widget.event.applicantId != currentUser.id) {
          await PostMeetingService.sendFollowUpNotification(
            recipientId: widget.event.applicantId!,
            title: 'Meeting Summary Available',
            message: 'The interview for "${widget.event.title}" has been completed. Check your updates!',
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting summary saved successfully!'),
              backgroundColor: mediumSeaGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  String _getApplicationStatus(String decision) {
    switch (decision) {
      case 'proceed':
        return 'interview'; // Aligns with app_status enum
      case 'hired':
        return 'hired'; // Exact match
      case 'reject':
        return 'rejected'; // Exact match
      case 'on_hold':
        return 'under_review'; // Map to closest status
      case 'needs_review':
        return 'under_review'; // Map to closest status
      default:
        return 'interview'; // Default to interview status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: darkTeal.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title with icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      mediumSeaGreen.withValues(alpha: 0.1),
                      paleGreen.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mediumSeaGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.summarize_rounded,
                        color: mediumSeaGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Meeting Summary',
                            style: TextStyle(
                              color: darkTeal,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.event.title,
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Rating
              _buildRatingSection(),
              
              const SizedBox(height: 16),
              
              // Decision (for interviews)
              if (widget.applicationId != null) ...[
                _buildDecisionSection(),
                const SizedBox(height: 16),
              ],
              
              // Notes
              TextFormField(
                controller: _notesController,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  labelText: 'Meeting Notes',
                  labelStyle: const TextStyle(fontSize: 11),
                  hintText: 'What was discussed? Key points...',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please add meeting notes';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Action Items
              _buildActionItemsSection(),
              
              const SizedBox(height: 16),
              
              // Next Steps
              TextFormField(
                controller: _nextStepsController,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  labelText: 'Next Steps',
                  labelStyle: const TextStyle(fontSize: 11),
                  hintText: 'What happens next?',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 20),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mediumSeaGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Summary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Rate this interview',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final star = index + 1;
              final isSelected = star <= _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getRatingText(_rating),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_vote_rounded,
                color: mediumSeaGreen,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Hiring Decision',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDecisionChip('hired', '✓ Hire', mediumSeaGreen, Icons.check_circle_rounded),
              _buildDecisionChip('proceed', '→ Next Interview', Colors.green, Icons.arrow_forward_rounded),
              _buildDecisionChip('on_hold', '⏸ Needs Review', Colors.orange, Icons.pause_circle_rounded),
              _buildDecisionChip('reject', '✗ Reject', Colors.red, Icons.cancel_rounded),
              _buildDecisionChip('pending', '? Pending', Colors.grey, Icons.help_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionChip(String value, String label, Color color, IconData icon) {
    final isSelected = _decision == value;
    return InkWell(
      onTap: () => setState(() => _decision = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Action Items',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _addActionItem,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: mediumSeaGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, size: 12, color: mediumSeaGreen),
                      SizedBox(width: 4),
                      Text(
                        'Add Task',
                        style: TextStyle(
                          fontSize: 10,
                          color: mediumSeaGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_actionItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid,
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      color: Colors.grey.shade300,
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No action items yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._actionItems.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: mediumSeaGreen.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: mediumSeaGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: mediumSeaGreen,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _removeActionItem(entry.key),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _addActionItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Action Item',
          style: TextStyle(fontSize: 13),
        ),
        content: TextField(
          controller: _actionItemController,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            hintText: 'Enter action item',
            hintStyle: TextStyle(fontSize: 10),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 11)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_actionItemController.text.trim().isNotEmpty) {
                setState(() {
                  _actionItems.add(_actionItemController.text.trim());
                  _actionItemController.clear();
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
            ),
            child: const Text('Add', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _removeActionItem(int index) {
    setState(() {
      _actionItems.removeAt(index);
    });
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Below Average';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}


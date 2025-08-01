import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../utils/responsive_utils.dart';

class ProfileDialog extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onUserUpdated;
  final Color? themeColor;

  const ProfileDialog({
    super.key,
    required this.user,
    required this.onUserUpdated,
    this.themeColor,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool isEditing = false;
  late TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // Check if current user is admin
  bool get isAdmin => widget.user.role.toLowerCase() == 'admin';

  void _saveChanges() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final updatedUser = widget.user.copyWith(name: nameController.text.trim());

    // Update parent UI immediately
    widget.onUserUpdated(updatedUser);

    // Close the dialog first
    Navigator.pop(context);

    // Show loading indicator while updating
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Updating profile...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );

    // Update in database
    final success = await userProvider.updateUser(updatedUser);

    // Check if widget is still mounted before accessing context
    if (!mounted) return;

    // Clear the loading message
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show result message
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // If update failed, revert the UI change
      widget.onUserUpdated(widget.user);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: ${userProvider.error ?? 'Unknown error'}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showEditRestrictedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile editing is restricted. Please contact your administrator to make changes.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: context.dialogWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Only show edit button for admins
                  if (isAdmin)
                    IconButton(
                      onPressed: () {
                        if (isEditing) {
                          _saveChanges();
                        } else {
                          setState(() {
                            isEditing = true;
                          });
                        }
                      },
                      icon: Icon(
                        isEditing ? Icons.save : Icons.edit,
                        color: widget.themeColor ?? Colors.indigo,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _showEditRestrictedMessage,
                      icon: Icon(
                        Icons.edit_off,
                        color: Colors.grey[400],
                      ),
                      tooltip: 'Editing restricted - Contact admin',
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileField(
                        label: 'Name',
                        value: widget.user.name,
                        controller: nameController,
                        isEditable: isAdmin,
                      ),
                      const SizedBox(height: 12),
                      _buildProfileField(
                        label: 'Email',
                        value: widget.user.email,
                        isEditable: false,
                      ),
                      const SizedBox(height: 12),
                      _buildProfileField(
                        label: 'Phone',
                        value: widget.user.phoneNumber,
                        isEditable: false,
                      ),
                      const SizedBox(height: 12),
                      _buildProfileField(
                        label: 'Role',
                        value: widget.user.role.toUpperCase(),
                        isEditable: false,
                      ),
                      // Role-specific fields
                      if (widget.user.employeeId != null) ...[
                        const SizedBox(height: 12),
                        _buildProfileField(
                          label: 'Employee ID',
                          value: widget.user.employeeId!,
                          isEditable: false,
                        ),
                      ],
                      if (widget.user.company != null) ...[
                        const SizedBox(height: 12),
                        _buildProfileField(
                          label: 'Company',
                          value: widget.user.company!,
                          isEditable: false,
                        ),
                      ],
                      if (widget.user.address != null) ...[
                        const SizedBox(height: 12),
                        _buildProfileField(
                          label: 'Address',
                          value: widget.user.address!,
                          isEditable: false,
                        ),
                      ],
                      if (widget.user.accountNo != null) ...[
                        const SizedBox(height: 12),
                        _buildProfileField(
                          label: 'Account No',
                          value: widget.user.accountNo!,
                          isEditable: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Add info message for non-admin users
              if (!isAdmin) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To update your profile information, please contact your administrator.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    TextEditingController? controller,
    bool isEditable = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        if (isEditable && isEditing && isAdmin)
          TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}
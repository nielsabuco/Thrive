import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class PersonalInfoScreen extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const PersonalInfoScreen({
    super.key,
    required this.onProfileUpdated,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final Color thriveGreen = const Color(0xFF40983D);
  final Color thriveLightGreen = const Color(0xFF70B644);
  final Color thriveCard = const Color(0xFFF6F8F5);
  final Color thriveTextGrey = const Color(0xFF777777);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _nameController.text = user.displayName ?? (user.email?.split('@').first ?? 'User');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('phone')) {
          _phoneController.text = data['phone'] ?? '';
        }
        if (data.containsKey('bio')) {
          _bioController.text = data['bio'] ?? '';
        } else {
          _bioController.text = 'Grow through every little step.';
        }
      } else {
        _bioController.text = 'Grow through every little step.';
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      final newBio = _bioController.text.trim();

      // Update Firebase Auth display name
      await user.updateDisplayName(newName);

      // Update Cloud Firestore user document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'email': user.email,
        'phone': newPhone,
        'bio': newBio,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      widget.onProfileUpdated();

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal information updated successfully!'),
            backgroundColor: Color(0xFF40983D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personal Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.close : Icons.edit_note,
                color: thriveGreen,
              ),
              tooltip: _isEditing ? 'Cancel Edit' : 'Edit Information',
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _loadUserData(); // reset changes if canceled
                  }
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF40983D)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar Banner
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor: const Color(0xFFE1F0DF),
                                  child: Icon(
                                    Icons.person,
                                    size: 58,
                                    color: thriveGreen,
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: thriveGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'Thrive Member',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: thriveTextGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Section Title
                      Text(
                        _isEditing ? 'Edit Profile Details' : 'Account Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: thriveGreen,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isEditing) ...[
                        // Edit Mode Fields
                        _buildEditableField(
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name cannot be empty';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildReadOnlyField(
                          label: 'Email Address',
                          icon: Icons.mail_outline,
                          value: user?.email ?? 'Not available',
                          note: 'Email is linked to your Firebase account.',
                        ),
                        const SizedBox(height: 16),

                        _buildEditableField(
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          hint: 'e.g. +63 912 345 6789',
                        ),
                        const SizedBox(height: 16),

                        _buildEditableField(
                          label: 'Personal Motto / Goal',
                          icon: Icons.format_quote_outlined,
                          controller: _bioController,
                          maxLines: 2,
                          hint: '“Grow through every little step.”',
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, color: Colors.white),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: thriveGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // View Mode Cards
                        _buildInfoCard(
                          icon: Icons.badge_outlined,
                          title: 'Full Name',
                          value: _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Not set',
                        ),
                        _buildInfoCard(
                          icon: Icons.email_outlined,
                          title: 'Email Address',
                          value: user?.email ?? 'Not set',
                        ),
                        _buildInfoCard(
                          icon: Icons.phone_android_outlined,
                          title: 'Phone Number',
                          value: _phoneController.text.isNotEmpty
                              ? _phoneController.text
                              : 'Not added yet',
                        ),
                        _buildInfoCard(
                          icon: Icons.favorite_border,
                          title: 'Daily Motto',
                          value: _bioController.text.isNotEmpty
                              ? '“${_bioController.text}”'
                              : '“Grow through every little step.”',
                        ),
                        _buildInfoCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'Member Since',
                          value: user?.metadata.creationTime != null
                              ? '${user!.metadata.creationTime!.year}-${user.metadata.creationTime!.month.toString().padLeft(2, '0')}-${user.metadata.creationTime!.day.toString().padLeft(2, '0')}'
                              : 'Recent',
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Notification & Alarm Settings Section
                      Text(
                        'Alarms & Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: thriveGreen,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: thriveCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2EBE0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1F0DF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.alarm, color: thriveGreen),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Exact Time Reminders',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Rings and alerts your phone at the exact scheduled minute.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF777777),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await NotificationService().showTestNotification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '🔔 Test notification sent! Check your phone notification tray.',
                                        ),
                                        backgroundColor: Color(0xFF40983D),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.notifications_active),
                                label: const Text('Test Phone Alarm Notification'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: thriveGreen,
                                  side: BorderSide(color: thriveGreen),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: thriveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: thriveGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: thriveTextGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: thriveGreen),
        filled: true,
        fillColor: thriveCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2EBE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: thriveGreen, width: 2),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: thriveTextGrey),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: thriveTextGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                note,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


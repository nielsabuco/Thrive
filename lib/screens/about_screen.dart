import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final Color thriveGreen = const Color(0xFF40983D);
  final Color thriveLightGreen = const Color(0xFF70B644);
  final Color thriveCard = const Color(0xFFF6F8F5);
  final Color thriveTextGrey = const Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About THRIVE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // App Icon with glow/circle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F0DF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF70B644), width: 2),
                ),
                child: const Icon(
                  Icons.eco,
                  size: 64,
                  color: Color(0xFF40983D),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'THRIVE',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                  color: Color(0xFF40983D),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Daily Reminder & Routine Companion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF70B644),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 11, color: Color(0xFF555555)),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                '“Grow through every little step.”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: thriveGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Purpose Card
              _buildSectionCard(
                icon: Icons.lightbulb_outline,
                title: 'Our Purpose',
                content:
                    'THRIVE is designed to empower you to build lasting habits, balance healthy lifestyle choices, organize productive study and work schedules, and celebrate daily progress without feeling overwhelmed.',
              ),
              const SizedBox(height: 14),

              // Key Features Card
              _buildSectionCard(
                icon: Icons.star_outline,
                title: 'Key Capabilities',
                content:
                    '• Exact Alarm Alerts: Ring and notify on time with high-priority audio & vibration.\n'
                    '• Smart Categories: Separate and focus on Health, Study, Work, and Personal reminders.\n'
                    '• Cloud Sync: Securely stored in Google Cloud Firestore with Firebase Auth.\n'
                    '• Flexible Scheduling: Daily recurring tasks, specific dates, or weekly milestones.\n'
                    '• Daily Focus Mode: Instantly view what needs your attention today.',
              ),
              const SizedBox(height: 14),

              // Battery & Alarm Tip
              _buildSectionCard(
                icon: Icons.alarm_on,
                title: 'Ensuring Accurate Alarms',
                content:
                    'For exact on-the-minute alarms, ensure THRIVE has permission to send notifications and schedule exact alarms in your Android System Settings.',
              ),
              const SizedBox(height: 28),

              // Credits & Copyright
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Crafted with ❤️ for mindful daily living',
                style: TextStyle(fontSize: 12, color: thriveTextGrey),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2026 THRIVE Team. All rights reserved.',
                style: TextStyle(fontSize: 11, color: thriveTextGrey),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: thriveCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F0DF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: thriveGreen),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }
}


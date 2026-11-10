import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/personal_info_screen.dart';
import 'screens/about_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification initialization note: $e');
  }

  runApp(const ThriveApp());
}

// ==================== COLORS ====================

const Color thriveGreen = Color(0xFF40983D);
const Color thriveLightGreen = Color(0xFF70B644);
const Color thriveGrey = Color(0xFFDADADA);
const Color thriveCard = Color(0xFFF0F0F0);
const Color thriveTextGrey = Color(0xFF777777);

// ==================== APP ====================

class ThriveApp extends StatelessWidget {
  const ThriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'THRIVE - Daily Reminder App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: thriveGreen),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // Responsive width: full width on phones, max 500 on tablets/desktop
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },

      home: const AuthGate(),
    );
  }
}

// ==================== AUTH GATE ====================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: thriveGreen),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final displayName = user.displayName?.isNotEmpty == true
              ? user.displayName!
              : (user.email?.split('@').first ?? 'Friend');
          return HomeScreen(username: displayName);
        }

        return const LoginScreen();
      },
    );
  }
}

// ==================== REMINDER MODEL ====================

class Reminder {
  String id;
  String title;
  DateTime date;
  TimeOfDay time;
  String category;
  String repeat;
  bool completed;
  bool enabled;

  Reminder({
    this.id = '',
    required this.title,
    required this.date,
    required this.time,
    required this.category,
    required this.repeat,
    this.completed = false,
    this.enabled = true,
  });

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final dateTimestamp = data['date'] as Timestamp?;
    final dateTime = dateTimestamp != null ? dateTimestamp.toDate() : DateTime.now();
    final hour = data['timeHour'] as int? ?? 8;
    final minute = data['timeMinute'] as int? ?? 0;

    return Reminder(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      date: dateTime,
      time: TimeOfDay(hour: hour, minute: minute),
      category: data['category'] as String? ?? 'Personal',
      repeat: data['repeat'] as String? ?? 'Never',
      completed: data['completed'] as bool? ?? false,
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'category': category,
      'repeat': repeat,
      'completed': completed,
      'enabled': enabled,
    };
  }

  DateTime get scheduledDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  bool get isOverdue {
    if (completed || !enabled) return false;
    return DateTime.now().isAfter(scheduledDateTime);
  }

  String get statusText {
    if (completed) return 'Completed';
    if (!enabled) return 'Disabled';

    final now = DateTime.now();
    final scheduled = scheduledDateTime;

    if (now.isAfter(scheduled)) {
      final diff = now.difference(scheduled);
      final minutes = diff.inMinutes;
      final hours = diff.inHours;
      final days = diff.inDays;

      if (minutes < 1) {
        return 'Late just now';
      } else if (minutes < 60) {
        return 'Late by $minutes min${minutes == 1 ? '' : 's'}';
      } else if (hours < 24) {
        return 'Late by $hours hr${hours == 1 ? '' : 's'}';
      } else {
        final remainingHours = hours % 24;
        if (days < 7 && remainingHours > 0) {
          return 'Late by $days day${days == 1 ? '' : 's'}, $remainingHours hr${remainingHours == 1 ? '' : 's'}';
        }
        return 'Late by $days day${days == 1 ? '' : 's'}';
      }
    } else {
      final diff = scheduled.difference(now);
      final minutes = diff.inMinutes;
      final hours = diff.inHours;
      final days = diff.inDays;

      if (minutes < 60) {
        return 'Due in $minutes min${minutes == 1 ? '' : 's'}';
      } else if (hours < 24) {
        return 'Due in $hours hr${hours == 1 ? '' : 's'}';
      } else {
        return 'Due in $days day${days == 1 ? '' : 's'}';
      }
    }
  }

  Color get statusColor {
    if (completed) return const Color(0xFF40983D);
    if (!enabled) return const Color(0xFF999999);
    if (isOverdue) return const Color(0xFFD32F2F);
    return const Color(0xFF2E7D32);
  }

  Color get statusBgColor {
    if (completed) return const Color(0xFFE8F5E9);
    if (!enabled) return const Color(0xFFEEEEEE);
    if (isOverdue) return const Color(0xFFFFEBEE);
    return const Color(0xFFF1F8E9);
  }
}

// ==================== LOGIN SCREEN ====================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Navigation is automatically handled by AuthGate
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please check your credentials.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is badly formatted.';
      } else if (e.code == 'network-request-failed' ||
          (e.message != null && e.message!.contains('Failed to connect'))) {
        message =
            'Unable to reach Firebase servers. Please verify your phone is connected to working Wi-Fi or mobile data.';
      } else if (e.message != null) {
        message = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Failed to connect') ||
            msg.contains('SocketException') ||
            msg.contains('network')) {
          msg =
              'Network error: Unable to connect to the internet. Please connect your phone to working Wi-Fi and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.eco,
                  size: 76,
                  color: thriveLightGreen,
                ),
                const SizedBox(height: 8),
                const Text(
                  'THRIVE',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: thriveGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Daily Reminder App',
                  style: TextStyle(color: thriveGreen, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text(
                  '“Grow through every little step.”',
                  style: TextStyle(color: thriveGreen, fontSize: 12),
                ),
                const SizedBox(height: 42),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: inputDecoration(
                    'Email Address',
                    Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: inputDecoration(
                    'Password',
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => hidePassword = !hidePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: greenButtonStyle(),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Login'),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: thriveTextGrey,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(text: "Don't have an account?  "),
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SIGN UP SCREEN ====================

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save user display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // AuthGate handles going to HomeScreen
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please log in.';
      } else if (e.code == 'weak-password') {
        message = 'The password provided is too weak (minimum 6 characters).';
      } else if (e.code == 'network-request-failed' ||
          (e.message != null && e.message!.contains('Failed to connect'))) {
        message =
            'Unable to reach Firebase servers. Please verify your phone is connected to working Wi-Fi or mobile data.';
      } else if (e.message != null) {
        message = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Failed to connect') ||
            msg.contains('SocketException') ||
            msg.contains('network')) {
          msg =
              'Network error: Unable to connect to the internet. Please connect your phone to working Wi-Fi and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 18),
            const Icon(Icons.eco, size: 70, color: thriveGreen),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Join THRIVE',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: thriveGreen,
                ),
              ),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              decoration: inputDecoration(
                'Full Name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: inputDecoration(
                'Email Address',
                Icons.mail_outline,
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: hidePassword,
              decoration: inputDecoration(
                'Password',
                Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => hidePassword = !hidePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 26),

            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: greenButtonStyle(),
                onPressed: isLoading ? null : createAccount,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HOME SCREEN ====================

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;

  String get firstName {
    final user = FirebaseAuth.instance.currentUser;
    final value = (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : widget.username)
        .trim();
    if (value.isEmpty) return 'Friend';
    return value[0].toUpperCase() + value.substring(1);
  }

  void changeTab(int index) {
    setState(() => selectedTab = index);
  }

  CollectionReference? get remindersRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('reminders');
  }

  void openAddReminder({Reminder? reminder}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(existingReminder: reminder),
      ),
    );
  }

  void openDetails(Reminder reminder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderDetailsScreen(
          reminder: reminder,
          onEdit: () => openAddReminder(reminder: reminder),
        ),
      ),
    );
  }

  Future<void> toggleReminder(Reminder reminder, bool value) async {
    final ref = remindersRef;
    if (ref != null && reminder.id.isNotEmpty) {
      await ref.doc(reminder.id).update({'completed': value});
      if (value) {
        await NotificationService().cancelReminder(reminder.id.hashCode);
      } else if (reminder.enabled) {
        await NotificationService().scheduleReminder(
          id: reminder.id.hashCode,
          title: reminder.title,
          category: reminder.category,
          date: reminder.date,
          time: reminder.time,
          repeat: reminder.repeat,
        );
      }
    }
  }

  Future<void> deleteReminder(Reminder reminder) async {
    final ref = remindersRef;
    if (ref != null && reminder.id.isNotEmpty) {
      await NotificationService().cancelReminder(reminder.id.hashCode);
      await ref.doc(reminder.id).delete();
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final ref = remindersRef;

    return StreamBuilder<QuerySnapshot>(
      stream: ref?.snapshots(),
      builder: (context, snapshot) {
        final List<Reminder> allReminders = [];
        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            allReminders.add(Reminder.fromFirestore(doc));
          }
        }

        if (selectedTab == 1) {
          return RemindersScreen(
            reminders: allReminders,
            onAdd: () => openAddReminder(),
            onOpen: openDetails,
            onToggle: toggleReminder,
            onDelete: deleteReminder,
            selectedTab: selectedTab,
            onTabChanged: changeTab,
          );
        }

        if (selectedTab == 2) {
          final user = FirebaseAuth.instance.currentUser;
          final currentDisplayName = user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : widget.username;
          return ProfileScreen(
            username: currentDisplayName,
            onLogout: logout,
            selectedTab: selectedTab,
            onTabChanged: changeTab,
            onProfileUpdated: () {
              setState(() {});
            },
          );
        }

        final today = DateTime.now();

        final todayReminders = allReminders.where((r) {
          return sameDay(r.date, today);
        }).toList()
          ..sort((a, b) => timeInMinutes(a.time).compareTo(timeInMinutes(b.time)));

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good Morning,\n$firstName!',
                                  style: const TextStyle(
                                    color: thriveGreen,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Ready to thrive today?',
                                  style: TextStyle(
                                    color: thriveGreen,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => changeTab(2),
                            icon: const Icon(Icons.account_circle_outlined),
                            iconSize: 30,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: thriveCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 24),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDate(today),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: thriveTextGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Your Reminders',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: thriveGreen),
                          ),
                        )
                      else if (todayReminders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(
                            child: Text(
                              'No reminders for today.',
                              style: TextStyle(color: thriveTextGrey),
                            ),
                          ),
                        ),

                      ...todayReminders.map(
                        (reminder) => ReminderCard(
                          reminder: reminder,
                          onTap: () => openDetails(reminder),
                          onToggle: (value) => toggleReminder(reminder, value),
                          onDelete: () => deleteReminder(reminder),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: greenButtonStyle(),
                          onPressed: () => openAddReminder(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Reminder'),
                        ),
                      ),
                    ],
                  ),
                ),
                BottomNavigation(
                  selectedIndex: selectedTab,
                  onSelected: changeTab,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== MY REMINDERS SCREEN ====================

class RemindersScreen extends StatelessWidget {
  final List<Reminder> reminders;
  final VoidCallback onAdd;
  final ValueChanged<Reminder> onOpen;
  final void Function(Reminder, bool) onToggle;
  final ValueChanged<Reminder> onDelete;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const RemindersScreen({
    super.key,
    required this.reminders,
    required this.onAdd,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final todayList = reminders.where((r) => sameDay(r.date, today)).toList()
      ..sort((a, b) => timeInMinutes(a.time).compareTo(timeInMinutes(b.time)));

    final tomorrowList =
        reminders.where((r) => sameDay(r.date, tomorrow)).toList()
          ..sort(
            (a, b) => timeInMinutes(a.time).compareTo(timeInMinutes(b.time)),
          );

    final laterList = reminders.where((r) {
      final dateOnly = DateTime(r.date.year, r.date.month, r.date.day);
      final tomorrowOnly = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );
      return dateOnly.isAfter(tomorrowOnly);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_none, size: 27),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'My Reminders',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onAdd,
                        icon: const Icon(
                          Icons.add_circle,
                          color: thriveGreen,
                          size: 27,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Today', style: sectionHeading()),
                  Text(
                    formatDate(today),
                    style: const TextStyle(
                      color: thriveTextGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (todayList.isEmpty)
                    const Text(
                      'No reminders for today.',
                      style: TextStyle(color: thriveTextGrey),
                    ),

                  ...todayList.map(
                    (r) => ReminderCard(
                      reminder: r,
                      onTap: () => onOpen(r),
                      onToggle: (value) => onToggle(r, value),
                      onDelete: () => onDelete(r),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Tomorrow', style: sectionHeading()),
                  Text(
                    formatDate(tomorrow),
                    style: const TextStyle(
                      color: thriveTextGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (tomorrowList.isEmpty)
                    const Text(
                      'No reminders for tomorrow.',
                      style: TextStyle(color: thriveTextGrey),
                    ),

                  ...tomorrowList.map(
                    (r) => ReminderCard(
                      reminder: r,
                      onTap: () => onOpen(r),
                      onToggle: (value) => onToggle(r, value),
                      onDelete: () => onDelete(r),
                    ),
                  ),

                  if (laterList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Upcoming', style: sectionHeading()),
                    const SizedBox(height: 12),
                    ...laterList.map(
                      (r) => ReminderCard(
                        reminder: r,
                        onTap: () => onOpen(r),
                        onToggle: (value) => onToggle(r, value),
                        onDelete: () => onDelete(r),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            BottomNavigation(
              selectedIndex: selectedTab,
              onSelected: onTabChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ADD / EDIT REMINDER ====================

class AddReminderScreen extends StatefulWidget {
  final Reminder? existingReminder;

  const AddReminderScreen({
    super.key,
    this.existingReminder,
  });

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final titleController = TextEditingController();

  late DateTime selectedDate;
  TimeOfDay? selectedTime;
  String category = 'Study';
  String repeat = 'Every Day';
  bool isSaving = false;

  final categories = ['Study', 'Health', 'Personal'];

  final repeats = [
    'Never',
    'Every Day',
    'Every Week',
    'Every Month',
  ];

  @override
  void initState() {
    super.initState();

    final existing = widget.existingReminder;

    if (existing != null) {
      titleController.text = existing.title;
      selectedDate = existing.date;
      selectedTime = existing.time;
      category = existing.category;
      repeat = existing.repeat;
    } else {
      selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: thriveGreen),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> saveReminder() async {
    if (titleController.text.trim().isEmpty || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a title and select a time.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save reminders.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders');

      final newReminder = Reminder(
        title: titleController.text.trim(),
        date: selectedDate,
        time: selectedTime!,
        category: category,
        repeat: repeat,
        completed: widget.existingReminder?.completed ?? false,
        enabled: widget.existingReminder?.enabled ?? true,
      );

      String reminderId = widget.existingReminder?.id ?? '';
      if (widget.existingReminder != null && widget.existingReminder!.id.isNotEmpty) {
        await ref.doc(widget.existingReminder!.id).update(newReminder.toMap());
      } else {
        final docRef = await ref.add({
          ...newReminder.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        reminderId = docRef.id;
      }

      // Schedule exact alarm notification on device
      final notifId = reminderId.hashCode;
      if (newReminder.enabled && !newReminder.completed) {
        await NotificationService().scheduleReminder(
          id: notifId,
          title: newReminder.title,
          category: newReminder.category,
          date: newReminder.date,
          time: newReminder.time,
          repeat: newReminder.repeat,
        );
      } else {
        await NotificationService().cancelReminder(notifId);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save reminder: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingReminder != null;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          editing ? 'Edit Reminder' : 'Add Reminder',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Reminder Title',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: inputDecoration(
                'e.g. Read my notes',
                Icons.menu_book_outlined,
              ),
            ),

            const SizedBox(height: 18),
            const Text(
              'Date',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            pickerTile(
              icon: Icons.calendar_month,
              text: formatDate(selectedDate),
              onTap: pickDate,
            ),

            const SizedBox(height: 18),
            const Text(
              'Time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            pickerTile(
              icon: Icons.access_time,
              text: selectedTime?.format(context) ?? 'Select time',
              onTap: pickTime,
            ),

            const SizedBox(height: 22),
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Row(
              children: categories.map((item) {
                final selected = category == item;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => category = item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE1F0DF)
                              : thriveGrey,
                          borderRadius: BorderRadius.circular(14),
                          border: selected
                              ? Border.all(color: thriveGreen, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              categoryIcon(item),
                              size: 25,
                              color: selected ? thriveGreen : Colors.black,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? thriveGreen
                                    : thriveTextGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),
            const Text(
              'Repeat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: thriveGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: repeat,
                  isExpanded: true,
                  items: repeats.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Row(
                        children: [
                          const Icon(Icons.autorenew, size: 20),
                          const SizedBox(width: 12),
                          Text(item),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => repeat = value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: greenButtonStyle(),
                onPressed: isSaving ? null : saveReminder,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(editing ? 'Update' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REMINDER DETAILS ====================

class ReminderDetailsScreen extends StatefulWidget {
  final Reminder reminder;
  final VoidCallback onEdit;

  const ReminderDetailsScreen({
    super.key,
    required this.reminder,
    required this.onEdit,
  });

  @override
  State<ReminderDetailsScreen> createState() =>
      _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  DocumentReference? get docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.reminder.id.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reminders')
        .doc(widget.reminder.id);
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.reminder;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Reminder Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: thriveGreen,
              child: Icon(
                categoryIcon(reminder.category),
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reminder.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: reminder.statusBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: reminder.statusColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reminder.isOverdue
                          ? Icons.warning_amber_rounded
                          : (reminder.completed
                              ? Icons.check_circle_outline
                              : Icons.schedule),
                      size: 14,
                      color: reminder.statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      reminder.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: reminder.statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: thriveGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  detailRow(
                    Icons.history_toggle_off,
                    'Status',
                    reminder.statusText,
                  ),
                  detailRow(
                    Icons.calendar_month,
                    'Date',
                    formatDate(reminder.date),
                  ),
                  detailRow(
                    Icons.access_time,
                    'Time',
                    reminder.time.format(context),
                  ),
                  detailRow(
                    categoryIcon(reminder.category),
                    'Category',
                    reminder.category,
                  ),
                  detailRow(
                    Icons.autorenew,
                    'Repeat',
                    reminder.repeat,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.notifications_none, size: 21),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Reminder Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Switch(
                        value: reminder.enabled,
                        activeThumbColor: Colors.white,
                        activeTrackColor: thriveGreen,
                        onChanged: (value) async {
                          setState(() => reminder.enabled = value);
                          await docRef?.update({'enabled': value});
                          if (value && !reminder.completed) {
                            await NotificationService().scheduleReminder(
                              id: reminder.id.hashCode,
                              title: reminder.title,
                              category: reminder.category,
                              date: reminder.date,
                              time: reminder.time,
                              repeat: reminder.repeat,
                            );
                          } else {
                            await NotificationService().cancelReminder(reminder.id.hashCode);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: greenButtonStyle(),
                onPressed: reminder.completed
                    ? null
                    : () async {
                        setState(() => reminder.completed = true);
                        await docRef?.update({'completed': true});
                        await NotificationService().cancelReminder(reminder.id.hashCode);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reminder marked as done!'),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                child: Text(
                  reminder.completed ? 'Completed' : 'Mark as Done',
                ),
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onEdit();
                      });
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: thriveGrey,
                      foregroundColor: Colors.black,
                      side: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete Reminder'),
                          content: const Text(
                            'Are you sure you want to delete this reminder?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, false);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, true);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await docRef?.delete();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: thriveGrey,
                      foregroundColor: Colors.black,
                      side: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: thriveGrey,
                  foregroundColor: thriveGreen,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PROFILE SCREEN ====================

class ProfileScreen extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.onLogout,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'My Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),

                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: Color(0xFFE1F0DF),
                    child: Icon(
                      Icons.person,
                      size: 54,
                      color: thriveGreen,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    username,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (user?.email != null)
                    Text(
                      user!.email!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: thriveTextGrey,
                      ),
                    ),

                  const SizedBox(height: 28),
                  profileItem(
                    Icons.person_outline,
                    'Personal Information',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalInfoScreen(
                            onProfileUpdated: onProfileUpdated,
                          ),
                        ),
                      );
                    },
                  ),
                  profileItem(
                    Icons.notifications_outlined,
                    'My Reminders',
                    onTap: () => onTabChanged(1),
                  ),
                  profileItem(
                    Icons.eco_outlined,
                    'About THRIVE',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: thriveGreen,
                        side: const BorderSide(color: thriveGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            BottomNavigation(
              selectedIndex: selectedTab,
              onSelected: onTabChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REMINDER CARD ====================

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: thriveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: reminder.completed,
            onChanged: (value) => onToggle(value ?? false),
            activeColor: thriveGreen,
            shape: const CircleBorder(),
          ),
          Icon(categoryIcon(reminder.category), size: 20),
          const SizedBox(width: 10),

          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: reminder.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(reminder.date)} • '
                      '${reminder.time.format(context)}',
                      style: const TextStyle(
                        color: thriveTextGrey,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(categoryIcon(reminder.category), size: 13, color: thriveGreen),
                        const SizedBox(width: 5),
                        Text(
                          reminder.category,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: reminder.statusBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: reminder.statusColor.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (reminder.isOverdue) ...[
                                Icon(Icons.warning_amber_rounded, size: 10, color: reminder.statusColor),
                                const SizedBox(width: 3),
                              ] else if (reminder.completed) ...[
                                Icon(Icons.check, size: 10, color: reminder.statusColor),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                reminder.statusText,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: reminder.statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'details') onTap();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'details',
                child: Text('View Details'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== BOTTOM NAVIGATION ====================

class BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            navItem(Icons.home, 'Home', 0),
            navItem(Icons.notifications, 'Reminders', 1),
            navItem(Icons.person_outline, 'Profile', 2),
          ],
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    final selected = selectedIndex == index;
    final color = selected ? thriveGreen : thriveTextGrey;

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 25, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== REUSABLE WIDGETS ====================

InputDecoration inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: thriveTextGrey,
      fontSize: 12,
    ),
    prefixIcon: Icon(
      icon,
      size: 19,
      color: const Color(0xFF444444),
    ),
    filled: true,
    fillColor: thriveGrey,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: thriveGreen,
        width: 1.5,
      ),
    ),
  );
}

ButtonStyle greenButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: thriveGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  );
}

Widget pickerTile({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: thriveGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF444444)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: thriveTextGrey,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 21),
        ],
      ),
    ),
  );
}

Widget detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF444444)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget profileItem(IconData icon, String title, {VoidCallback? onTap}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: thriveCard,
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, color: thriveGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: thriveTextGrey),
          ],
        ),
      ),
    ),
  );
}

// ==================== HELPER FUNCTIONS ====================

IconData categoryIcon(String category) {
  switch (category) {
    case 'Study':
      return Icons.school;
    case 'Health':
      return Icons.water_drop;
    case 'Personal':
      return Icons.person_outline;
    default:
      return Icons.notifications_none;
  }
}

TextStyle sectionHeading() {
  return const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  );
}

bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}

String formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

int timeInMinutes(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

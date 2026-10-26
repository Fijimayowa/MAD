import 'package:flutter/material.dart';

import 'tip_service.dart';

void main() {
  runApp(const MyApp());
}

// 🧓 Great-Grandparent
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun Signup App',
      // Visual theme choice: a Material 3 color scheme generated from one seed color
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: const SignupPage(),
    );
  }
}

// The four situations the tip feature can be in
enum TipStatus { idle, loading, success, error }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // 🔑 The Global Key - acts like a remote control for the form
  final _formKey = GlobalKey<FormState>();

  // 📝 Controllers to track what the user types
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 🤖 AI Signup Coach state (Task A)
  // Swap MockTipService() for HttpTipService('https://...') once you have the instructor URL.
  final TipService _tipService = MockTipService();
  TipStatus _tipStatus = TipStatus.idle;
  String _tip = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadTip() async {
    setState(() => _tipStatus = TipStatus.loading);
    try {
      final tip = await _tipService.fetchTip();
      if (!mounted) return;
      setState(() {
        _tip = tip.length > 240 ? tip.substring(0, 240) : tip;
        _tipStatus = TipStatus.success;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tipStatus = TipStatus.error);
    }
  }

  Widget _buildTipArea() {
    switch (_tipStatus) {
      case TipStatus.idle:
        return TextButton(
          onPressed: _loadTip,
          child: const Text('Get a signup tip'),
        );
      case TipStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        );
      case TipStatus.success:
        return Column(
          children: [
            Text(
              _tipService.isMock
                  ? 'Mock tip (no live AI called):'
                  : 'AI-generated advice:',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            // Plain Text widget: the AI response is displayed, never trusted or run
            Text(_tip, textAlign: TextAlign.center),
            TextButton(onPressed: _loadTip, child: const Text('New tip')),
          ],
        );
      case TipStatus.error:
        return Column(
          children: [
            const Text("Couldn't get a tip right now."),
            TextButton(onPressed: _loadTip, child: const Text('Retry')),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👨 Parent
      appBar: AppBar(
        title: const Text('Join Us Today for the Cash Money!'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          // 👶 Child
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 👤 Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 📧 Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 🔒 Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 🚀 Sign Up Button (validation stays local; the AI tip never affects it)
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Demo signup complete — your form passed validation!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 16),

              // 🤖 AI Signup Coach
              _buildTipArea(),
            ],
          ),
        ),
      ),
    );
  }
}

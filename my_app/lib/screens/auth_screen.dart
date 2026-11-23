import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const roles = ['student', 'instructor', 'other']; // confirm values with instructor
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String _role = roles.first;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return; // blocks double submit
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        final user = await AuthService.instance.register(
          email: _email.text,
          password: _password.text,
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
        );
        await BoardService.instance.saveUserRecord(
          uid: user.uid,
          firstName: _first.text,
          lastName: _last.text,
          role: _role,
        );
      } else {
        await AuthService.instance.signIn(email: _email.text, password: _password.text);
      }
      // AuthGate routes to the board on its own via authStateChanges().
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Create account' : 'Sign in')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(children: [
                if (_register) ...[
                  TextFormField(
                    controller: _first,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: _required,
                  ),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                          ? 'Enter a valid email'
                          : null,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_register ? 'Register' : 'Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                  child: Text(_register ? 'Have an account? Sign in' : 'New here? Create an account'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}

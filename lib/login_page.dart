import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true; // <-- To toggle password visibility

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user != null) {
          await supabase.from('users').upsert({
            'id': user.id,
            'email': user.email,
          });
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserListPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed')),
          );
        }
      } else {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user != null) {
          await supabase.from('users').insert({
            'id': user.id,
            'email': user.email,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up successful! Please check your email for confirmation.')),
          );
          setState(() {
            _isLogin = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up failed')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleFormMode() => setState(() => _isLogin = !_isLogin);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_isLogin ? 'Login' : 'Create Account'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? 'Login' : 'Create Account'),
                    ),
              TextButton(
                onPressed: _toggleFormMode,
                child: Text(
                  _isLogin
                      ? "Don't have an account? Create one"
                      : "Already have an account? Login",
                ),
              ),
            ],
          ),
        ),
      );
}

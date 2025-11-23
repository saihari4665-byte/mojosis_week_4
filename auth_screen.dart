// In lib/auth_screen.dart
import 'package:flutter/material.dart';
// 1. Import Firebase packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 2. Add a loading state
  bool _isLoading = false;

  // 3. Get the Firebase Auth instance
  final _auth = FirebaseAuth.instance;

  // --- THIS IS THE UPDATED FUNCTION ---
  void _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }

    // Close the keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true; // Show loading spinner
    });

    try {
      UserCredential userCredential;

      if (_isLogin) {
        // --- Log in user ---
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // --- Sign up user ---
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // --- 4. CREATE USER DOCUMENT IN FIRESTORE ---
        // This is the most important part for Step 1!
        // We create a new 'users' collection and add a document
        // with the user's unique ID.
        await FirebaseFirestore.instance
            .collection('users') // Create/use a 'users' collection
            .doc(userCredential.user!.uid) // Use the new user's ID as the doc name
            .set({
          'email': _emailController.text.trim(),
          'rating': 1200, // Starting rating
          'puzzles_solved': 0,
          'win_streak': 0,
          'created_at': Timestamp.now(), // Good to know when they joined
        });
      }

      // If successful, the StreamBuilder in main.dart will automatically
      // navigate to the MainMenuScreen. No navigation code needed here!

    } on FirebaseAuthException catch (error) {
      // 5. Handle errors
      String message = 'An error occurred, please check your credentials.';
      if (error.message != null) {
        message = error.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      print(error);
    }

    if (mounted) {
      setState(() {
        _isLoading = false; // Hide loading spinner
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Create Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 6) {
                        return 'Password must be at least 6 characters long.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  // --- 6. Show loading spinner on button ---
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLogin ? 'Login' : 'Sign Up',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  const SizedBox(height: 16),

                  if (!_isLoading) // Hide toggle button when loading
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Sign Up'
                            : 'Already have an account? Login',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
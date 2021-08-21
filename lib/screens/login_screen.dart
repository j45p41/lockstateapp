import 'package:flutter/material.dart';
import 'package:lockstate/authentication/authentication.controller.dart';
import 'package:lockstate/screens/signup_screen.dart';
import 'package:momentum/momentum.dart';

import '../main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String email = '';
  String password = '';
  final _formKey = GlobalKey<FormState>();
  login() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final authController =
          Momentum.controller<AuthenticationController>(context);
      authController.login(email, password);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => Authenticate(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) => SignupScreen(),
                ));
              },
              child: Text("Signup"))
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Email",
                ),
                onSaved: (newValue) => email = newValue!,
              ),
              TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Password",
                ),
                onSaved: (newValue) => password = newValue!,
              ),
              ElevatedButton(
                onPressed: login,
                child: Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

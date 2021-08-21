import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/main.dart';
import 'package:momentum/momentum.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String email = '';
  String password = '';
  String username = '';
  final _formKey = GlobalKey<FormState>();
  signup() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final authController =
          Momentum.controller<AuthenticationController>(context);
      print("signup screen " + email + " " + password + " " + username);
      authController.signup(email, password, username);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => Authenticate(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Signup"),
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
                  hintText: "Username",
                ),
                onSaved: (newValue) => username = newValue!,
              ),
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
                onPressed: signup,
                child: Text("Signup"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

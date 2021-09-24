import 'package:flutter/material.dart';
import 'package:lockstate/authentication/authentication.controller.dart';
import 'package:lockstate/screens/signup_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
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
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 30,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Log in",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: Color(
                      ColorUtils.color4,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 30,
              ),
              TextFormField(
                style: TextStyle(color: Color(ColorUtils.color4)),
                decoration: InputDecoration(
                  fillColor: Color(ColorUtils.color2),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Enter your email address",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),

                ),
                onSaved: (newValue) => email = newValue!,
              ),
              SizedBox(
                height: 5,
              ),
              TextFormField(
                style: TextStyle(color: Color(ColorUtils.color4)),
                decoration: InputDecoration(
                  fillColor: Color(ColorUtils.color2),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Enter you password",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),
                ),
                onSaved: (newValue) => password = newValue!,
              ),
              SizedBox(
                height: 40,
              ),
              GestureDetector(
                onTap: login,
                child: Container(
                  child: Center(
                    child: Text(
                      "Log in",
                      style: TextStyle(
                        color: Color(
                          ColorUtils.color4,
                        ),
                      ),
                    ),
                  ),
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Color(ColorUtils.color3),
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Dont have an account?",
                    style: TextStyle(
                      color: Color(
                        ColorUtils.color4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => SignupScreen(),
                      ));
                    },
                    child: Text(
                      "Signup",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

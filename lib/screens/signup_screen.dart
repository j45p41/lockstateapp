import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/main.dart';
import 'package:lockstate/screens/login_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
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
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              SizedBox(
                height: 30,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Sign up",
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
                  hintText: "Enter a username",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),
                ),
                onSaved: (newValue) => username = newValue!,
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
                  hintText: "Enter your password",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),
                ),
                onSaved: (newValue) => password = newValue!,
              ),
              SizedBox(
                height: 40,
              ),
              GestureDetector(
                onTap: signup,
                child: Container(
                  child: Center(
                    child: Text(
                      "Sign up",
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
                    "Already have an account?",
                    style: TextStyle(
                      color: Color(
                        ColorUtils.color4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ));
                    },
                    child: Text(
                      "Login",
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

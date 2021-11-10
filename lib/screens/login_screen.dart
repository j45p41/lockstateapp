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
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover)),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: 100,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                    child: Image.asset(
                      "assets/images/logo.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: 30,
                ),
                TextFormField(
                  style: TextStyle(color: Color(ColorUtils.colorWhite)),
                  decoration: InputDecoration(
                    labelText: "Email",
                    enabledBorder: UnderlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white,
                          width: 1,
                          style: BorderStyle.solid),
                    ),
                    labelStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: "Enter your email address",
                    hintStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                  ),
                  onSaved: (newValue) => email = newValue!,
                ),
                SizedBox(
                  height: 5,
                ),
                TextFormField(
                  style: TextStyle(color: Color(ColorUtils.colorWhite)),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                    labelText: "Password",
                    enabledBorder: UnderlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white,
                          width: 1,
                          style: BorderStyle.solid),
                    ),
                    border: UnderlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white,
                          width: 1,
                          style: BorderStyle.solid),
                    ),
                    hintText: "Enter you password",
                    hintStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
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
                            ColorUtils.colorWhite,
                          ),
                        ),
                      ),
                    ),
                    padding: EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Color(ColorUtils.color3),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => SignupScreen(),
                    ));
                  },
                  child: Container(
                    child: Center(
                      child: Text(
                        "Register",
                        style: TextStyle(
                          color: Color(
                            ColorUtils.colorWhite,
                          ),
                        ),
                      ),
                    ),
                    padding: EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Color(ColorUtils.colorGrey),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Color(
                          ColorUtils.colorWhite,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "Click here",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(
            Icons.arrow_back_ios_new,
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
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
                    labelText: "Username",
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
                    hintText: "Enter your username",
                    hintStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                  ),
                  onSaved: (newValue) => username = newValue!,
                ),
                SizedBox(
                  height: 5,
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
                  onTap: signup,
                  child: Container(
                    child: Center(
                      child: Text(
                        "Sign up",
                        style: TextStyle(
                          color: Color(
                            ColorUtils.colorWhite,
                          ),
                        ),
                      ),
                    ),
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Color(ColorUtils.color2),
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
                          ColorUtils.colorWhite,
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
      ),
    );
  }
}

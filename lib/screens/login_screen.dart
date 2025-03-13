import 'package:flutter/material.dart';
import 'package:lockstate/authentication/authentication.controller.dart';
import 'package:lockstate/screens/signup_screen.dart';
import 'package:lockstate/screens/forgot_password_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String password = '';
  final _formKey = GlobalKey<FormState>();
  login() async{
    if (globals.email.isEmpty) {
      print('Please Enter Username');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Enter Username"),
        ),
      );
      // Handle no password case (e.g., show an error message)
      return;
    }

    if (password.isEmpty) {
      print('No password supplied');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Enter a Password"),
        ),
      );
      // Handle no password case (e.g., show an error message)
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
       final authController =
      Momentum.controller<AuthenticationController>(context);
       authController.login(globals.email, password);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => const Authenticate(),
      ));
    }

          print('userID is:');
      print(FirebaseAuth.instance.currentUser!.email.toString());


    // if (globals.snapdata == "null") {


    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //           'Authentication Error: Please Check username and password and try again'),
    //     ),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        body: Container(
          height: MediaQuery.of(context).size.height * .90,
          decoration: const BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover)),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 100,
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(10),
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
                    const SizedBox(
                      height: 30,
                    ),
                    TextFormField(
                      style: const TextStyle(color: Color(ColorUtils.colorWhite)),
                      decoration: InputDecoration(
                        labelText: "Email",
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1,
                              style: BorderStyle.solid),
                        ),
                        labelStyle:
                            const TextStyle(color: Color(ColorUtils.colorWhite)),
                        border: UnderlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: "Enter your email address",
                        hintStyle:
                            const TextStyle(color: Color(ColorUtils.colorWhite)),
                      ),
                      initialValue: globals.email,
                      onChanged: (value) => globals.email = value,
                      onSaved: (newValue) => globals.email = newValue!,
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    TextFormField(
                      style: const TextStyle(color: Color(ColorUtils.colorWhite)),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelStyle:
                            const TextStyle(color: Color(ColorUtils.colorWhite)),
                        labelText: "Password",
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1,
                              style: BorderStyle.solid),
                        ),
                        border: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1,
                              style: BorderStyle.solid),
                        ),
                        hintText: "Enter your password",
                        hintStyle:
                            const TextStyle(color: Color(ColorUtils.colorWhite)),
                      ),
                      onSaved: (newValue) => password = newValue!,
                      onChanged: (newValue) => password = newValue,
                    ),
                    const SizedBox(
                      height: 40,
                    ),
                    GestureDetector(
                      onTap: login,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: const Color(ColorUtils.color3),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                          child: Text(
                            "Log in",
                            style: TextStyle(
                              color: Color(
                                ColorUtils.colorWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: const Color(ColorUtils.colorGrey),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                          child: Text(
                            "Register",
                            style: TextStyle(
                              color: Color(
                                ColorUtils.colorWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(
                              ColorUtils.colorWhite,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return const forgot_password_screen();
                              },
                            ));
                          },
                          child: const Text(
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
        ));
  }
}

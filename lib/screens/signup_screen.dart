import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/main.dart';
import 'package:lockstate/screens/login_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;


class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String password = '';
  String username = '';
  final _formKey = GlobalKey<FormState>();
  signup() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final authController =
          Momentum.controller<AuthenticationController>(context);
      print("signup screen ${globals.email} $password $username");

      if (globals.email .isEmpty) {
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

      try {
        authController.signup(globals.email, password, username);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const Authenticate(),
        ));
      } on Exception catch (e) {
        print('AUTH EXCEPTION');
        // Check for user already exists error (if applicable)
        if (e.toString().contains('user-already-exists')) {
          print('User already exists');
          // Handle user already exists case (e.g., show an error message)
        } else {
          print(e.toString());
        }
      }
      
                if(globals.snapdata=="null"){

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Locksure'),
        ),
      );

          }


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Icon(
              Icons.arrow_back_ios_new,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
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
                    // TextFormField(
                    //   style: TextStyle(color: Color(ColorUtils.colorWhite)),
                    //   // decoration: InputDecoration(
                    //   //   labelText: "Username",
                    //   //   enabledBorder: UnderlineInputBorder(
                    //   //     borderRadius: BorderRadius.circular(10),
                    //   //     borderSide: BorderSide(
                    //   //         color: Colors.white,
                    //   //         width: 1,
                    //   //         style: BorderStyle.solid),
                    //   //   ),
                    //   //   labelStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                    //   //   border: UnderlineInputBorder(
                    //   //     borderSide: BorderSide(color: Colors.white, width: 1),
                    //   //     borderRadius: BorderRadius.circular(10),
                    //   //   ),
                    //   //   hintText: "Enter your username",
                    //   //   hintStyle: TextStyle(color: Color(ColorUtils.colorWhite)),
                    //   // ),
                    //   onSaved: (newValue) => username = newValue!,
                    // ),
                    const SizedBox(
                      height: 5,
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
                        hintText: "Enter you password",
                        hintStyle:
                            const TextStyle(color: Color(ColorUtils.colorWhite)),
                      ),
                      onSaved: (newValue) => password = newValue!,
                    ),
                    const SizedBox(
                      height: 40,
                    ),
                    GestureDetector(
                      onTap: signup,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: const Color(ColorUtils.color2),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                          child: Text(
                            "Sign up",
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
                          "Already have an account?",
                          style: TextStyle(
                            color: Color(
                              ColorUtils.colorWhite,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pushReplacement(MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ));
                          },
                          child: const Text(
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
        ));
  }
}

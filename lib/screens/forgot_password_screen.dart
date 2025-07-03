import 'package:flutter/material.dart';
import 'package:lockstate/authentication/authentication.controller.dart';
import 'package:lockstate/screens/login_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

class forgot_password_screen extends StatefulWidget {
  const forgot_password_screen({Key? key}) : super(key: key);

  @override
  _forgot_password_screen createState() => _forgot_password_screen();
}

class _forgot_password_screen extends State<forgot_password_screen> {
  String password = '';
  final _formKey = GlobalKey<FormState>();

  Future passwordReset() async {
    print("email: ");
    print(globals.email);
    // 1. Validate email format
    final form = _formKey.currentState;
    if (!form!.validate()) {
      return; // Don't proceed if form is invalid
    }

    // 2. Access Authentication Service (assuming you have one)
    final authService = Momentum.controller<AuthenticationController>(context);

    // 3. Send password reset email using your authentication service
    try {
      await authService.sendPasswordResetEmail(globals.email);

      // Check if widget is still mounted before using context
      if (!mounted) return;

      if (!globals.emailSucess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(globals.e?.message ?? 'An error occurred'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email Sent - please check your inbox"),
          ),
        );
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ));
      }

      if (globals.e?.message.toString() == 'Password Reset Email Sent') {
        print('SUCESS CASE');
      }
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
        ),
      );
    }
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
                    const Text(
                      "Please Enter Your Email and we will send you a Password Reset Link",
                      style: TextStyle(
                        color: Color(
                          ColorUtils.colorWhite,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    TextFormField(
                      style:
                          const TextStyle(color: Color(ColorUtils.colorWhite)),
                      decoration: InputDecoration(
                        labelText: "Email",
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1,
                              style: BorderStyle.solid),
                        ),
                        labelStyle: const TextStyle(
                            color: Color(ColorUtils.colorWhite)),
                        border: UnderlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: "Enter your email address",
                        hintStyle: const TextStyle(
                            color: Color(ColorUtils.colorWhite)),
                      ),
                      // onSaved: (newValue) => email = newValue!,
                      onChanged: (newValue) => globals.email = newValue,
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    // TextFormField(
                    //   style: TextStyle(color: Color(ColorUtils.colorWhite)),
                    //   obscureText: true,
                    //   decoration: InputDecoration(
                    //     labelStyle:
                    //         TextStyle(color: Color(ColorUtils.colorWhite)),
                    //     labelText: "Password",
                    //     enabledBorder: UnderlineInputBorder(
                    //       borderRadius: BorderRadius.circular(10),
                    //       borderSide: BorderSide(
                    //           color: Colors.white,
                    //           width: 1,
                    //           style: BorderStyle.solid),
                    //     ),
                    //     border: UnderlineInputBorder(
                    //       borderRadius: BorderRadius.circular(10),
                    //       borderSide: BorderSide(
                    //           color: Colors.white,
                    //           width: 1,
                    //           style: BorderStyle.solid),
                    //     ),
                    //     hintText: "Enter your password",
                    //     hintStyle:
                    //         TextStyle(color: Color(ColorUtils.colorWhite)),
                    //   ),
                    //   onSaved: (newValue) => password = newValue!,
                    // ),
                    const SizedBox(
                      height: 40,
                    ),
                    GestureDetector(
                      onTap: passwordReset,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: const Color(ColorUtils.color3),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                          child: Text(
                            "Reset Password",
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
                    // GestureDetector(
                    //   onTap: () {
                    //     Navigator.of(context).push(MaterialPageRoute(
                    //       builder: (context) => SignupScreen(),
                    //     ));
                    //   },
                    //   child: Container(
                    //     child: Center(
                    //       child: Text(
                    //         "Register",
                    //         style: TextStyle(
                    //           color: Color(
                    //             ColorUtils.colorWhite,
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //     padding: EdgeInsets.all(12),
                    //     width: double.infinity,
                    //     decoration: BoxDecoration(
                    //         color: Color(ColorUtils.colorGrey),
                    //         borderRadius: BorderRadius.circular(8)),
                    //   ),
                    // ),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     Text(
                    //       "Forgot Password?",
                    //       style: TextStyle(
                    //         color: Color(
                    //           ColorUtils.colorWhite,
                    //         ),
                    //       ),
                    //     ),
                    //     TextButton(
                    //       onPressed: () {},
                    //       child: Text(
                    //         "Click here",
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}

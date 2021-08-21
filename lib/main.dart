import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/screens/home_screen.dart';
import 'package:lockstate/screens/login_screen.dart';
import 'package:lockstate/services/auth_service.dart';
import 'package:lockstate/services/fcm_service.dart';
import 'package:lockstate/services/firestore_service.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

String? fcmId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(momentum());

  fcmId = await FirebaseMessaging.instance.getToken();
  print('fcmId ' + fcmId.toString());
}

Momentum momentum() {
  return Momentum(
    key: UniqueKey(),
    restartCallback: main,
    controllers: [
      AuthenticationController(),
      DataController(),
    ],
    services: [
      AuthService(),
      FcmService(),
      FirestoreService(),
    ],
    child: MyApp(),
  );
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        backgroundColor: Color(ColorUtils.color1),
        primaryColor: Color(ColorUtils.color2),
        accentColor: Color(ColorUtils.color4),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: Authenticate(),
    );
  }
}

class Authenticate extends StatelessWidget {
  const Authenticate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          print("Authenticate " + snapshot.data.toString());
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return snapshot.data != null ? HomeScreen() : LoginScreen();
        });
  }
}

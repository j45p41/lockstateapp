import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/screens/home_screen.dart';
import 'package:lockstate/screens/login_screen.dart';
import 'package:lockstate/screens/select_connection_type_screen.dart';
import 'package:lockstate/services/auth_service.dart';
import 'package:lockstate/services/fcm_service.dart';
import 'package:lockstate/services/firestore_service.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;


String? fcmId;
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("background message ${message.data}");

  await Firebase.initializeApp();
}

void main() async {


  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp();



  print('RUNNING NOTIFCATION API');
  FcmService().startFCMService;
  // await FirebaseApi().initNotifications();
  runApp(momentum());

  // await FirebaseMessaging.instance.requestPermission();

  fcmId = await FirebaseMessaging.instance.getToken();
  print('fcmId $fcmId');
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
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(ColorUtils.color1),
        primaryColor: const Color(ColorUtils.color2),
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(ColorUtils.color4)),
      ),
      // home: IntroScreen(),
      home: const HomeScreen(),
    );
  }
}

class Authenticate extends StatefulWidget {
  const Authenticate({Key? key}) : super(key: key);

  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  bool isConnectionTypeSet = true;
  getUser() async {
    if (FirebaseAuth.instance.currentUser != null) {
      print("getUser auth");

      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();


      print("*******getUser auth************ ${doc['connectionType']}");
      setState(() {
        isConnectionTypeSet =
            doc['connectionType'] == "NOT_SELECTED" ? false : true;
      });
    }
  }

  @override
  void initState() {
    FcmService().startFCMService(context);
    getUser();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          print("Authenticate ${snapshot.data}");

 globals.snapdata = snapshot.data.toString();

          const HomeScreen();
          isConnectionTypeSet = true;

          // if (snapshot.connectionState == ConnectionState.waiting) {
          //   return Scaffold(
          //     body: Center(
          //       child: CircularProgressIndicator(),
          //     ),
          //   );
          // }
          return snapshot.data != null
              ? isConnectionTypeSet
                  ? const HomeScreen()
                  : const SelectConnectionScreen()
              : const LoginScreen();
        });


  }


}



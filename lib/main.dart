import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockstate/screens/add_device_screen.dart';
import 'package:lockstate/screens/device_detail_screen.dart';
import 'package:lockstate/screens/home_screen.dart';
import 'package:lockstate/screens/mqtt_test.dart';
import 'package:lockstate/utils/color_utils.dart';

void main() {
  runApp(MyApp());
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
      home: AddDeviceScreen(),
    );
  }
}

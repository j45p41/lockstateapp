import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

double _currentSliderValue = 10;

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return MomentumBuilder(
        controllers: [AuthenticationController, DataController],
        builder: (context, snapshot) {
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          return Scaffold(
            backgroundColor: Color(ColorUtils.colorDarkGrey),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Color(ColorUtils.colorDarkGrey),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(
                    ColorUtils.colorWhite,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  width: 100,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5)),
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(
                  width: 10,
                )
              ],
              centerTitle: false,
            ),
            body: Column(children: [
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.red,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.green,
                ),
                title: Text(
                  "Colour Scheme 1: RED/GREEN",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.blue,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.amber,
                ),
                title: Text(
                  "Colour Scheme 2: BLUE/AMBER",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.cyan,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.pinkAccent,
                ),
                title: Text(
                  "Colour Scheme 3: CYAN/MAGENTA",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.brightness_low,
                  color: Colors.white,
                ),
                trailing: Icon(
                  Icons.brightness_high,
                  color: Colors.white,
                ),
                title: Text(
                  "Mini-Hub Brightness",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Slider(
                value: _currentSliderValue,
                max: 100,
                divisions: 5,
                label: _currentSliderValue.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    _currentSliderValue = value;
                  });
                },
              ),
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.volume_mute,
                  color: Colors.white,
                ),
                trailing: Icon(
                  Icons.volume_up,
                  color: Colors.white,
                ),
                title: Text(
                  "Mini-Hub Volume",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Slider(
                value: _currentSliderValue,
                max: 100,
                divisions: 5,
                label: _currentSliderValue.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    _currentSliderValue = value;
                  });
                },
              ),
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.swap_horiz,
                  color: Colors.white,
                ),
                trailing: ButtonTheme(
                  minWidth: (1000),
                  height: 100.0,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Text("INVERT"),
                    style: ElevatedButton.styleFrom(
                        primary: Colors.redAccent,
                        padding:
                            EdgeInsets.symmetric(horizontal: 45, vertical: 15),
                        textStyle: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                title: Text(
                  "Swap Lock/Unlock",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(
                height: 100,
              ),
              Column(
                children: [
                  ButtonTheme(
                    minWidth: (5000),
                    height: 100.0,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: Text("LOGOUT"),
                      style: ElevatedButton.styleFrom(
                          primary: Colors.redAccent,
                          padding: EdgeInsets.symmetric(
                              horizontal: 100, vertical: 15),
                          textStyle: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Column()
            ]),
          );
        });
  }
}

import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

bool gotSettings = false;

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

double brightnessSliderSetting = 90;
double brightnessAlertSliderSetting = 75;
double volumeSliderSetting = 40;
double sentLightSetting = 2;

Color _colorGreen = Color.fromARGB(0, 255, 255, 255);
Color _colorBlue = Color.fromARGB(0, 255, 255, 255);
Color _colorCyan = Color.fromARGB(0, 255, 255, 255);

final List<bool> _selectedFruits = <bool>[true, false];

const List<Widget> icons = <Widget>[
  Icon(Icons.arrow_left),
  Icon(Icons.arrow_right),
];
bool vertical = false;
int doorStateInvert = 0;

double titleSize = 20;
int lastIndex = 0;

// Future<QuerySnapshot> getDocuments() async {
//   return await FirebaseFirestore.instance
//       .collection('users')
//       .doc(FirebaseAuth.instance.currentUser!.uid.toString())
//       .collection('devices')
//       .get();
// }

class _SettingsScreenState extends State<SettingsScreen> {
  void getSettingsFromFirestore() async {
    // getInitialSettings(); //temp

    print('Getting Settings from Firestore');

    sentLightSetting = 0;

    // print(FirebaseAuth.instance.currentUser!.uid.toString());
    // print(device.deviceId);

    int deviceIndex = 0;

    final db = FirebaseFirestore.instance;
    var result = await db
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid.toString())
        .collection('devices')
        .get();
    result.docs.forEach((res) {
      print(res.id);

      FirebaseFirestore.instance
          .collection('devices')
          .doc(res.id.toString())
          .get()
          .then((value) {
        print(value.get('brightnessSliderSetting'));
        // brightnessSliderSetting =
        //     double.parse(value.get('brightnessSliderSetting'));

        // brightnessSliderSetting = value.get('brightnessSliderSetting');

        if (!globals.gotSettings) {
          print('LIGHTSETTING:');
          print(value.get('lightSetting'));
          // sentLightSetting = value.get('lightSetting');
          globals.lightSetting = value.get('lightSetting').toInt();

          setState(() {
            if (globals.lightSetting == 1) {
              _colorGreen = Color.fromARGB(73, 255, 7, 7);
              _colorCyan = Color.fromARGB(0, 255, 255, 255);
              _colorBlue = Color.fromARGB(0, 255, 255, 255);
            } else if (globals.lightSetting == 2) {
              _colorBlue = Color.fromARGB(73, 255, 7, 7);
              _colorCyan = Color.fromARGB(0, 255, 255, 255);
              _colorGreen = Color.fromARGB(0, 255, 255, 255);
            } else if (globals.lightSetting == 3) {
              _colorCyan = Color.fromARGB(73, 255, 7, 7);
              _colorBlue = Color.fromARGB(0, 255, 255, 255);
              _colorGreen = Color.fromARGB(0, 255, 255, 255);
            }

            brightnessSliderSetting = value.get('brightnessSliderSetting');
            brightnessAlertSliderSetting =
                value.get('brightnessAlertSliderSetting');
            volumeSliderSetting = value.get('volumeSliderSetting');

            print(value.get('doorStateInvert'));

            if (value.get('doorStateInvert') == 1) {
              doorStateInvert = 0;
              _selectedFruits[0] = true;
              _selectedFruits[1] = false;
              lastIndex = 1;
              print('TRUE');
            } else {
              doorStateInvert = 1;
              _selectedFruits[0] = false;
              _selectedFruits[1] = true;
              lastIndex = 0;
              print('FALSE');
            }
          });
        }
        globals.gotSettings = true;
      });

      // FirebaseFirestore.instance
      //     .collection('devices')
      //     .doc(res.id.toString())
      //     .get()
      //     .then((value) {
      //   print(value.get('doorStateInvert'));
      //   // doorStateInvert = value.get('doorStateInvert');
      // });
    });
  }

  @override
  Widget build(BuildContext context) {
    // getSettingsFromFirestore();S
    // globals.gotSettings = false;

    print('Widget build(BuildContext context) {');
    return MomentumBuilder(
        controllers: [AuthenticationController, DataController],
        builder: (context, snapshot) {
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          // getInitialSettings();

          getSettingsFromFirestore();

          return Scaffold(
            backgroundColor: Color.fromARGB(255, 43, 43, 43),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Color.fromARGB(255, 43, 43, 43),
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
                    vertical: 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  width: 200,
                  height: 100,
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
              const SizedBox(
                height: 10,
              ),
              Text(
                "Setting take effect on next operation",
                style: TextStyle(color: Colors.white, fontSize: titleSize),
              ),
              const SizedBox(
                height: 10,
              ),
              ListTile(
                tileColor: _colorGreen,
                onTap: () async {
                  setState(() {
                    _colorGreen = Color.fromARGB(73, 255, 7, 7);
                    _colorBlue = Color.fromARGB(0, 255, 255, 255);
                    _colorCyan = Color.fromARGB(0, 255, 255, 255);
                    globals.lightSetting = 1;
                    globals.gotLightSettings = false;
                  });

                  print('Getting Settings from Firestore');

                  // print(FirebaseAuth.instance.currentUser!.uid.toString());
                  // print(device.deviceId);

                  // getInitialSettings(); //temp
                  print('RED/GREEN Pressed');

                  print(FirebaseAuth.instance.currentUser!.uid.toString());
                  // print(device.deviceId);

                  final db = FirebaseFirestore.instance;
                  var result = await db
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid.toString())
                      .collection('devices')
                      .get();
                  result.docs.forEach((res) {
                    print(res.id);
                    sentLightSetting = 1;
                    FirebaseFirestore.instance
                        .collection('devices')
                        .doc(res.id.toString())
                        .update({'lightSetting': sentLightSetting});
                  });
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.green,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.red,
                ),
                title: new Center(
                    child: new Text(
                  "Green = Locked / Red = Unlocked",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              ListTile(
                tileColor: _colorBlue,
                onTap: () async {
                  setState(() {
                    _colorBlue = Color.fromARGB(73, 255, 7, 7);
                    _colorCyan = Color.fromARGB(0, 255, 255, 255);
                    _colorGreen = Color.fromARGB(0, 255, 255, 255);
                    globals.lightSetting = 2;
                    globals.gotLightSettings = false;
                  });
                  print('BLUE/MAGENTA Pressed');

                  print(FirebaseAuth.instance.currentUser!.uid.toString());
                  // print(device.deviceId);

                  final db = FirebaseFirestore.instance;
                  var result = await db
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid.toString())
                      .collection('devices')
                      .get();
                  result.docs.forEach((res) {
                    print(res.id);
                    sentLightSetting = 2;
                    FirebaseFirestore.instance
                        .collection('devices')
                        .doc(res.id.toString())
                        .update({'lightSetting': sentLightSetting});
                  });
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.blue,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.pinkAccent,
                ),
                title: new Center(
                    child: new Text(
                  "Blue = Locked / Magenta = Unlocked",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              ListTile(
                tileColor: _colorCyan,
                onTap: () async {
                  setState(() {
                    _colorCyan = Color.fromARGB(73, 255, 7, 7);
                    _colorBlue = Color.fromARGB(0, 255, 255, 255);
                    _colorGreen = Color.fromARGB(0, 255, 255, 255);
                    globals.lightSetting = 3;
                    globals.gotLightSettings = false;
                  });
                  print('CYAN/AMBER Pressed');

                  print(FirebaseAuth.instance.currentUser!.uid.toString());
                  // print(device.deviceId);

                  final db = FirebaseFirestore.instance;
                  var result = await db
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid.toString())
                      .collection('devices')
                      .get();
                  result.docs.forEach((res) {
                    print(res.id);
                    sentLightSetting = 3;

                    FirebaseFirestore.instance
                        .collection('devices')
                        .doc(res.id.toString())
                        .update({'lightSetting': sentLightSetting});
                  });
                },
                leading: Icon(
                  Icons.circle,
                  color: Colors.cyan,
                ),
                trailing: Icon(
                  Icons.circle,
                  color: Colors.amber,
                ),
                title: new Center(
                    child: new Text(
                  "Cyan = Locked / Amber = Unlocked",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                "Hub Brightness",
                style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              ),
              const SizedBox(
                height: 5,
              ),
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: Row(children: [
                    Expanded(
                        child: Column(children: [
                      Slider(
                        value: brightnessSliderSetting,
                        max: 100,
                        divisions: 5,
                        label: brightnessSliderSetting.round().toString(),
                        // onChangeStart: (value) async {
                        //   final db = FirebaseFirestore.instance;
                        //   var result = await db
                        //       .collection('users')
                        //       .doc(FirebaseAuth.instance.currentUser!.uid
                        //           .toString())
                        //       .collection('devices')
                        //       .get();
                        //   result.docs.forEach((res) {
                        //     print(res.id);

                        //     FirebaseFirestore.instance
                        //         .collection('devices')
                        //         .doc(res.id.toString())
                        //         .get()
                        //         .then((value) {
                        //       print(value.get('brightnessSliderSetting'));

                        //       setState(() {
                        //         brightnessSliderSetting =
                        //             value.get('brightnessSliderSetting');
                        //       });
                        //       value = value.get('brightnessSliderSetting');
                        //     });
                        //   });
                        // },
                        onChanged: (double value) {
                          setState(() {
                            brightnessSliderSetting = value;
                          });
                        },
                      )
                    ])),
                    Column(children: [
                      ElevatedButton(
                        onPressed: () async {
                          print('Brightness Pressed');

                          print(FirebaseAuth.instance.currentUser!.uid
                              .toString());
                          // print(device.deviceId);

                          final db = FirebaseFirestore.instance;
                          var result = await db
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid
                                  .toString())
                              .collection('devices')
                              .get();
                          result.docs.forEach((res) {
                            print(res.id);

                            FirebaseFirestore.instance
                                .collection('devices')
                                .doc(res.id.toString())
                                .update({
                              'brightnessSliderSetting': brightnessSliderSetting
                            });
                          });
                        },
                        child: Text("SET"),
                        style: ElevatedButton.styleFrom(
                            primary: Color.fromARGB(73, 255, 7, 7),
                            padding: EdgeInsets.symmetric(
                                horizontal: 5, vertical: 5),
                            textStyle: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ])),
              const SizedBox(
                height: 10,
              ),
              Text(
                "Hub Alert Brightness",
                style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              ),
              const SizedBox(
                height: 5,
              ),
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: Row(children: [
                    Expanded(
                        child: Column(children: [
                      Slider(
                        value: brightnessAlertSliderSetting,
                        max: 100,
                        divisions: 5,
                        label: brightnessAlertSliderSetting.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            brightnessAlertSliderSetting = value;
                          });
                        },
                      )
                    ])),
                    Column(children: [
                      ElevatedButton(
                        onPressed: () async {
                          print('brightnessAlertSliderSetting Pressed');

                          print(FirebaseAuth.instance.currentUser!.uid
                              .toString());
                          // print(device.deviceId);

                          final db = FirebaseFirestore.instance;
                          var result = await db
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid
                                  .toString())
                              .collection('devices')
                              .get();
                          result.docs.forEach((res) {
                            print(res.id);

                            FirebaseFirestore.instance
                                .collection('devices')
                                .doc(res.id.toString())
                                .update({
                              'brightnessAlertSliderSetting':
                                  brightnessAlertSliderSetting
                            });
                          });
                        },
                        child: Text("SET"),
                        style: ElevatedButton.styleFrom(
                            primary: Color.fromARGB(73, 255, 7, 7),
                            padding: EdgeInsets.symmetric(
                                horizontal: 5, vertical: 5),
                            textStyle: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ])),
              const SizedBox(
                height: 10,
              ),
              Text(
                "Audible Alert Interval (Minutes)",
                style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              ),
              const SizedBox(
                height: 5,
              ),
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: Row(children: [
                    Expanded(
                        child: Column(children: [
                      Slider(
                        value: volumeSliderSetting,
                        max: 60,
                        divisions: 6,
                        label: volumeSliderSetting.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            volumeSliderSetting = value;
                          });
                        },
                      )
                    ])),
                    Column(children: [
                      ElevatedButton(
                        onPressed: () async {
                          print('volumeSliderSetting Pressed');

                          print(FirebaseAuth.instance.currentUser!.uid
                              .toString());
                          // print(device.deviceId);

                          final db = FirebaseFirestore.instance;
                          var result = await db
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid
                                  .toString())
                              .collection('devices')
                              .get();
                          result.docs.forEach((res) {
                            print(res.id);

                            FirebaseFirestore.instance
                                .collection('devices')
                                .doc(res.id.toString())
                                .update({
                              'volumeSliderSetting': volumeSliderSetting
                            });
                          });
                        },
                        child: Text("SET"),
                        style: ElevatedButton.styleFrom(
                            primary: Color.fromARGB(73, 255, 7, 7),
                            padding: EdgeInsets.symmetric(
                                horizontal: 5, vertical: 5),
                            textStyle: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ])),
              const SizedBox(
                height: 10,
              ),
              ListTile(
                onTap: () {
                  print('Pressed');
                },
                leading: Icon(
                  Icons.swap_horiz,
                  color: Colors.white,
                ),
                trailing: ToggleButtons(
                  direction: vertical ? Axis.vertical : Axis.horizontal,
                  onPressed: (int index) async {
                    setState(() {
                      // The button that is tapped is set to true, and the others to false.
                      for (int i = 0; i < _selectedFruits.length; i++) {
                        _selectedFruits[i] = i == index;
                        lastIndex = index;
                      }
                    });

                    if (lastIndex == 1) {
                      print('doorStateInvert FALSE Pressed');

                      doorStateInvert = 0;

                      print(FirebaseAuth.instance.currentUser!.uid.toString());
                      // print(device.deviceId);

                      final db = FirebaseFirestore.instance;
                      var result = await db
                          .collection('users')
                          .doc(
                              FirebaseAuth.instance.currentUser!.uid.toString())
                          .collection('devices')
                          .get();
                      result.docs.forEach((res) {
                        print(res.id);

                        FirebaseFirestore.instance
                            .collection('devices')
                            .doc(res.id.toString())
                            .update({'doorStateInvert': doorStateInvert});
                      });
                    } else {
                      print('doorStateInvert TRUE Pressed');

                      doorStateInvert = 1;

                      print(FirebaseAuth.instance.currentUser!.uid.toString());
                      // print(device.deviceId);

                      final db = FirebaseFirestore.instance;
                      var result = await db
                          .collection('users')
                          .doc(
                              FirebaseAuth.instance.currentUser!.uid.toString())
                          .collection('devices')
                          .get();
                      result.docs.forEach((res) {
                        print(res.id);

                        FirebaseFirestore.instance
                            .collection('devices')
                            .doc(res.id.toString())
                            .update({'doorStateInvert': doorStateInvert});
                      });
                    }
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  selectedBorderColor: Colors.blue[700],
                  selectedColor: Colors.white,
                  fillColor: Color.fromARGB(73, 255, 7, 7),
                  color: Color.fromARGB(73, 255, 7, 7),
                  isSelected: _selectedFruits,
                  children: icons,
                ),
                title: new Center(
                    child: new Text(
                  "Swap Lock/Unlock",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              const SizedBox(
                height: 10,
              ),
              Column(),
              Column(
                children: [
                  ButtonTheme(
                    minWidth: (5000),
                    height: 100.0,
                    child: ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                      },
                      child: Text("Logout"),
                      style: ElevatedButton.styleFrom(
                          primary: Color.fromARGB(73, 255, 7, 7),
                          padding: EdgeInsets.symmetric(
                              horizontal: 100, vertical: 15),
                          textStyle: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ]),
          );
        });
  }
}

void getInitialSettings() async {
  print("GETTING INTIAL SETTINGS");

  final db = FirebaseFirestore.instance;
  var result = await db
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid.toString())
      .collection('devices')
      .get();
  result.docs.forEach((res) async {
    print(res.id);

    var initialSettings = await db
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid.toString())
        .collection('devices')
        .doc(res.id.toString())
        .get();
    print("OUTPUT:");
    print(initialSettings.data().toString());
  });
}

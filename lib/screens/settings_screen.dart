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

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

double brightnessSliderSetting = 90;
double brightnessAlertSliderSetting = 75;
double volumeSliderSetting = 40;
double sentLightSetting = 2;

final List<bool> _selectedFruits = <bool>[true, false];

void getSettingsFromFirestore() async {
  // getInitialSettings(); //temp
  print('Getting Settings from Firestore');
  globals.lightSetting = 0;
  sentLightSetting = 0;

  print(FirebaseAuth.instance.currentUser!.uid.toString());
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
      print(value.get('lightSetting'));
      globals.lightSetting = value.get('lightSetting');
    });

    FirebaseFirestore.instance
        .collection('devices')
        .doc(res.id.toString())
        .get()
        .then((value) {
      print(value.get('volumeSliderSetting'));
      volumeSliderSetting =
          double.parse(value.get('volumeSliderSetting').toint());
    });

    FirebaseFirestore.instance
        .collection('devices')
        .doc(res.id.toString())
        .get()
        .then((value) {
      print(value.get('brightnessSliderSetting'));
      brightnessSliderSetting =
          double.parse(value.get('brightnessSliderSetting').toint());
    });

    FirebaseFirestore.instance
        .collection('devices')
        .doc(res.id.toString())
        .get()
        .then((value) {
      print(value.get('doorStateInvert'));
      doorStateInvert = value.get('doorStateInvert');
    });
    FirebaseFirestore.instance
        .collection('devices')
        .doc(res.id.toString())
        .get()
        .then((value) {
      print(value.get('brightnessAlertSliderSetting'));
      brightnessAlertSliderSetting =
          double.parse(value.get('brightnessAlertSliderSetting').toint());
    });
  });
}

const List<Widget> icons = <Widget>[
  Icon(Icons.arrow_left),
  Icon(Icons.arrow_right),
];
bool vertical = false;
bool doorStateInvert = false;

double titleSize = 15;
int lastIndex = 0;

// Future<QuerySnapshot> getDocuments() async {
//   return await FirebaseFirestore.instance
//       .collection('users')
//       .doc(FirebaseAuth.instance.currentUser!.uid.toString())
//       .collection('devices')
//       .get();
// }

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return MomentumBuilder(
        controllers: [AuthenticationController, DataController],
        builder: (context, snapshot) {
          getSettingsFromFirestore();
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
              const SizedBox(
                height: 10,
              ),
              Text(
                "Hub and Monitor Color Schemes",
                style: TextStyle(color: Colors.white, fontSize: titleSize),
              ),
              const SizedBox(
                height: 10,
              ),
              ListTile(
                onTap: () async {
                  // getInitialSettings(); //temp
                  print('RED/GREEN Pressed');
                  globals.lightSetting = 0;
                  sentLightSetting = 0;

                  print(FirebaseAuth.instance.currentUser!.uid.toString());
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
                  "GREEN LOCKED / RED UNLOCKED",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              ListTile(
                onTap: () async {
                  print('BLUE/AMBER Pressed');
                  globals.lightSetting = 2;
                  sentLightSetting = 2;

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
                  color: Colors.amber,
                ),
                title: new Center(
                    child: new Text(
                  "BLUE LOCKED / AMBER UNLOCKED",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              ListTile(
                onTap: () async {
                  print('CYAN/MAGENTA Pressed');
                  globals.lightSetting = 3;
                  sentLightSetting = 3;

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
                  color: Colors.pinkAccent,
                ),
                title: new Center(
                    child: new Text(
                  "CYAN LOCKED / MAGENTA UNLOCKED",
                  style:
                      TextStyle(color: Colors.white, fontSize: titleSize - 5),
                )),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                "Hub Brightness",
                style: TextStyle(color: Colors.white, fontSize: titleSize),
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
                            primary: Colors.redAccent,
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
                style: TextStyle(color: Colors.white, fontSize: titleSize),
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
                            primary: Colors.redAccent,
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
                "Hub Volume",
                style: TextStyle(color: Colors.white, fontSize: titleSize),
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
                        max: 100,
                        divisions: 5,
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
                            primary: Colors.redAccent,
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

                      doorStateInvert = false;

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

                      doorStateInvert = true;

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
                  fillColor: Colors.blue[200],
                  color: Colors.blue[400],
                  isSelected: _selectedFruits,
                  children: icons,
                ),
                title: new Center(
                    child: new Text(
                  "SWAP LOCK/UNLOCK",
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

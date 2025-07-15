import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

// Cloud‑Function that stores "this Firebase user ↔ Amazon account"
const String kAlexaLinkEndpoint =
    'https://us-central1-lockstate-e72fc.cloudfunctions.net/alexaLinkUser';

// Returns the user's rooms in the format
// [ { roomId:"frontDoorSensor", name:"Front Door" }, … ]
const String kListRoomsEndpoint =
    'https://us-central1-lockstate-e72fc.cloudfunctions.net/listRooms';

// Alexa gives you this under "Alexa Redirect URLs"
const String kAlexaRedirectUrl =
    'https://layla.amazon.com/api/skill/link/89751fb9-1b7f-4c40-8c9f-a5231bdb3998';

bool gotSettings = false;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

double brightnessSliderSetting = 90;
double brightnessAlertSliderSetting = 75;
double volumeSliderSetting = 40;
double sentLightSetting = 2;

Color _colorGreen = const Color.fromARGB(0, 255, 255, 255);
Color _colorBlue = const Color.fromARGB(0, 255, 255, 255);
Color _colorCyan = const Color.fromARGB(0, 255, 255, 255);

final List<bool> _selectedFruits = <bool>[true, false];

const List<Widget> icons = <Widget>[
  Icon(Icons.arrow_left),
  Icon(Icons.arrow_right),
];
bool vertical = false;
int doorStateInvert = 0;
bool isCancelled = false;

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
  late TextEditingController controller;
  late TextEditingController amazonUserIdController;
  String name = '';
  bool isAlexaLinked = false;
  String? amazonUserId;

  bool showSignalStrength = false;
  bool showBatteryPercentage = false;
  bool notificationsEnabled = true;
  List<int> allowedNotificationStates = [
    1,
    2
  ]; // Only Locked and Unlocked states

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
    for (var res in result.docs) {
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
          // print('LIGHTSETTING:');
          // print(value.get('lightSetting'));
          // sentLightSetting = value.get('lightSetting');
          globals.lightSetting = value.get('lightSetting').toInt();

          setState(() {
            if (globals.lightSetting == 1) {
              _colorGreen = const Color.fromARGB(73, 255, 7, 7);
              _colorCyan = const Color.fromARGB(0, 255, 255, 255);
              _colorBlue = const Color.fromARGB(0, 255, 255, 255);
            } else if (globals.lightSetting == 2) {
              _colorBlue = const Color.fromARGB(73, 255, 7, 7);
              _colorCyan = const Color.fromARGB(0, 255, 255, 255);
              _colorGreen = const Color.fromARGB(0, 255, 255, 255);
            } else if (globals.lightSetting == 3) {
              _colorCyan = const Color.fromARGB(73, 255, 7, 7);
              _colorBlue = const Color.fromARGB(0, 255, 255, 255);
              _colorGreen = const Color.fromARGB(0, 255, 255, 255);
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
    }
  }

  late PageController pageController;
  int currentIndex = 0;

  void loadUserSettings() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          globals.showSignalStrength =
              userDoc.data()?['showSignalStrength'] ?? false;
          globals.showBatteryPercentage =
              userDoc.data()?['showBatteryPercentage'] ?? false;
          amazonUserId = userDoc.data()?['amazonUserId'];
          if (amazonUserId != null) {
            amazonUserIdController.text = amazonUserId!;
          }
        });
      } else {
        // If user document doesn't exist, create it with default values
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .set({
          'showSignalStrength': false,
          'showBatteryPercentage': false,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  @override
  void initState() {
    pageController = PageController();
    controller = TextEditingController();
    amazonUserIdController = TextEditingController();
    loadUserSettings(); // Load settings when screen initializes
    super.initState();
    checkAlexaLinkStatus();
    loadSettings();
  }

  Future<void> checkAlexaLinkStatus() async {
    print('[Alexa] Checking Alexa link status...');
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      print('[Alexa] Firestore document retrieved: exists=${userDoc.exists}');
      final linkedStatus = userDoc.data()?['alexaLinked'];
      print('[Alexa] alexaLinked field: $linkedStatus');

      setState(() {
        isAlexaLinked = linkedStatus ?? false;
      });

      if (isAlexaLinked) {
        print('[Alexa] ✅ Alexa is linked.');
      } else {
        print('[Alexa] ❌ Alexa not linked.');
      }
    } catch (e) {
      print('[Alexa] ❌ Error checking Alexa link status: $e');
    }
  }

  /// Fetches all rooms for the current Firebase user.
  Future<List<Map<String, dynamic>>> _fetchUserRooms() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final res = await http.get(Uri.parse('$kListRoomsEndpoint?userId=$uid'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      print('[Alexa] room fetch failed: $e');
    }
    return [];
  }

  /// Registers the current Firebase user with the Alexa skill after the
  /// user has enabled the skill inside the Alexa app.
  Future<void> _registerAlexaLink() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    print('[Alexa] Registering Alexa link for Firebase UID: $userId');
    try {
      final res = await http.post(
        Uri.parse(kAlexaLinkEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (res.statusCode == 200) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'alexaLinked': true}, SetOptions(merge: true));

        setState(() => isAlexaLinked = true);
        // Fetch and log the user's doors
        final rooms = await _fetchUserRooms();
        print(
            '[Alexa] User has \\${rooms.length} door(s): \\${jsonEncode(rooms)}');
        print('[Alexa] ✅ Link registered with Cloud Function');
        // Warn if no rooms exist
        if (rooms.isEmpty) {
          print(
              '[Alexa] ⚠️ Warning: No rooms found for user. Please create a room/lock in the app.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Alexa linked, but no rooms found. Please create a room first.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print(
              '[Alexa] ✅ Found \\${rooms.length} room(s) ready for Alexa discovery');
        }
      } else {
        print('[Alexa] ❌ CF error \\${res.statusCode}: \\${res.body}');
      }
    } catch (e) {
      print('[Alexa] ❌ Failed to register link: $e');
    }
  }

  /// Clears the alexaLinked flag so the user can relink the skill.
  Future<void> _unlinkAlexaAccount() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'alexaLinked': false}, SetOptions(merge: true));

      setState(() => isAlexaLinked = false);
      print('[Alexa] 🔄 Link removed for $userId');
    } catch (e) {
      print('[Alexa] ❌ Failed to unlink: $e');
    }
  }

  Future<bool> verifyAlexaLinkage() async {
    try {
      // Replace this URL with your actual Alexa skill verification endpoint
      final response = await http.get(
        Uri.parse('https://your-api-endpoint/verify-alexa-link'),
        headers: {
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isLinked'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error verifying Alexa linkage: $e');
      return false;
    }
  }

  void debugAlexa(String message) {
    print('[ALEXA-DEBUG] ' + message);
  }

  Future<void> linkAlexaAccount() async {
    debugAlexa('--- Alexa linking started ---');

    // Check if user is signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugAlexa('User not signed in');
      await showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Sign In Required'),
          content: Text(
              'Please sign in or create an account in the app before linking with Alexa.'),
        ),
      );
      return;
    }
    final uid = user.uid;
    final firebaseEmail = user.email ?? '';
    debugAlexa(
        'User signed in: UID=\u001b[1m$uid\u001b[0m, email=$firebaseEmail');

    try {
      // Save the Alexa link status to Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'alexaLinked': true,
          'email': firebaseEmail,
          'uid': uid,
        }, SetOptions(merge: true));
        debugAlexa('Alexa link status written to Firestore');
      } catch (e) {
        debugAlexa('Error writing to Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Alexa link status: $e')),
        );
        return;
      }

      setState(() {
        amazonUserId = firebaseEmail;
      });

      // Show instructions dialog using Firebase email
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alexa Linking Instructions'),
          content: Text('Your Locksure email: $firebaseEmail\n\n'
              '1. Open the Alexa app on your phone.\n'
              '2. Search for the "Locksure" skill.\n'
              '3. Tap "Enable" to add the skill.\n'
              '4. When prompted, use the email above to log in.\n\n'
              'After linking, return to the Alexa app or say "Alexa, discover devices" to complete setup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugAlexa('Error linking account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to link Amazon account: $e')),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    amazonUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // getSettingsFromFirestore();S
    // globals.gotSettings = false;

    print('Widget build(BuildContext context) {');
    return MomentumBuilder(
        controllers: const [AuthenticationController, DataController],
        builder: (context, snapshot) {
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          // getInitialSettings();

          // getSettingsFromFirestore();

          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 43, 43, 43),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: const Color.fromARGB(255, 43, 43, 43),
              title: const Text(
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
                  margin: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  width: 160,
                  height: 80,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5)),
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(
                  width: 10,
                )
              ],
              centerTitle: false,
            ),
            body: Column(children: [
              const SizedBox(
                height: 10,
              ),
              // Text(
              //   "Settings take effect on next operation",
              //   style: TextStyle(color: Colors.white, fontSize: titleSize),
              // ),
              // const SizedBox(
              //   height: 10,
              // ),
              // const SizedBox(
              //   height: 10,
              // ),
              // Text(
              //   "Hub Brightness",
              //   style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              // ),
              // const SizedBox(
              //   height: 5,
              // ),
              // Container(
              //     padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              //     // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              //     child: Row(children: [
              //       Expanded(
              //           child: Column(children: [
              //         Slider(
              //           value: brightnessSliderSetting,
              //           max: 100,
              //           divisions: 5,
              //           label: brightnessSliderSetting.round().toString(),
              //           // onChangeStart: (value) async {
              //           //   final db = FirebaseFirestore.instance;
              //           //   var result = await db
              //           //       .collection('users')
              //           //       .doc(FirebaseAuth.instance.currentUser!.uid
              //           //           .toString())
              //           //       .collection('devices')
              //           //       .get();
              //           //   result.docs.forEach((res) {
              //           //     print(res.id);

              //           //     FirebaseFirestore.instance
              //           //         .collection('devices')
              //           //         .doc(res.id.toString())
              //           //         .get()
              //           //         .then((value) {
              //           //       print(value.get('brightnessSliderSetting'));

              //           //       setState(() {
              //           //         brightnessSliderSetting =
              //           //             value.get('brightnessSliderSetting');
              //           //       });
              //           //       value = value.get('brightnessSliderSetting');
              //           //     });
              //           //   });
              //           // },
              //           onChanged: (double value) {
              //             setState(() {
              //               brightnessSliderSetting = value;
              //             });
              //           },
              //         )
              //       ])),
              //       Column(children: [
              //         ElevatedButton(
              //           onPressed: () async {
              //             print('Brightness Pressed');

              //             print(FirebaseAuth.instance.currentUser!.uid
              //                 .toString());
              //             // print(device.deviceId);

              //             final db = FirebaseFirestore.instance;
              //             var result = await db
              //                 .collection('users')
              //                 .doc(FirebaseAuth.instance.currentUser!.uid
              //                     .toString())
              //                 .collection('devices')
              //                 .get();
              //             result.docs.forEach((res) {
              //               print(res.id);

              //               FirebaseFirestore.instance
              //                   .collection('devices')
              //                   .doc(res.id.toString())
              //                   .update({
              //                 'brightnessSliderSetting': brightnessSliderSetting
              //               });
              //             });
              //           },
              //           child: Text("SET"),
              //           style: ElevatedButton.styleFrom(
              //               backgroundColor: Color.fromARGB(73, 255, 7, 7),
              //               padding: EdgeInsets.symmetric(
              //                   horizontal: 5, vertical: 5),
              //               textStyle: TextStyle(
              //                   fontSize: 10, fontWeight: FontWeight.bold)),
              //         ),
              //       ]),
              //     ])),
              const SizedBox(
                height: 10,
              ),
              // Text(
              //   "Hub Alert Brightness",
              //   style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              // ),
              // const SizedBox(
              //   height: 5,
              // ),
              // Container(
              //     padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              //     // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              //     child: Row(children: [
              //       Expanded(
              //           child: Column(children: [
              //         Slider(
              //           value: brightnessAlertSliderSetting,
              //           max: 100,
              //           divisions: 5,
              //           label: brightnessAlertSliderSetting.round().toString(),
              //           onChanged: (double value) {
              //             setState(() {
              //               brightnessAlertSliderSetting = value;
              //             });
              //           },
              //         )
              //       ])),
              //       Column(children: [
              //         ElevatedButton(
              //           onPressed: () async {
              //             print('brightnessAlertSliderSetting Pressed');

              //             print(FirebaseAuth.instance.currentUser!.uid
              //                 .toString());
              //             // print(device.deviceId);

              //             final db = FirebaseFirestore.instance;
              //             var result = await db
              //                 .collection('users')
              //                 .doc(FirebaseAuth.instance.currentUser!.uid
              //                     .toString())
              //                 .collection('devices')
              //                 .get();
              //             result.docs.forEach((res) {
              //               print(res.id);

              //               FirebaseFirestore.instance
              //                   .collection('devices')
              //                   .doc(res.id.toString())
              //                   .update({
              //                 'brightnessAlertSliderSetting':
              //                     brightnessAlertSliderSetting
              //               });
              //             });
              //           },
              //           child: Text("SET"),
              //           style: ElevatedButton.styleFrom(
              //               backgroundColor: Color.fromARGB(73, 255, 7, 7),
              //               padding: EdgeInsets.symmetric(
              //                   horizontal: 5, vertical: 5),
              //               textStyle: TextStyle(
              //                   fontSize: 10, fontWeight: FontWeight.bold)),
              //         ),
              //       ]),
              //     ])),
              const SizedBox(
                height: 10,
              ),
              // Text(
              //   "Clear History",
              //   style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              // ),
              // Text(
              //   "Door Magnet Must Be Installed!",
              //   style: TextStyle(color: Colors.white, fontSize: titleSize - 5),
              // ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                          title: const Text('Clear History'),
                          content: const Text(
                              'Are you sure you want to clear your history?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                isCancelled = true;
                                Navigator.of(context).pop();
                              },
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                isCancelled = false;
                                Navigator.of(context).pop();
                              },
                              child: const Text('CONFIRM'),
                            )
                          ]),
                    );

                    if (!isCancelled) {
                      print("DELETE HISTORY:");
                      final db = FirebaseFirestore.instance;
                      var userId =
                          FirebaseAuth.instance.currentUser!.uid.toString();

                      var result = await db
                          .collection('notifications')
                          .where("userId", isEqualTo: userId)
                          .get();
                      for (var res in result.docs) {
                        print(res.id);

                        FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(res.id)
                            .delete();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(73, 255, 7, 7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text("Clear History"),
                ),
              ),

              const SizedBox(
                height: 10,
              ),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  // padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: const Row(children: [
                    Expanded(child: Column(children: [])),
                    // Column(children: [
                    //   ElevatedButton(
                    //     onPressed: () async {
                    //       print('volumeSliderSetting Pressed');

                    //       print(FirebaseAuth.instance.currentUser!.uid
                    //           .toString());
                    //       // print(device.deviceId);

                    //       final db = FirebaseFirestore.instance;
                    //       var result = await db
                    //           .collection('users')
                    //           .doc(FirebaseAuth.instance.currentUser!.uid
                    //               .toString())
                    //           .collection('devices')
                    //           .get();
                    //       result.docs.forEach((res) {
                    //         print(res.id);

                    //         FirebaseFirestore.instance
                    //             .collection('devices')
                    //             .doc(res.id.toString())
                    //             .update({
                    //           'volumeSliderSetting': volumeSliderSetting
                    //         });
                    //       });
                    //     },
                    //     child: Text("SET"),
                    //     style: ElevatedButton.styleFrom(
                    //         backgroundColor: Color.fromARGB(73, 255, 7, 7),
                    //         padding: EdgeInsets.symmetric(
                    //             horizontal: 5, vertical: 5),
                    //         textStyle: TextStyle(
                    //             fontSize: 10, fontWeight: FontWeight.bold)),
                    //   ),
                    // ]),
                  ])),
              const SizedBox(
                height: 10,
              ),
              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Display Signal Strength",
                        style: TextStyle(
                            color: Colors.white, fontSize: titleSize - 5),
                      ),
                    ),
                    Switch(
                      value: globals.showSignalStrength,
                      onChanged: (bool state) {
                        setState(() {
                          globals.showSignalStrength = state;
                          // Store the new state in Firestore
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .update({
                            'showSignalStrength': state,
                          });
                        });
                      },
                      activeColor: Colors.green,
                      inactiveTrackColor: const Color.fromARGB(73, 255, 7, 7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Display Battery Percentage",
                        style: TextStyle(
                            color: Colors.white, fontSize: titleSize - 5),
                      ),
                    ),
                    Switch(
                      value: globals.showBatteryPercentage,
                      onChanged: (bool state) {
                        setState(() {
                          globals.showBatteryPercentage = state;
                          // Store the new state in Firestore
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .update({
                            'showBatteryPercentage': state,
                          });
                        });
                      },
                      activeColor: Colors.green,
                      inactiveTrackColor: const Color.fromARGB(73, 255, 7, 7),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),

              // NOTIFICATION SETTINGS
              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Enable Notifications",
                        style: TextStyle(
                            color: Colors.white, fontSize: titleSize - 5),
                      ),
                    ),
                    Switch(
                      value: notificationsEnabled,
                      onChanged: (bool state) {
                        setState(() {
                          notificationsEnabled = state;
                        });
                        saveSettings();
                      },
                      activeColor: Colors.green,
                      inactiveTrackColor: const Color.fromARGB(73, 255, 7, 7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (notificationsEnabled) ...[
                Container(
                  width: 350,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Notify for Door States:",
                        style: TextStyle(
                            color: Colors.white, fontSize: titleSize - 7),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: allowedNotificationStates.contains(1)
                                    ? const Color.fromARGB(73, 255, 7, 7)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color.fromARGB(73, 255, 7, 7),
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: const Text("Locked",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                value: allowedNotificationStates.contains(1),
                                onChanged: (value) {
                                  toggleNotificationState(1);
                                  saveSettings();
                                },
                                activeColor:
                                    const Color.fromARGB(73, 255, 7, 7),
                                checkColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                dense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: allowedNotificationStates.contains(2)
                                    ? const Color.fromARGB(73, 255, 7, 7)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color.fromARGB(73, 255, 7, 7),
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: const Text("Unlocked",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                value: allowedNotificationStates.contains(2),
                                onChanged: (value) {
                                  toggleNotificationState(2);
                                  saveSettings();
                                },
                                activeColor:
                                    const Color.fromARGB(73, 255, 7, 7),
                                checkColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                dense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Commented out Open and Closed states
                      /*
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text("Open",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              value: allowedNotificationStates.contains(3),
                              onChanged: (value) {
                                toggleNotificationState(3);
                                saveSettings();
                              },
                              activeColor: Colors.green,
                              checkColor: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text("Closed",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              value: allowedNotificationStates.contains(4),
                              onChanged: (value) {
                                toggleNotificationState(4);
                                saveSettings();
                              },
                              activeColor: Colors.green,
                              checkColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      */
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ALEXA LINKING

              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Alexa Account",
                        style: TextStyle(
                            color: Colors.white, fontSize: titleSize - 5),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await linkAlexaAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: const Text("Link Account",
                          style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const SizedBox(
                height: 10,
              ),
              Column(
                children: [
                  ButtonTheme(
                    minWidth: (5000),
                    height: 100.0,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = await openDeleteAccountDialog();
                        if (!isCancelled) {
                          try {
                            final db = FirebaseFirestore.instance;
                            final userId =
                                FirebaseAuth.instance.currentUser!.uid;
                            print("Deleting all data for user: $userId");

                            // Create a batch for atomic operations
                            WriteBatch batch = db.batch();

                            // 1. Delete all notifications
                            var notificationsQuery = await db
                                .collection('notifications')
                                .where("userId", isEqualTo: userId)
                                .get();
                            for (var doc in notificationsQuery.docs) {
                              batch.delete(doc.reference);
                            }
                            print(
                                "Queued ${notificationsQuery.docs.length} notifications for deletion");

                            // 2. Delete all rooms and their shared access
                            var roomsQuery = await db
                                .collection('rooms')
                                .where("userId", isEqualTo: userId)
                                .get();
                            for (var doc in roomsQuery.docs) {
                              batch.delete(doc.reference);
                            }
                            // Also delete rooms where user is in sharedWith
                            var sharedRoomsQuery = await db
                                .collection('rooms')
                                .where("sharedWith", arrayContains: userId)
                                .get();
                            for (var doc in sharedRoomsQuery.docs) {
                              // Remove user from sharedWith array
                              batch.update(doc.reference, {
                                "sharedWith": FieldValue.arrayRemove([userId])
                              });
                            }
                            print(
                                "Queued ${roomsQuery.docs.length} rooms for deletion");

                            // 3. Delete all devices
                            // First from user's devices subcollection
                            var userDevicesQuery = await db
                                .collection('users')
                                .doc(userId)
                                .collection('devices')
                                .get();
                            for (var doc in userDevicesQuery.docs) {
                              batch.delete(doc.reference);
                              // Also delete from main devices collection
                              batch
                                  .delete(db.collection('devices').doc(doc.id));
                            }
                            print(
                                "Queued ${userDevicesQuery.docs.length} devices for deletion");

                            // 4. Delete all share requests
                            var sentRequestsQuery = await db
                                .collection('shareRequests')
                                .where("senderUid", isEqualTo: userId)
                                .get();
                            var receivedRequestsQuery = await db
                                .collection('shareRequests')
                                .where("recipientUid", isEqualTo: userId)
                                .get();
                            for (var doc in sentRequestsQuery.docs) {
                              batch.delete(doc.reference);
                            }
                            for (var doc in receivedRequestsQuery.docs) {
                              batch.delete(doc.reference);
                            }
                            print(
                                "Queued ${sentRequestsQuery.docs.length + receivedRequestsQuery.docs.length} share requests for deletion");

                            // 5. Delete user document
                            batch.delete(db.collection('users').doc(userId));

                            // 6. Execute all deletions in a single atomic operation
                            await batch.commit();
                            print("Successfully deleted all Firestore records");

                            // 7. Handle Firebase Auth account deletion with reauthentication if needed
                            final user = FirebaseAuth.instance.currentUser!;
                            try {
                              if (user.metadata.creationTime !=
                                  user.metadata.lastSignInTime) {
                                // Need to reauthenticate
                                final emailController =
                                    TextEditingController(text: user.email);
                                final passwordController =
                                    TextEditingController();

                                await showDialog(
                                  context: context,
                                  barrierDismissible:
                                      false, // User must take action
                                  builder: (context) => AlertDialog(
                                    title: const Text('Verify Your Account'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: emailController,
                                          enabled: false,
                                          decoration: const InputDecoration(
                                            labelText: 'Email',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: passwordController,
                                          obscureText: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Password',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          throw Exception(
                                              'Account deletion cancelled by user');
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Verify'),
                                        onPressed: () async {
                                          try {
                                            final credential =
                                                EmailAuthProvider.credential(
                                              email: emailController.text,
                                              password: passwordController.text,
                                            );
                                            await user
                                                .reauthenticateWithCredential(
                                                    credential);
                                            Navigator.of(context).pop();
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Authentication failed: $e')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Delete the Firebase Auth account
                              await user.delete();
                              print(
                                  "Successfully deleted Firebase Auth account");

                              // Sign out and show success message
                              await FirebaseAuth.instance.signOut();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Account successfully deleted')),
                              );
                            } catch (e) {
                              print("Error during auth deletion: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error deleting account: $e')),
                              );
                            }
                          } catch (e) {
                            print("Error during deletion process: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Error deleting account data: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(73, 255, 7, 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 75, vertical: 15),
                          textStyle: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      child: const Text("Delete Account"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(30, 255, 255, 255),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'Not signed in',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  ButtonTheme(
                    minWidth: (5000),
                    height: 100.0,
                    child: ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(73, 255, 7, 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 100, vertical: 15),
                          textStyle: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ]),
          );
        });
  }

  Future<String?> openDeleteAccountDialog() => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Delete Account'),
            content:
                const Text('Are you sure you want to Delete Your Account?'),
            actions: [
              TextButton(
                onPressed: cancel,
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: confirm,
                child: const Text('CONFIRM'),
              )
            ]),
      );

  void cancel() {
    // Navigator.of(context).pop(controller.text);
    isCancelled = true;
    Navigator.of(context).pop(controller.text);
  }

  void confirm() {
    Navigator.of(context).pop(controller.text);
  }

  Future<void> loadSettings() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          showSignalStrength = data['showSignalStrength'] ?? false;
          showBatteryPercentage = data['showBatteryPercentage'] ?? false;
          notificationsEnabled =
              data['notificationSettings']?['enabled'] ?? true;
          allowedNotificationStates = List<int>.from(
              data['notificationSettings']?['allowedStates'] ?? [1, 2]);
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'showSignalStrength': showSignalStrength,
        'showBatteryPercentage': showBatteryPercentage,
        'notificationSettings': {
          'enabled': notificationsEnabled,
          'allowedStates': allowedNotificationStates,
        }
      });

      // Update globals
      globals.showSignalStrength = showSignalStrength;
      globals.showBatteryPercentage = showBatteryPercentage;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleNotificationState(int state) {
    setState(() {
      if (allowedNotificationStates.contains(state)) {
        allowedNotificationStates.remove(state);
      } else {
        allowedNotificationStates.add(state);
      }
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:lockstate/screens/notifications_screen.dart';
import 'package:lockstate/screens/settings_screen.dart';
import 'package:lockstate/screens/share_doors_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:lockstate/widgets/share_request_status.dart';
import 'package:lockstate/widgets/share_request_handler.dart';

// var globals.lightSetting = 3; // Added by Jas to allow for different colour schemes need to move to globals

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

Color _lightSettingColour = Colors.red;

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController controller;
  String name = '';

  // void getLightSettingsFromFirestore() async {
  //   String newRoomName = "TEST ROOM";
  //   print('Getting LIGHT Settings from Firestore');

  //   void _shareRoom() {
  //     // Logic to obtain the roomId
  //     final roomId =
  //         'yourRoomId'; // Replace with actual logic to get the roomId

  //     // Navigate to ShareRoomPage
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => ShareRoomPage(roomId: roomId),
  //       ),
  //     );
  //   }

  //   final db = FirebaseFirestore.instance;
  //   var result = await db
  //       .collection('users')
  //       .doc(FirebaseAuth.instance.currentUser!.uid.toString())
  //       .collection('devices')
  //       .get();
  //   result.docs.forEach((res) {
  //     print(res.id);

  //     FirebaseFirestore.instance
  //         .collection('devices')
  //         .doc(res.id.toString())
  //         .get()
  //         .then((value) {
  //       if (!globals.gotLightSettings) {
  //         // print('LIGHTSETTING:');
  //         // print(value.get('lightSetting'));
  //         // sentLightSetting = value.get('lightSetting');
  //         globals.lightSetting = value.get('lightSetting').toInt();

  //         setState(() {
  //           globals.lightSetting = value.get('lightSetting').toInt();

  //           if (globals.lightSetting == 1) {
  //             _lightSettingColour = Colors.green;
  //           } else if (globals.lightSetting == 2) {
  //             _lightSettingColour = Colors.blue;
  //           } else if (globals.lightSetting == 3) {
  //             _lightSettingColour = Colors.cyan;
  //           }
  //         });
  //       }
  //       globals.gotLightSettings = true;
  //     });
  //   });
  // }

  late Account? currentAccount;
  late PageController pageController;
  int currentIndex = 0;

  @override
  void initState() {
    pageController = PageController();
    controller = TextEditingController();
    super.initState();
    listenForShareRequests();
    listenForRequestResponses();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  buildBottomNavigationBar() {
    return BottomNavigationBar(
        selectedItemColor: _lightSettingColour,
        currentIndex: currentIndex,
        unselectedItemColor: Colors.white,
        onTap: (int index) {
          setState(() {
            currentIndex = index;
          });
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 100),
            curve: Curves.bounceIn,
          );
        },
        items: const [
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),

            icon: Icon(
              Icons.home,
              // color: Colors.grey,
              size: 30,
            ),

            label: 'Home',
          ),
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),
            icon: Icon(
              Icons.history,
              // color: Colors.grey,
              size: 30,
            ),
            label: 'History',
          ),
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),
            icon: Icon(
              Icons.settings,
              // color: Colors.grey,
              size: 30,
            ),
            label: 'Settings',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 0, 0, 0));
  }

  // Function to delete a room and its associated devices
  Future<void> deleteRoom(String roomId, String userId) async {
    final db = FirebaseFirestore.instance;

    try {
      // First, get all devices with matching roomId from the user's devices subcollection
      var userDevices = await db
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('roomId', isEqualTo: roomId)
          .get();

      // Create a batch for atomic operations
      var batch = db.batch();

      // Delete devices from both collections
      for (var deviceDoc in userDevices.docs) {
        // Delete from user's devices subcollection
        batch.delete(deviceDoc.reference);

        // Delete from main devices collection
        batch.delete(db.collection('devices').doc(deviceDoc.id));
      }

      // Delete the room
      batch.delete(db.collection('rooms').doc(roomId));

      // Execute all deletions atomically
      await batch.commit();

      print('Room and associated devices deleted successfully');
    } catch (e) {
      print('Error deleting room and devices: $e');
      throw e; // Re-throw to handle in the UI
    }
  }

  // Function to show confirmation dialog
  Future<void> showDeleteConfirmationDialog(
      String roomId, String userId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this room?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await deleteRoom(roomId, userId);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  buildRoomsPage() {
    // getLightSettingsFromFirestore();
    return MomentumBuilder(
        controllers: const [
          DataController,
          AuthenticationController,
        ],
        builder: (context, snapshot) {
          // var dataModel = snapshot<DataModel>();
          // // var dataController = dataModel.controller;
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          // final devices = dataModel.devicesSnapshot?.docs ?? [];

          // print("devices" + devices.toString());
          // currentAccount = dataModel.account;
          // print("home dataModel : " + currentAccount!.uid);

          return DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: const Color.fromARGB(255, 43, 43, 43),
              appBar: AppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: const Color.fromARGB(255, 43, 43, 43),
                title: const Text(
                  'Home',
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
                    width: 140,
                    height: 100,
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
                bottom: AppBar(
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: const Color.fromARGB(255, 43, 43, 43),
                  title: const TabBar(
                    unselectedLabelColor: Color(ColorUtils.colorGrey),
                    indicatorColor: Colors.transparent,
                    tabs: [
                      Center(
                        child: Text("MY HOME"),
                      ),
                      Center(
                        child: Text("SHARED"),
                      ),
                    ],
                  ),
                  actions: [
                    GestureDetector(
                      onTap: () async {
                        // var doc = await FirebaseFirestore.instance
                        //     .collection('users')
                        //     .doc(FirebaseAuth.instance.currentUser!.uid)
                        //     .get();
                        // if (doc['connectionType'] == "HELIUM" ||
                        //     doc['connectionType'] == "TTN") {
                        //   Navigator.of(context).push(MaterialPageRoute(
                        //     builder: (context) {
                        //       return AddRoomScreen();
                        //     },
                        //   ));
                        // }
                        // if (doc['connectionType'] == "MINI_HUB") {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) {
                            return const AddHubScreen();
                          },
                        ));
                        // }
                      },
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lightSettingColour,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 18,
                    )
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 10,
                        child: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('rooms')
                                .where("userId",
                                    isEqualTo:
                                        FirebaseAuth.instance.currentUser!.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              var data = snapshot.data;
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.data == null) {
                                return const Center(
                                  child: Text("No Rooms Registered"),
                                );
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(
                                  15,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1 / 2,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                ),
                                scrollDirection: Axis.vertical,
                                itemCount: data!.docs.length,
                                itemBuilder: (context, index) {
                                  var doc = data.docs[index];
                                  var room = Room.fromDocument(doc);
                                  return GestureDetector(
                                    onTap: () async {
                                      int powerLevel1 = 2;
                                      int powerLevel2 = 2;
                                      List<DocumentSnapshot> deviceDocs = [];
                                      Map<String, double> batteryLevels = {};

                                      try {
                                        // Fetch associated devices
                                        final devicesSnapshot =
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(FirebaseAuth
                                                    .instance.currentUser!.uid)
                                                .collection('devices')
                                                .where('roomId',
                                                    isEqualTo: room.roomId)
                                                .get();

                                        // Filter out devices ending with "99999"
                                        deviceDocs =
                                            devicesSnapshot.docs.where((doc) {
                                          String deviceId = doc.id;
                                          return !deviceId.endsWith('99999');
                                        }).toList();

                                        print(
                                            'Found ${deviceDocs.length} valid devices (excluding *99999)');

                                        // Fetch power levels and latest battery readings for each device
                                        for (var deviceDoc in deviceDocs) {
                                          // Fetch power level
                                          final device = await FirebaseFirestore
                                              .instance
                                              .collection('devices')
                                              .doc(deviceDoc.id)
                                              .get();

                                          if (device.exists &&
                                              device
                                                  .data()!
                                                  .containsKey('powerLevel')) {
                                            if (batteryLevels.isEmpty) {
                                              powerLevel1 =
                                                  device.data()!['powerLevel'];
                                            } else {
                                              powerLevel2 =
                                                  device.data()!['powerLevel'];
                                            }
                                          }

                                          // Fetch latest notification for battery level
                                          final latestNotification =
                                              await FirebaseFirestore.instance
                                                  .collection('notifications')
                                                  .where('deviceId',
                                                      isEqualTo: deviceDoc.id)
                                                  .get();

                                          if (latestNotification
                                              .docs.isNotEmpty) {
                                            // Sort the documents locally to get the latest one
                                            final sortedDocs =
                                                latestNotification.docs
                                                  ..sort((a, b) => b
                                                      .data()['received_at']
                                                      .compareTo(a.data()[
                                                          'received_at']));

                                            final notification =
                                                sortedDocs.first.data();
                                            print('Device ID: ${deviceDoc.id}');
                                            print(
                                                'Full notification data: $notification');

                                            // Get volts directly from the root level
                                            if (notification
                                                .containsKey('volts')) {
                                              // Convert the voltage to a percentage or appropriate scale
                                              double volts = notification[
                                                          'volts']
                                                      .toDouble() /
                                                  1000; // Convert to volts (3818 -> 3.818V)
                                              batteryLevels[deviceDoc.id] =
                                                  volts;
                                              print(
                                                  'Battery voltage for device ${deviceDoc.id}: ${volts.toStringAsFixed(3)}V');
                                            } else {
                                              print(
                                                  'No notifications found for device: ${deviceDoc.id}');
                                            }
                                          } else {
                                            print(
                                                'No notifications found for device: ${deviceDoc.id}');
                                          }
                                        }
                                      } catch (e) {
                                        print('Error fetching device data: $e');
                                      }

                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return StatefulBuilder(
                                              builder: (context, setState) {
                                            return AlertDialog(
                                              title: Text(
                                                room.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (deviceDocs
                                                      .isNotEmpty) ...[
                                                    Text(
                                                      'Indoor Battery Level: ${batteryLevels[deviceDocs[0].id]?.toStringAsFixed(1) ?? 'N/A'}V',
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    Text(
                                                      'Please set power level to lowest working value to extend battery life.',
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    const Text(
                                                      'Indoor Power Level:',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 1'),
                                                      value: 1,
                                                      groupValue: powerLevel1,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel1 = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 2'),
                                                      value: 2,
                                                      groupValue: powerLevel1,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel1 = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 3'),
                                                      value: 3,
                                                      groupValue: powerLevel1,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel1 = value!;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                  if (deviceDocs.length >
                                                      1) ...[
                                                    const SizedBox(height: 20),
                                                    Text(
                                                      'Outdoor Battery Level: ${batteryLevels[deviceDocs[1].id]?.toStringAsFixed(1) ?? 'N/A'}V',
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    const Text(
                                                      'Outdoor Power Level:',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 1'),
                                                      value: 1,
                                                      groupValue: powerLevel2,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel2 = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 2'),
                                                      value: 2,
                                                      groupValue: powerLevel2,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel2 = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<int>(
                                                      title:
                                                          const Text('Level 3'),
                                                      value: 3,
                                                      groupValue: powerLevel2,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          powerLevel2 = value!;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    try {
                                                      // Update first device
                                                      if (deviceDocs
                                                          .isNotEmpty) {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'devices')
                                                            .doc(deviceDocs[0]
                                                                .id)
                                                            .update({
                                                          'powerLevel':
                                                              powerLevel1
                                                        });
                                                      }

                                                      // Update second device if it exists
                                                      if (deviceDocs.length >
                                                          1) {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'devices')
                                                            .doc(deviceDocs[1]
                                                                .id)
                                                            .update({
                                                          'powerLevel':
                                                              powerLevel2
                                                        });
                                                      }

                                                      Navigator.of(context)
                                                          .pop();

                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Power levels updated successfully'),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      print(
                                                          'Error updating power levels: $e');
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Failed to update power levels'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: const Text('Save'),
                                                ),
                                              ],
                                            );
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF3F3F3),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Color(room.state == 0
                                                ? ColorUtils.colorGrey
                                                : room.state == 2 &&
                                                        globals.lightSetting ==
                                                            1
                                                    ? ColorUtils.colorRed
                                                    : room.state == 1 &&
                                                            globals.lightSetting ==
                                                                1
                                                        ? ColorUtils.colorGreen
                                                        : room.state == 3 &&
                                                                globals.lightSetting ==
                                                                    1
                                                            ? ColorUtils
                                                                .colorRed
                                                            : room.state == 1
                                                                ? ColorUtils
                                                                    .colorGrey
                                                                : room.state ==
                                                                            2 &&
                                                                        globals.lightSetting ==
                                                                            2
                                                                    ? ColorUtils
                                                                        .colorAmber
                                                                    : room.state ==
                                                                                1 &&
                                                                            globals.lightSetting ==
                                                                                2
                                                                        ? ColorUtils
                                                                            .colorBlue
                                                                        : room.state == 3 &&
                                                                                globals.lightSetting == 3
                                                                            ? ColorUtils.colorRed
                                                                            : room.state == 2 && globals.lightSetting == 3
                                                                                ? ColorUtils.colorAmber
                                                                                : room.state == 1 && globals.lightSetting == 3
                                                                                    ? ColorUtils.colorCyan
                                                                                    : room.state == 3 && globals.lightSetting == 3
                                                                                        ? ColorUtils.colorRed
                                                                                        : ColorUtils.colorRed),
                                            width: 2),

                                        // boxShadow: [
                                        //   BoxShadow(
                                        //       blurRadius: 4,
                                        //       color: Theme.of(context).accentColor)
                                        // ],
                                        // border: Border.all(
                                        //     color: Theme.of(context).accentColor),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(15),
                                              margin: const EdgeInsets.only(
                                                top: 20,
                                              ),
                                              decoration: BoxDecoration(
                                                  color: const Color(
                                                      ColorUtils.colorWhite),
                                                  shape: BoxShape.circle,
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.grey,
                                                      offset: Offset(
                                                          0.0, 1.0), //(x,y)
                                                      blurRadius: 6.0,
                                                    ),
                                                  ],
                                                  border: Border.all(
                                                      color: Color(room.state ==
                                                              1
                                                          ? ColorUtils.colorGrey
                                                          : room.state == 2 &&
                                                                  globals.lightSetting ==
                                                                      1
                                                              ? ColorUtils
                                                                  .colorRed
                                                              : room.state ==
                                                                          1 &&
                                                                      globals.lightSetting ==
                                                                          1
                                                                  ? ColorUtils
                                                                      .colorGreen
                                                                  : room.state ==
                                                                              3 &&
                                                                          globals.lightSetting ==
                                                                              1
                                                                      ? ColorUtils
                                                                          .colorRed
                                                                      : room.state ==
                                                                              0
                                                                          ? ColorUtils
                                                                              .colorGrey
                                                                          : room.state == 2 && globals.lightSetting == 2
                                                                              ? ColorUtils.colorAmber
                                                                              : room.state == 1 && globals.lightSetting == 2
                                                                                  ? ColorUtils.colorBlue
                                                                                  : room.state == 3 && globals.lightSetting == 3
                                                                                      ? ColorUtils.colorRed
                                                                                      : room.state == 2 && globals.lightSetting == 3
                                                                                          ? ColorUtils.colorAmber
                                                                                          : room.state == 1 && globals.lightSetting == 3
                                                                                              ? ColorUtils.colorCyan
                                                                                              : room.state == 3 && globals.lightSetting == 3
                                                                                                  ? ColorUtils.colorRed
                                                                                                  : ColorUtils.colorRed),
                                                      width: 1)),
                                              child: Center(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Icon(
                                                      room.state == 1
                                                          ? Icons.lock
                                                          : Icons.lock_open,
                                                      size: 100,
                                                      color: Color(room.state ==
                                                              0
                                                          ? ColorUtils.colorGrey
                                                          : room.state == 2 &&
                                                                  globals.lightSetting ==
                                                                      1
                                                              ? ColorUtils
                                                                  .colorRed
                                                              : room.state ==
                                                                          1 &&
                                                                      globals.lightSetting ==
                                                                          1
                                                                  ? ColorUtils
                                                                      .colorGreen
                                                                  : room.state ==
                                                                              3 &&
                                                                          globals.lightSetting ==
                                                                              1
                                                                      ? ColorUtils
                                                                          .colorRed
                                                                      : room.state ==
                                                                              0
                                                                          ? ColorUtils
                                                                              .colorGrey
                                                                          : room.state == 2 && globals.lightSetting == 2
                                                                              ? ColorUtils.colorAmber
                                                                              : room.state == 1 && globals.lightSetting == 2
                                                                                  ? ColorUtils.colorBlue
                                                                                  : room.state == 3 && globals.lightSetting == 3
                                                                                      ? ColorUtils.colorRed
                                                                                      : room.state == 2 && globals.lightSetting == 3
                                                                                          ? ColorUtils.colorAmber
                                                                                          : room.state == 1 && globals.lightSetting == 3
                                                                                              ? ColorUtils.colorCyan
                                                                                              : room.state == 3 && globals.lightSetting == 3
                                                                                                  ? ColorUtils.colorRed
                                                                                                  : ColorUtils.colorRed),
                                                    ),
                                                    if (currentIndex != 1 &&
                                                        room.sharedWith
                                                            .isNotEmpty)
                                                      Transform.translate(
                                                        offset:
                                                            const Offset(0, 60),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(6),
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Colors.green,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          constraints:
                                                              const BoxConstraints(
                                                            minWidth: 30,
                                                            minHeight: 30,
                                                          ),
                                                          child: Text(
                                                            room.sharedWith
                                                                .length
                                                                .toString(),
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Text(
                                              room.name,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 1,
                                            ),
                                            ShareRequestStatus(
                                                roomId: room.roomId),
                                            const SizedBox(
                                              height: 1,
                                            ),
                                            Text(
                                              room.state == 0
                                                  ? "Not Set"
                                                  : room.state == 2
                                                      ? "Unlocked"
                                                      : room.state == 1
                                                          ? "Locked"
                                                          : room.state == 3
                                                              ? "Unlocked / Open"
                                                              : "Closed",
                                              style: const TextStyle(
                                                color: Color(
                                                  ColorUtils.color4,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('notifications')
                                                  .where('roomId',
                                                      isEqualTo: room.roomId)
                                                  .orderBy('received_at',
                                                      descending: true)
                                                  .limit(1)
                                                  .snapshots(),
                                              builder:
                                                  (context, notifSnapshot) {
                                                if (notifSnapshot
                                                        .connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const CircularProgressIndicator();
                                                }
                                                if (notifSnapshot.hasError ||
                                                    !notifSnapshot.hasData ||
                                                    notifSnapshot
                                                        .data!.docs.isEmpty) {
                                                  return Column(
                                                    children: [
                                                      const Text(
                                                        'Last Operation:',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      const SizedBox(height: 1),
                                                      const Text(
                                                        'Not Set',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                    ],
                                                  );
                                                }
                                                final notif = notifSnapshot
                                                        .data!.docs.first
                                                        .data()
                                                    as Map<String, dynamic>;
                                                final msg = notif['message']
                                                    as Map<String, dynamic>?;
                                                String? isoString = msg != null
                                                    ? msg['received_at']
                                                        as String?
                                                    : null;
                                                DateTime? date;
                                                if (isoString != null) {
                                                  try {
                                                    date = DateTime.parse(
                                                        isoString);
                                                  } catch (e) {
                                                    print(
                                                        'Failed to parse message.received_at: $isoString');
                                                  }
                                                }
                                                final formatted = date != null
                                                    ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}'
                                                    : 'Unknown';
                                                return Column(
                                                  children: [
                                                    const Text(
                                                      'Last Operation:',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      formatted,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        final name =
                                                            await openRenameDialog();
                                                        if (name == null ||
                                                            name.isEmpty)
                                                          return;
                                                        setState(
                                                            () => this.name);
                                                        FirebaseFirestore
                                                            .instance
                                                            .collection("rooms")
                                                            .doc(room.roomId)
                                                            .update({
                                                          "name":
                                                              name.toUpperCase()
                                                        });

                                                        final db =
                                                            FirebaseFirestore
                                                                .instance;
                                                        var result = await db
                                                            .collection('users')
                                                            .doc(room.userId)
                                                            .collection(
                                                                'devices')
                                                            .where('roomId',
                                                                isEqualTo:
                                                                    room.roomId)
                                                            .get();
                                                        for (var res
                                                            in result.docs) {
                                                          print(res.id);

                                                          db
                                                              .collection(
                                                                  'devices')
                                                              .doc(res.id
                                                                  .toString())
                                                              .get()
                                                              .then((value) {
                                                            print(value
                                                                .get('isIndoor')
                                                                .toString());
                                                            bool isIndoor =
                                                                value.get(
                                                                    'isIndoor');

                                                            if (isIndoor) {
                                                              //                                                       db
                                                              //     .collection(
                                                              //         'devices')
                                                              //     .doc(res.id
                                                              //         .toString())
                                                              //     .update({
                                                              //   'deviceName':
                                                              //       name + " INSIDE"
                                                              // });
                                                              db
                                                                  .collection(
                                                                      'devices')
                                                                  .doc(res.id
                                                                      .toString())
                                                                  .update({
                                                                'deviceName': name
                                                                    .toUpperCase()
                                                              });
                                                            } else {
                                                              db
                                                                  .collection(
                                                                      'devices')
                                                                  .doc(res.id
                                                                      .toString())
                                                                  .update({
                                                                'deviceName':
                                                                    "$name OUTSIDE"
                                                              });
                                                            }
                                                          });
                                                        }
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors
                                                              .white,
                                                          fixedSize:
                                                              const Size.square(
                                                                  5),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 1,
                                                                  vertical: 1),
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                      child: const Icon(
                                                        Icons.edit,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                ShareRoomPage(
                                                              roomId:
                                                                  room.roomId,
                                                              roomName: room
                                                                  .name, // Ensure roomName is provided
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.white,
                                                        fixedSize:
                                                            const Size.square(
                                                                5),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 1,
                                                                vertical: 1),
                                                        textStyle:
                                                            const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                      ),
                                                      child: const Icon(
                                                        Icons.share,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 1),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    showDeleteConfirmationDialog(
                                                        room.roomId,
                                                        room.userId);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    fixedSize:
                                                        const Size.square(5),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 1,
                                                        vertical: 1),
                                                    textStyle: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  child: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                      ),
                      // Expanded(
                      //   child: Container(),
                      //   flex: 1,
                      // ),

                      // Expanded(
                      //   child: Container(),
                      //   flex: 1,
                      // ),

                      // Expanded(
                      //   flex: 1,
                      //   child: Center(
                      //     child: Text(
                      //       "Security Level",
                      //       style: TextStyle(
                      //         fontSize: 20,
                      //         fontWeight: FontWeight.w700,
                      //         color: Colors.white70,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Expanded(
                      //   child: NumberStepper(
                      //       lineColor: Color(ColorUtils.color3),
                      //       activeStepColor: Theme.of(context).accentColor,
                      //       activeStepBorder
                      //       stepColor: Color(
                      //         ColorUtils.color3,
                      //       ),
                      //       lineDotRadius: 3,
                      //       activeStepBorderWidth: 3,
                      //       lineLength: 60,
                      //       numbers: [
                      //         1,
                      //         2,
                      //         3,
                      //         4,
                      //       ]),
                      //   flex: 1,
                      // ),
                    ],
                  ),

                  // SHARED PAGE STARTS HERE
                  Column(
                    children: [
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('rooms')
                              .where("sharedWith",
                                  arrayContains:
                                      FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            // Debug information
                            print("\n=== SHARED ROOMS DEBUG ===");
                            print(
                                "Current user ID: ${FirebaseAuth.instance.currentUser!.uid}");
                            print(
                                "Current user email: ${FirebaseAuth.instance.currentUser!.email}");
                            print(
                                "Connection state: ${snapshot.connectionState}");
                            print("Has error: ${snapshot.hasError}");
                            if (snapshot.hasError)
                              print("Error: ${snapshot.error}");
                            print("Has data: ${snapshot.hasData}");
                            print(
                                "Number of rooms: ${snapshot.data?.docs.length ?? 0}");

                            if (snapshot.data != null) {
                              for (var doc in snapshot.data!.docs) {
                                print("\nRoom Details:");
                                print("Room ID: ${doc.id}");
                                print("Room Name: ${doc.data()['name']}");
                                print(
                                    "Shared With: ${doc.data()['sharedWith']}");
                                print("Owner ID: ${doc.data()['userId']}");
                              }
                            }
                            print("=========================\n");

                            var data = snapshot.data;
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.data == null || data!.docs.isEmpty) {
                              return const Center(
                                child: Text("No Shared Rooms",
                                    style: TextStyle(color: Colors.white)),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(15),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1 / 2,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                              ),
                              itemCount: data.docs.length,
                              itemBuilder: (context, index) {
                                var doc = data.docs[index];
                                var room = Room.fromDocument(doc);
                                return GestureDetector(
                                  // onTap: () {
                                  //   Navigator.of(context)
                                  //       .push(MaterialPageRoute(
                                  //     builder: (context) {
                                  //       return RoomDetailScreen(
                                  //           room: room);
                                  //     },
                                  //   ));
                                  // },

                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xffF3F3F3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Color(room.state == 0
                                              ? ColorUtils.colorGrey
                                              : room.state == 2 &&
                                                      globals.lightSetting == 1
                                                  ? ColorUtils.colorRed
                                                  : room.state == 1 &&
                                                          globals.lightSetting ==
                                                              1
                                                      ? ColorUtils.colorGreen
                                                      : room.state == 3 &&
                                                              globals.lightSetting ==
                                                                  1
                                                          ? ColorUtils.colorRed
                                                          : room.state == 1
                                                              ? ColorUtils
                                                                  .colorGrey
                                                              : room.state ==
                                                                          2 &&
                                                                      globals.lightSetting ==
                                                                          2
                                                                  ? ColorUtils
                                                                      .colorAmber
                                                                  : room.state ==
                                                                              1 &&
                                                                          globals.lightSetting ==
                                                                              2
                                                                      ? ColorUtils
                                                                          .colorBlue
                                                                      : room.state == 3 &&
                                                                              globals.lightSetting ==
                                                                                  2
                                                                          ? ColorUtils
                                                                              .colorRed
                                                                          : room.state == 2 && globals.lightSetting == 3
                                                                              ? ColorUtils.colorAmber
                                                                              : room.state == 1 && globals.lightSetting == 3
                                                                                  ? ColorUtils.colorCyan
                                                                                  : room.state == 3 && globals.lightSetting == 3
                                                                                      ? ColorUtils.colorRed
                                                                                      : ColorUtils.colorRed),
                                          width: 2),

                                      // boxShadow: [
                                      //   BoxShadow(
                                      //       blurRadius: 4,
                                      //       color: Theme.of(context).accentColor)
                                      // ],
                                      // border: Border.all(
                                      //     color: Theme.of(context).accentColor),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Shared icon in top corner
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.share,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(15),
                                                margin: const EdgeInsets.only(
                                                  top: 20,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: const Color(
                                                        ColorUtils.colorWhite),
                                                    shape: BoxShape.circle,
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.grey,
                                                        offset: Offset(
                                                            0.0, 1.0), //(x,y)
                                                        blurRadius: 6.0,
                                                      ),
                                                    ],
                                                    border: Border.all(
                                                        color: Color(room
                                                                    .state ==
                                                                1
                                                            ? ColorUtils
                                                                .colorGrey
                                                            : room.state == 2 &&
                                                                    globals.lightSetting ==
                                                                        1
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : room.state ==
                                                                            1 &&
                                                                        globals.lightSetting ==
                                                                            1
                                                                    ? ColorUtils
                                                                        .colorGreen
                                                                    : room.state ==
                                                                                3 &&
                                                                            globals.lightSetting ==
                                                                                1
                                                                        ? ColorUtils
                                                                            .colorRed
                                                                        : room.state ==
                                                                                0
                                                                            ? ColorUtils.colorGrey
                                                                            : room.state == 2 && globals.lightSetting == 2
                                                                                ? ColorUtils.colorAmber
                                                                                : room.state == 1 && globals.lightSetting == 2
                                                                                    ? ColorUtils.colorBlue
                                                                                    : room.state == 3 && globals.lightSetting == 3
                                                                                        ? ColorUtils.colorRed
                                                                                        : room.state == 2 && globals.lightSetting == 3
                                                                                            ? ColorUtils.colorAmber
                                                                                            : room.state == 1 && globals.lightSetting == 3
                                                                                                ? ColorUtils.colorCyan
                                                                                                : room.state == 3 && globals.lightSetting == 3
                                                                                                    ? ColorUtils.colorRed
                                                                                                    : ColorUtils.colorRed),
                                                        width: 1)),
                                                child: Center(
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Icon(
                                                        room.state == 1
                                                            ? Icons.lock
                                                            : Icons.lock_open,
                                                        size: 100,
                                                        color: Color(room
                                                                    .state ==
                                                                0
                                                            ? ColorUtils
                                                                .colorGrey
                                                            : room.state == 2 &&
                                                                    globals.lightSetting ==
                                                                        1
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : room.state ==
                                                                            1 &&
                                                                        globals.lightSetting ==
                                                                            1
                                                                    ? ColorUtils
                                                                        .colorGreen
                                                                    : room.state ==
                                                                                3 &&
                                                                            globals.lightSetting ==
                                                                                1
                                                                        ? ColorUtils
                                                                            .colorRed
                                                                        : room.state ==
                                                                                0
                                                                            ? ColorUtils.colorGrey
                                                                            : room.state == 2 && globals.lightSetting == 2
                                                                                ? ColorUtils.colorAmber
                                                                                : room.state == 1 && globals.lightSetting == 2
                                                                                    ? ColorUtils.colorBlue
                                                                                    : room.state == 3 && globals.lightSetting == 3
                                                                                        ? ColorUtils.colorRed
                                                                                        : room.state == 2 && globals.lightSetting == 3
                                                                                            ? ColorUtils.colorAmber
                                                                                            : room.state == 1 && globals.lightSetting == 3
                                                                                                ? ColorUtils.colorCyan
                                                                                                : room.state == 3 && globals.lightSetting == 3
                                                                                                    ? ColorUtils.colorRed
                                                                                                    : ColorUtils.colorRed),
                                                      ),
                                                      if (room.sharedWith
                                                          .isNotEmpty)
                                                        Container(),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                room.name,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 1,
                                              ),
                                              ShareRequestStatus(
                                                  roomId: room.roomId),
                                              const SizedBox(
                                                height: 1,
                                              ),
                                              Text(
                                                room.state == 0
                                                    ? "Not Set"
                                                    : room.state == 2
                                                        ? "Unlocked"
                                                        : room.state == 1
                                                            ? "Locked"
                                                            : room.state == 3
                                                                ? "Unlocked / Open"
                                                                : "Closed",
                                                style: const TextStyle(
                                                  color: Color(
                                                    ColorUtils.color4,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 5,
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      // Show confirmation dialog
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext
                                                            context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                                'Remove Shared Access'),
                                                            content: const Text(
                                                                'Are you sure you want to remove your access to this shared room?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(); // Close dialog
                                                                },
                                                                child: const Text(
                                                                    'Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    () async {
                                                                  try {
                                                                    // Remove current user from sharedWith array
                                                                    await FirebaseFirestore
                                                                        .instance
                                                                        .collection(
                                                                            'rooms')
                                                                        .doc(room
                                                                            .roomId)
                                                                        .update({
                                                                      'sharedWith':
                                                                          FieldValue
                                                                              .arrayRemove([
                                                                        FirebaseAuth
                                                                            .instance
                                                                            .currentUser!
                                                                            .uid
                                                                      ])
                                                                    });

                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(); // Close dialog
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      const SnackBar(
                                                                          content:
                                                                              Text('Access removed successfully')),
                                                                    );
                                                                  } catch (e) {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(); // Close dialog
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                          content:
                                                                              Text('Error removing access: $e')),
                                                                    );
                                                                  }
                                                                },
                                                                child: const Text(
                                                                    'Remove Access',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red)),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .white,
                                                        fixedSize: const Size
                                                            .square(5),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 1,
                                                                vertical: 1),
                                                        textStyle:
                                                            const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                    child: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(
                                                height: 7,
                                              ),
                                              FutureBuilder<QuerySnapshot>(
                                                future: FirebaseFirestore
                                                    .instance
                                                    .collection('users')
                                                    .where(FieldPath.documentId,
                                                        whereIn:
                                                            room.sharedWith)
                                                    .get(),
                                                builder:
                                                    (context, userSnapshot) {
                                                  if (userSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const CircularProgressIndicator();
                                                  }
                                                  if (userSnapshot.hasError ||
                                                      !userSnapshot.hasData) {
                                                    return const Text(
                                                        'Error loading emails');
                                                  }
                                                  final emails = userSnapshot
                                                      .data!.docs
                                                      .map((doc) => doc['email']
                                                          as String)
                                                      .join(', ');
                                                  return Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5.0),
                                                        child: Center(
                                                          child: Text(
                                                            'This Door Belongs To: $emails',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 12,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      ),
                                                      StreamBuilder<
                                                          QuerySnapshot>(
                                                        stream: FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'notifications')
                                                            .where('roomId',
                                                                isEqualTo:
                                                                    room.roomId)
                                                            .orderBy(
                                                                'received_at',
                                                                descending:
                                                                    true)
                                                            .limit(1)
                                                            .snapshots(),
                                                        builder: (context,
                                                            notifSnapshot) {
                                                          if (notifSnapshot
                                                                  .connectionState ==
                                                              ConnectionState
                                                                  .waiting) {
                                                            return const CircularProgressIndicator();
                                                          }
                                                          if (notifSnapshot.hasError ||
                                                              !notifSnapshot
                                                                  .hasData ||
                                                              notifSnapshot
                                                                  .data!
                                                                  .docs
                                                                  .isEmpty) {
                                                            return Column(
                                                              children: [
                                                                const Text(
                                                                  'Last Operation:',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .black,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                                const SizedBox(
                                                                    height: 1),
                                                                const Text(
                                                                  'Not Set',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .black),
                                                                ),
                                                              ],
                                                            );
                                                          }
                                                          final notif =
                                                              notifSnapshot
                                                                      .data!
                                                                      .docs
                                                                      .first
                                                                      .data()
                                                                  as Map<String,
                                                                      dynamic>;
                                                          final msg =
                                                              notif['message']
                                                                  as Map<String,
                                                                      dynamic>?;
                                                          String? isoString =
                                                              msg != null
                                                                  ? msg['received_at']
                                                                      as String?
                                                                  : null;
                                                          DateTime? date;
                                                          if (isoString !=
                                                              null) {
                                                            try {
                                                              date = DateTime
                                                                  .parse(
                                                                      isoString);
                                                            } catch (e) {
                                                              print(
                                                                  'Failed to parse message.received_at: $isoString');
                                                            }
                                                          }
                                                          final formatted = date !=
                                                                  null
                                                              ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}'
                                                              : 'Unknown';
                                                          return Column(
                                                            children: [
                                                              const Text(
                                                                'Last Operation:',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .black,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                              const SizedBox(
                                                                  height: 1),
                                                              Text(
                                                                formatted,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .black),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 1),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        });
  }

  Future<String?> openRenameDialog() => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Rename Door'),
            content: TextField(
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Enter New Door Name'),
              controller: controller,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6), // Limit to 6 characters
              ],
            ),
            actions: [
              TextButton(
                onPressed: submit,
                child: const Text('SUBMIT'),
              )
            ]),
      );
  void submit() {
    Navigator.of(context).pop(controller.text);
  }

  buildPageView() {
    return PageView(
      controller: pageController,
      onPageChanged: onPageChanged,
      children: [
        buildRoomsPage(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ],
    );
  }

  onPageChanged(int page) {
    setState(() {
      currentIndex = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      body: Stack(
        children: [
          buildPageView(),
          const ShareRequestHandler(),
        ],
      ),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

  void listenForShareRequests() {
    FirebaseFirestore.instance
        .collection('shareRequests')
        .where('recipientEmail',
            isEqualTo: FirebaseAuth.instance.currentUser!.email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          showShareRequestDialog(change.doc);
        }
      }
    });
  }

  void listenForRequestResponses() {
    FirebaseFirestore.instance
        .collection('shareRequests')
        .where('senderUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final status = change.doc.data()!['status'];
          if (status == 'rejected') {
            showRejectionDialog(change.doc.data()!['recipientEmail']);
          }
        }
      }
    });
  }

  void showShareRequestDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Share Request'),
        content: Text(
            '${data['senderEmail']} wants to share "${data['roomName']}" with you.'),
        actions: [
          TextButton(
            onPressed: () => handleShareResponse(doc.id, 'rejected'),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => handleShareResponse(doc.id, 'accepted'),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void showRejectionDialog(String recipientEmail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Request Rejected'),
        content: Text('$recipientEmail has declined your share request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> handleShareResponse(String requestId, String response) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('shareRequests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data()!;

      // Update request status
      await requestDoc.reference.update({'status': response});

      if (response == 'accepted') {
        // Add user to sharedWith array
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(requestData['roomId'])
            .update({
          'sharedWith':
              FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])
        });
      }

      Navigator.pop(context); // Close dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class GridElement {
  late bool isSelected;
  late String name;
  late IconData icon;
  GridElement(
      {required this.icon, required this.isSelected, required this.name});
}

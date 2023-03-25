import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:lockstate/screens/add_room_screen.dart';
import 'package:lockstate/screens/notifications_screen.dart';
import 'package:lockstate/screens/room_detail_screen.dart';
import 'package:lockstate/screens/settings_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

// var globals.lightSetting = 3; // Added by Jas to allow for different colour schemes need to move to globals

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

Color _lightSettingColour = Color.fromARGB(0, 255, 255, 255);

class _HomeScreenState extends State<HomeScreen> {
  void getLightSettingsFromFirestore() async {
    print('Getting LIGHT Settings from Firestore');

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
        if (!globals.gotLightSettings) {
          print('LIGHTSETTING:');
          print(value.get('lightSetting'));
          // sentLightSetting = value.get('lightSetting');
          globals.lightSetting = value.get('lightSetting').toInt();

          setState(() {
            globals.lightSetting = value.get('lightSetting').toInt();

            if (globals.lightSetting == 1) {
              _lightSettingColour = Colors.green;
            } else if (globals.lightSetting == 2) {
              _lightSettingColour = Colors.blue;
            } else if (globals.lightSetting == 3) {
              _lightSettingColour = Colors.cyan;
            }
          });
        }
        globals.gotLightSettings = true;
      });
    });
  }

  late Account? currentAccount;
  late PageController pageController;
  int currentIndex = 0;

  @override
  void initState() {
    pageController = PageController();
    super.initState();
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
            duration: Duration(milliseconds: 100),
            curve: Curves.bounceIn,
          );
        },
        items: [
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
        backgroundColor: Color.fromARGB(255, 0, 0, 0));
  }

  buildRoomsPage() {
    getLightSettingsFromFirestore();
    return MomentumBuilder(
        controllers: [
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
              backgroundColor: Color.fromARGB(255, 43, 43, 43),
              appBar: AppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: Color.fromARGB(255, 43, 43, 43),
                title: Text(
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
                bottom: AppBar(
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: Color.fromARGB(255, 43, 43, 43),
                  title: TabBar(
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
                        var doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .get();
                        if (doc['connectionType'] == "HELIUM" ||
                            doc['connectionType'] == "TTN") {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) {
                              return AddRoomScreen();
                            },
                          ));
                        }
                        if (doc['connectionType'] == "MINI_HUB") {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) {
                              return AddHubScreen();
                            },
                          ));
                        }
                      },
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lightSettingColour,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
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
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('rooms')
                                    .where("userId",
                                        isEqualTo: FirebaseAuth
                                            .instance.currentUser!.uid)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  var data = snapshot.data;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.data == null) {
                                    return Center(
                                      child: Text("No Rooms Registered"),
                                    );
                                  }

                                  return GridView.builder(
                                    padding: EdgeInsets.all(
                                      15,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1 / 1.5,
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 20,
                                    ),
                                    scrollDirection: Axis.vertical,
                                    itemCount: data!.docs.length,
                                    itemBuilder: (context, index) {
                                      var doc = data.docs[index];
                                      var room = Room.fromDocument(doc);
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (context) {
                                              return RoomDetailScreen(
                                                  room: room);
                                            },
                                          ));
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xffF3F3F3),
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                                            ? ColorUtils
                                                                .colorGreen
                                                            : room.state == 3 &&
                                                                    globals.lightSetting ==
                                                                        1
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : room.state ==
                                                                        1
                                                                    ? ColorUtils
                                                                        .colorGrey
                                                                    : room.state ==
                                                                                2 &&
                                                                            globals.lightSetting ==
                                                                                2
                                                                        ? ColorUtils
                                                                            .colorMagenta
                                                                        : room.state == 1 &&
                                                                                globals.lightSetting == 2
                                                                            ? ColorUtils.colorBlue
                                                                            : room.state == 3 && globals.lightSetting == 2
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
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(15),
                                                margin: EdgeInsets.only(
                                                  top: 20,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: Color(
                                                        ColorUtils.colorWhite),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
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
                                                                                ? ColorUtils.colorMagenta
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
                                                  child: Icon(
                                                    room.state == 1
                                                        ? Icons.lock
                                                        : Icons.lock_open,
                                                    size: 100,
                                                    color: Color(room.state == 0
                                                        ? ColorUtils.colorGrey
                                                        : room.state == 2 &&
                                                                globals.lightSetting ==
                                                                    1
                                                            ? ColorUtils
                                                                .colorRed
                                                            : room.state == 1 &&
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
                                                                        : room.state == 2 &&
                                                                                globals.lightSetting == 2
                                                                            ? ColorUtils.colorMagenta
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
                                                ),
                                              ),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                room.name,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(
                                                height: 10,
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
                                                style: TextStyle(
                                                  color: Color(
                                                    ColorUtils.color4,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
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
                  Center(
                    child: Text("Shared"),
                  )
                ],
              ),
            ),
          );
        });
  }

  buildPageView() {
    return PageView(
      controller: pageController,
      onPageChanged: onPageChanged,
      children: [
        buildRoomsPage(),
        NotificationsScreen(),
        SettingsScreen(),
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
      backgroundColor: Theme.of(context).backgroundColor,
      body: buildPageView(),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }
}

class GridElement {
  late bool isSelected;
  late String name;
  late IconData icon;
  GridElement(
      {required this.icon, required this.isSelected, required this.name});
}

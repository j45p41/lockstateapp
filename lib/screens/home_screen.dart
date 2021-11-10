import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:im_stepper/stepper.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_device_screen.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:lockstate/screens/add_room_screen.dart';
import 'package:lockstate/screens/device_detail_screen.dart';
import 'package:lockstate/screens/notifications_screen.dart';
import 'package:lockstate/screens/room_detail_screen.dart';
import 'package:lockstate/screens/select_connection_type_screen.dart';
import 'package:lockstate/screens/settings_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

import 'package:dotted_border/dotted_border.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      selectedItemColor: Colors.red,
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
            Icons.notifications,
            // color: Colors.grey,
            size: 30,
          ),
          label: 'Notificactions',
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
      backgroundColor: Color(ColorUtils.color2),
    );
  }

  buildRoomsPage() {
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
              backgroundColor: Color(ColorUtils.colorDarkGrey),
              appBar: AppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: Color(ColorUtils.colorDarkGrey),
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
                bottom: AppBar(
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: Color(ColorUtils.colorDarkGrey),
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
                          color: Color(
                            ColorUtils.color2,
                          ),
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
                                  // print("home room name ${room.name}");
                                  // if (index == data.docs.length) {
                                  //   return GestureDetector(
                                  //     onTap: () {
                                  //       Navigator.of(context)
                                  //           .push(MaterialPageRoute(
                                  //         builder: (context) {
                                  //           return AddRoomScreen();
                                  //         },
                                  //       ));
                                  //     },
                                  //     child: DottedBorder(
                                  //       color: Color(ColorUtils.color3),
                                  //       borderType: BorderType.RRect,
                                  //       // padding: EdgeInsets.all(10),
                                  //       radius: Radius.circular(20),
                                  //       strokeWidth: 3,

                                  //       dashPattern: [10, 5],
                                  //       strokeCap: StrokeCap.butt,
                                  //       child: Center(
                                  //         child: Container(
                                  //           decoration: BoxDecoration(
                                  //             color: Theme.of(context)
                                  //                 .backgroundColor,
                                  //             // borderRadius: BorderRadius.circular(20),
                                  //             // boxShadow: [
                                  //             //   BoxShadow(
                                  //             //       blurRadius: 4,
                                  //             //       color: Theme.of(context).accentColor)
                                  //             // ],
                                  //             // border: Border.all(
                                  //             //     color: Theme.of(context).accentColor),
                                  //           ),
                                  //           child: Column(
                                  //             mainAxisAlignment:
                                  //                 MainAxisAlignment.center,
                                  //             children: [
                                  //               Container(
                                  //                 padding: EdgeInsets.all(10),
                                  //                 decoration: BoxDecoration(
                                  //                   color: Color(
                                  //                       ColorUtils.color2),
                                  //                   shape: BoxShape.circle,
                                  //                 ),
                                  //                 child: Center(
                                  //                   child: Icon(
                                  //                     Icons.add,
                                  //                     size: 40,
                                  //                     color: Color(
                                  //                         ColorUtils.color3),
                                  //                   ),
                                  //                 ),
                                  //               ),
                                  //               SizedBox(
                                  //                 height: 10,
                                  //               ),
                                  //               Text(
                                  //                 "Add Door",
                                  //                 style: TextStyle(
                                  //                   color: Color(
                                  //                       ColorUtils.color3),
                                  //                   fontSize: 20,
                                  //                 ),
                                  //               )
                                  //             ],
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   );
                                  // }
                                  var doc = data.docs[index];
                                  var room = Room.fromDocument(doc);
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (context) {
                                          return RoomDetailScreen(room: room);
                                        },
                                      ));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color(0xffF3F3F3),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Color(room.state == 0
                                                ? ColorUtils.colorGrey
                                                : room.state == 1
                                                    ? ColorUtils.colorRed
                                                    : room.state == 2
                                                        ? ColorUtils.colorGreen
                                                        : room.state == 3
                                                            ? ColorUtils
                                                                .colorRed
                                                            : ColorUtils
                                                                .colorRed),
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
                                                    color: Color(room.state == 0
                                                        ? ColorUtils.colorGrey
                                                        : room.state == 1
                                                            ? ColorUtils
                                                                .colorRed
                                                            : room.state == 2
                                                                ? ColorUtils
                                                                    .colorGreen
                                                                : room.state ==
                                                                        3
                                                                    ? ColorUtils
                                                                        .colorRed
                                                                    : ColorUtils
                                                                        .colorRed),
                                                    width: 1)),
                                            child: Center(
                                              child: Icon(
                                                Icons.door_front_door_outlined,
                                                size: 100,
                                                color: Color(room.state == 0
                                                    ? ColorUtils.colorGrey
                                                    : room.state == 1
                                                        ? ColorUtils.colorRed
                                                        : room.state == 2
                                                            ? ColorUtils
                                                                .colorGreen
                                                            : room.state == 3
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : ColorUtils
                                                                    .colorRed),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 10,
                                          ),
                                          Text(
                                            room.state == 0
                                                ? "Not Set"
                                                : room.state == 1
                                                    ? "Unlocked / Closed"
                                                    : room.state == 2
                                                        ? "Locked / Closed"
                                                        : room.state == 3
                                                            ? "Unlocked / Open"
                                                            : "Closed",
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
                                            room.name,
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

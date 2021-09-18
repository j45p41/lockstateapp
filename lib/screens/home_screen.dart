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
import 'package:lockstate/screens/add_room_screen.dart';
import 'package:lockstate/screens/device_detail_screen.dart';
import 'package:lockstate/screens/notifications_screen.dart';
import 'package:lockstate/screens/room_detail_screen.dart';
import 'package:lockstate/screens/settings_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

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
      currentIndex: currentIndex,
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
            color: Colors.grey,
            size: 30,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          // backgroundColor: Color(ColorUtils.color1),
          icon: Icon(
            Icons.notifications,
            color: Colors.grey,
            size: 30,
          ),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          // backgroundColor: Color(ColorUtils.color1),
          icon: Icon(
            Icons.settings,
            color: Colors.grey,
            size: 30,
          ),
          label: 'Settings',
        ),
      ],
      backgroundColor: Colors.white,
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

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                'Lockstate',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    authController.logout();
                  },
                  child: Text("Logout"),
                ),
              ],
              centerTitle: false,
            ),
            body: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      "Welcome to Lockstate",
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).accentColor,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .where("userId",
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid)
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
                            childAspectRatio: 1,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          scrollDirection: Axis.vertical,
                          itemCount: data!.docs.length,
                          itemBuilder: (context, index) {
                            var doc = data.docs[index];
                            var room = Room.fromDocument(doc);
                            // print("home room name ${room.name}");
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return RoomDetailScreen(room: room);
                                  },
                                ));
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).backgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 4,
                                        color: Theme.of(context).accentColor)
                                  ],
                                  border: Border.all(
                                      color: Theme.of(context).accentColor),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.home,
                                      size: 60,
                                      color: Color(ColorUtils.color3),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      room.name,
                                      style: TextStyle(
                                        color: Color(ColorUtils.color3),
                                        fontSize: 20,
                                      ),
                                    )
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
                Divider(
                  thickness: 1,
                  color: Color(
                    ColorUtils.color3,
                  ),
                ),
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
                //       activeStepBorderColor: Colors.white,
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

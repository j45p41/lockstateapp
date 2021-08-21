import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:im_stepper/stepper.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/screens/add_device_screen.dart';
import 'package:lockstate/screens/device_detail_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Account? currentAccount;
  @override
  Widget build(BuildContext context) {
    return MomentumBuilder(
        controllers: [
          DataController,
          AuthenticationController,
        ],
        builder: (context, snapshot) {
          var dataModel = snapshot<DataModel>();
          var dataController = dataModel.controller;
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          final devices = dataModel.devicesSnapshot?.docs ?? [];

          print("devices" + devices.toString());
          currentAccount = dataModel.account;
          // print("home dataModel : " + currentAccount!.uid);

          return Scaffold(
            backgroundColor: Theme.of(context).backgroundColor,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddDeviceScreen(),
                  ),
                );
              },
            ),
            drawer: Drawer(),
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
                          .collection('devices')
                          .where("userId",
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        var data = snapshot.data;

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
                          scrollDirection: Axis.horizontal,
                          itemCount: data!.docs.length,
                          itemBuilder: (context, index) {
                            var doc = data.docs[index];
                            var device = Device.fromDocument(doc);
                            print("home device name ${device.deviceName}");
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return DeviceDetailScreen(device: device);
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
                                      device.deviceName,
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
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      "Security Level",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: NumberStepper(
                      lineColor: Color(ColorUtils.color3),
                      activeStepColor: Theme.of(context).accentColor,
                      activeStepBorderColor: Colors.white,
                      stepColor: Color(
                        ColorUtils.color3,
                      ),
                      lineDotRadius: 3,
                      activeStepBorderWidth: 3,
                      lineLength: 60,
                      numbers: [
                        1,
                        2,
                        3,
                        4,
                      ]),
                  flex: 1,
                ),
                Expanded(
                  child: Container(),
                  flex: 1,
                ),
              ],
            ),
          );
        });
  }
}

class GridElement {
  late bool isSelected;
  late String name;
  late IconData icon;
  GridElement(
      {required this.icon, required this.isSelected, required this.name});
}

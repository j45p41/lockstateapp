import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_device_screen.dart';
import 'package:lockstate/screens/device_detail_screen.dart';
import 'package:lockstate/utils/color_utils.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  RoomDetailScreen({
    required this.room,
  });
  @override
  _RoomDetailScreenState createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(ColorUtils.colorDarkGrey),
        floatingActionButton: FloatingActionButton(
          child: Icon(
            Icons.add,
            color: Colors.white,
          ),
          backgroundColor: Color(ColorUtils.color2),
          foregroundColor: Color(ColorUtils.color2),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) {
                return AddDeviceScreen(widget.room);
              },
            ));
          },
        ),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Color(ColorUtils.colorDarkGrey),
          title: Text(
            widget.room.name,
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
                  color: Colors.white, borderRadius: BorderRadius.circular(5)),
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
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('devices')
                .where("roomId", isEqualTo: widget.room.roomId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.data == null) {
                return Center(
                  child: Text(
                    "No Devices Registered",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (snapshot.data!.docs.length == 0) {
                return Center(
                  child: Text(
                    "No Devices Registered",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              var data = snapshot.data;
              return GridView.builder(
                padding: EdgeInsets.all(
                  15,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5 / 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                scrollDirection: Axis.vertical,
                itemCount: data!.docs.length,
                itemBuilder: (context, index) {
                  // if (index == data.docs.length) {
                  //   return GestureDetector(
                  //     onTap: () {
                  // Navigator.of(context).push(MaterialPageRoute(
                  //   builder: (context) {
                  //     return AddDeviceScreen(widget.room);
                  //   },
                  // ));
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
                  //             color: Theme.of(context).backgroundColor,
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
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               Container(
                  //                 padding: EdgeInsets.all(10),
                  //                 decoration: BoxDecoration(
                  //                   color: Color(ColorUtils.color2),
                  //                   shape: BoxShape.circle,
                  //                 ),
                  //                 child: Center(
                  //                   child: Icon(
                  //                     Icons.add,
                  //                     size: 40,
                  //                     color: Color(ColorUtils.color3),
                  //                   ),
                  //                 ),
                  //               ),
                  //               SizedBox(
                  //                 height: 10,
                  //               ),
                  //               Text(
                  //                 "Add Device",
                  //                 style: TextStyle(
                  //                   color: Color(ColorUtils.color3),
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
                  var device = Device.fromDocument(doc);
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
                        color: Color(0xffF3F3F3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Color(device.state == 0
                                ? ColorUtils.colorGrey
                                : device.state == 1
                                    ? ColorUtils.colorRed
                                    : device.state == 2
                                        ? ColorUtils.colorGreen
                                        : device.state == 3
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(15),
                            margin: EdgeInsets.only(
                              top: 20,
                            ),
                            decoration: BoxDecoration(
                                color: Color(ColorUtils.colorWhite),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey,
                                    offset: Offset(0.0, 1.0), //(x,y)
                                    blurRadius: 6.0,
                                  ),
                                ],
                                border: Border.all(
                                    color: Color(device.state == 0
                                        ? ColorUtils.colorGrey
                                        : device.state == 1
                                            ? ColorUtils.colorRed
                                            : device.state == 2
                                                ? ColorUtils.colorGreen
                                                : device.state == 3
                                                    ? ColorUtils.colorRed
                                                    : ColorUtils.colorRed),
                                    width: 1)),
                            child: Center(
                              child: Icon(
                                Icons.door_front_door_outlined,
                                size: 130,
                                color: Color(device.state == 0
                                    ? ColorUtils.colorGrey
                                    : device.state == 1
                                        ? ColorUtils.colorRed
                                        : device.state == 2
                                            ? ColorUtils.colorGreen
                                            : device.state == 3
                                                ? ColorUtils.colorRed
                                                : ColorUtils.colorRed),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            device.state == 0
                                ? "Not Set"
                                : device.state == 1
                                    ? "Unlocked / Closed"
                                    : device.state == 2
                                        ? "Locked / Closed"
                                        : device.state == 3
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
                            widget.room.name,
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
            }));
  }
}

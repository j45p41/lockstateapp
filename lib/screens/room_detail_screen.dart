import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_device_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

var lightSetting =
    3; // Added by Jas to allow for different colour schemes need to move to globals

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  RoomDetailScreen({
    required this.room,
  });
  @override
  _RoomDetailScreenState createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final GlobalKey<FormState> _editRoomFormKey = GlobalKey<FormState>();
  String newRoomName = "";
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
            ),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return Container(
                      height: 200,
                      child: Form(
                        key: _editRoomFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              onChanged: (newValue) {
                                setState(() {
                                  newRoomName = newValue;
                                });
                              },
                            ),
                            ElevatedButton(
                                onPressed: () {
                                  if (_editRoomFormKey.currentState!
                                      .validate()) {
                                    FirebaseFirestore.instance
                                        .collection("rooms")
                                        .doc(widget.room.roomId)
                                        .update({"name": newRoomName});
                                  }
                                },
                                child: Text("Update Room Name"))
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
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
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                ),
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
                      // Navigator.of(context).push(MaterialPageRoute(
                      //   builder: (context) {
                      //     return DeviceDetailScreen(device: device);
                      //   },
                      // ));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xffF3F3F3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Color(device.state == 0
                                ? ColorUtils.colorGrey
                                : device.state == 2 && lightSetting == 0
                                    ? ColorUtils.colorRed
                                    : device.state == 1 && lightSetting == 0
                                        ? ColorUtils.colorGreen
                                        : device.state == 3 && lightSetting == 0
                                            ? ColorUtils.colorRed
                                            : device.state == 0
                                                ? ColorUtils.colorGrey
                                                : device.state == 2 &&
                                                        lightSetting == 2
                                                    ? ColorUtils.colorMagenta
                                                    : device.state == 1 &&
                                                            lightSetting == 2
                                                        ? ColorUtils.colorBlue
                                                        : device.state == 3 &&
                                                                lightSetting ==
                                                                    3
                                                            ? ColorUtils
                                                                .colorRed
                                                            : device.state ==
                                                                        2 &&
                                                                    lightSetting ==
                                                                        3
                                                                ? ColorUtils
                                                                    .colorAmber
                                                                : device.state ==
                                                                            1 &&
                                                                        lightSetting ==
                                                                            3
                                                                    ? ColorUtils
                                                                        .colorCyan
                                                                    : device.state ==
                                                                                3 &&
                                                                            lightSetting ==
                                                                                3
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(15),
                              margin: EdgeInsets.only(
                                top: 15,
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
                                          : device.state == 2 &&
                                                  lightSetting == 0
                                              ? ColorUtils.colorRed
                                              : device.state == 1 &&
                                                      lightSetting == 0
                                                  ? ColorUtils.colorGreen
                                                  : device.state == 3 &&
                                                          lightSetting == 0
                                                      ? ColorUtils.colorRed
                                                      : device.state == 0
                                                          ? ColorUtils.colorGrey
                                                          : device.state == 2 &&
                                                                  lightSetting ==
                                                                      2
                                                              ? ColorUtils
                                                                  .colorMagenta
                                                              : device.state ==
                                                                          1 &&
                                                                      lightSetting ==
                                                                          2
                                                                  ? ColorUtils
                                                                      .colorBlue
                                                                  : device.state ==
                                                                              3 &&
                                                                          lightSetting ==
                                                                              3
                                                                      ? ColorUtils
                                                                          .colorRed
                                                                      : device.state == 2 &&
                                                                              lightSetting ==
                                                                                  3
                                                                          ? ColorUtils
                                                                              .colorAmber
                                                                          : device.state == 1 && lightSetting == 3
                                                                              ? ColorUtils.colorCyan
                                                                              : device.state == 3 && lightSetting == 3
                                                                                  ? ColorUtils.colorRed
                                                                                  : ColorUtils.colorRed),
                                      width: 1)),
                              child: Center(
                                child: Image.asset(
                                  device.state == 1
                                      ? "assets/images/device_locked.png"
                                      : "assets/images/device_unlocked.png",
                                  height: 130,
                                ),
                                // child: Icon(
                                //   Icons.door_front_door_outlined,
                                //   size: 100,
                                //   color: Color(device.state == 0
                                //       ? ColorUtils.colorGrey
                                //       : device.state == 2
                                //           ? ColorUtils.colorRed
                                //           : device.state == 1
                                //               ? ColorUtils.colorGreen
                                //               : device.state == 3
                                //                   ? ColorUtils.colorRed
                                //                   : ColorUtils.colorRed),
                                // ),
                              ),
                            ),
                            // SizedBox(
                            //   height: 10,
                            // ),
                            // Text(
                            //   widget.room.name,
                            //   style: TextStyle(
                            //     color: Color(
                            //       ColorUtils.color4,
                            //     ),
                            //     fontWeight: FontWeight.bold,
                            //     fontSize: 14,
                            //   ),
                            // ),
                            SizedBox(
                              height: 20,
                            ),
                            Text(
                              device.isIndoor ? "INDOOR" : "OUTDOOR",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),

                            SizedBox(
                              height: 20,
                            ),
                            Text(
                              device.state == 0
                                  ? "Not Set"
                                  : device.state == 2
                                      ? "Unlocked"
                                      : device.state == 1
                                          ? "Locked"
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
                              height: 20,
                            ),

                            Text(
                              "Battery Level : " + device.batVolts.toString(),
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Spacer(),
                            Text(
                              "[${device.count}]",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(
                              height: 8,
                            ),
                            Text(
                              device.lastRecievedAt == ""
                                  ? "Not Set"
                                  : device.lastRecievedAt.substring(16, 24),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }));
  }
}

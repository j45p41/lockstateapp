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
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          title: Text(widget.room.name),
          backgroundColor: Theme.of(context).backgroundColor,
          elevation: 0,
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
                  child: Text("No Devices Registered"),
                );
              }
              if (snapshot.data!.docs.length == 0) {
                return Center(
                  child: Text("No Devices Registered"),
                );
              }
              var data = snapshot.data;
              return GridView.builder(
                padding: EdgeInsets.all(
                  15,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                scrollDirection: Axis.vertical,
                itemCount: data!.docs.length + 1,
                itemBuilder: (context, index) {
                  if (index == data.docs.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) {
                            return AddDeviceScreen(widget.room);
                          },
                        ));
                      },
                      child: DottedBorder(
                        color: Color(ColorUtils.color3),
                        borderType: BorderType.RRect,
                        // padding: EdgeInsets.all(10),
                        radius: Radius.circular(20),
                        strokeWidth: 3,

                        dashPattern: [10, 5],
                        strokeCap: StrokeCap.butt,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).backgroundColor,
                              // borderRadius: BorderRadius.circular(20),
                              // boxShadow: [
                              //   BoxShadow(
                              //       blurRadius: 4,
                              //       color: Theme.of(context).accentColor)
                              // ],
                              // border: Border.all(
                              //     color: Theme.of(context).accentColor),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(ColorUtils.color2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.add,
                                      size: 40,
                                      color: Color(ColorUtils.color3),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  "Add Device",
                                  style: TextStyle(
                                    color: Color(ColorUtils.color3),
                                    fontSize: 20,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
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
                        color: Color.fromRGBO(123, 128, 128, 0.06),
                        borderRadius: BorderRadius.circular(20),

                        // boxShadow: [
                        //   BoxShadow(
                        //       blurRadius: 4,
                        //       color: Theme.of(context).accentColor)
                        // ],
                        // border: Border.all(
                        //     color: Theme.of(context).accentColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(ColorUtils.color2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.door_front_door_outlined,
                                size: 40,
                                color: Color(ColorUtils.color3),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            device.deviceName,
                            style: TextStyle(
                              color: Color(ColorUtils.color4),
                              fontSize: 14,
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            }));
  }
}

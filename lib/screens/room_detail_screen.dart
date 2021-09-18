import 'package:cloud_firestore/cloud_firestore.dart';
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
        floatingActionButton: FloatingActionButton(
            child: Icon(
              Icons.add,
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) {
                  return AddDeviceScreen(widget.room);
                },
              ));
            }),
        appBar: AppBar(
          title: Text(widget.room.name),
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
                itemCount: data!.docs.length,
                itemBuilder: (context, index) {
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
                        color: Theme.of(context).backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 4,
                              color: Theme.of(context).accentColor)
                        ],
                        border:
                            Border.all(color: Theme.of(context).accentColor),
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
            }));
  }
}

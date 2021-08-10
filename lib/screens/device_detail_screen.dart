import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/utils/color_utils.dart';

class DeviceDetailScreen extends StatefulWidget {
  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool isOn = false;
  List<HistoryDetails> mockData = [
    HistoryDetails(
      duration: "1 hour",
      event: "ON",
      name: "Bedroom Door opened",
      timestamp: "3 Aug 2021 at 1:10 pm",
    ),
    HistoryDetails(
      duration: "2 hours",
      event: "OFF",
      name: "Bedroom Door closed",
      timestamp: "3 Aug 2021 at 3:10 pm",
    ),
    HistoryDetails(
      duration: "10 hours",
      event: "ON",
      name: "Bedroom Door opened",
      timestamp: "5 Aug 2021 at 4:10 pm",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Bedroom",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        leading: Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white70,
        ),
      ),
      backgroundColor: Theme.of(context).backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.bed,
                        size: 300,
                        color: isOn
                            ? Colors.white
                            : Color(
                                ColorUtils.color3,
                              ),
                      ),
                      Positioned(
                        left: -50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.battery_full,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "100%",
                              style: TextStyle(
                                color: Theme.of(context).accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15.0,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Turn device ${isOn ? "OFF" : "ON"}",
                          style: TextStyle(
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                        CupertinoSwitch(
                            value: isOn,
                            onChanged: (value) {
                              setState(() {
                                isOn = value;
                              });
                            }),
                      ],
                    ),
                  ),
                  Divider(
                    thickness: 1,
                    color: Color(
                      ColorUtils.color3,
                    ),
                  ),
                ],
              ),
            ),
            // flex: 3,
          ),
          Text(
            "History",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 30,
            ),
          ),
          Expanded(
              child: ListView.builder(
            itemCount: mockData.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  mockData[index].name,
                  style: TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  mockData[index].timestamp,
                  style: TextStyle(color: Colors.white70),
                ),
                trailing: Text(
                  "Event : " + mockData[index].event,
                  style: TextStyle(color: Colors.white70),
                ),
              );
            },
          )),
        ],
      ),
    );
  }
}

class HistoryDetails {
  late String duration;

  late String timestamp;
  late String name;
  late String event;
  HistoryDetails({
    required this.duration,
    required this.event,
    required this.name,
    required this.timestamp,
  });
}

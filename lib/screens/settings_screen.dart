import 'package:flutter/material.dart';
import 'package:lockstate/screens/add_hub_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Column(children: [
        ElevatedButton(onPressed: () {}, child: Text("Add device")),
        ElevatedButton(onPressed: () {}, child: Text("Rename device")),
        ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) {
                  return AddHubScreen();
                },
              ));
            },
            child: Text("Add hub")),
      ]),
    );
  }
}

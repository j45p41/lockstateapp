import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:momentum/momentum.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return MomentumBuilder(
        controllers: [AuthenticationController, DataController],
        builder: (context, snapshot) {
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
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
              TextButton(
                onPressed: () {
                  authController.logout();
                },
                child: Text("Logout"),
              ),
            ]),
          );
        });
  }
}

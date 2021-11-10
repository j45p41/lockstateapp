import 'package:flutter/material.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
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
            backgroundColor: Color(ColorUtils.colorDarkGrey),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Color(ColorUtils.colorDarkGrey),
              title: Text(
                'Settings',
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
            ),
            body: Column(children: [
              ListTile(
                onTap: () {
                  authController.logout();
                },
                leading: Icon(
                  Icons.logout,
                ),
                title: Text(
                  "Logout",
                  style: TextStyle(color: Colors.white),
                ),
              )
            ]),
          );
        });
  }
}

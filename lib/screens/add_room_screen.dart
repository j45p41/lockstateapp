import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/data/data.controller.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:momentum/momentum.dart';

import '../main.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({Key? key}) : super(key: key);

  @override
  _AddRoomScreenState createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  String roomName = '';

  addDevice() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final dataController = Momentum.controller<DataController>(context);

      dataController.addRoom(FirebaseAuth.instance.currentUser!.uid, roomName);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => Authenticate(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        title: Text(
          "Add Door",
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              TextFormField(
                style: TextStyle(color: Color(ColorUtils.color4)),
                decoration: InputDecoration(
                  fillColor: Color(ColorUtils.color2),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Enter Door name",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),
                ),
                onSaved: (newValue) => roomName = newValue!,
              ),
              SizedBox(
                height: 40,
              ),
              GestureDetector(
                onTap: addDevice,
                child: Container(
                  child: Center(
                    child: Text(
                      "Add Door",
                      style: TextStyle(
                        color: Color(
                          ColorUtils.color4,
                        ),
                      ),
                    ),
                  ),
                  padding: EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Color(ColorUtils.color3),
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

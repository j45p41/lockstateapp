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
      backgroundColor: Color(ColorUtils.colorDarkGrey),
      appBar: AppBar(
        backgroundColor: Color(ColorUtils.color2),
        title: Text(
          "Add Door",
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              SizedBox(
                height: 10,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Enter Door Name : ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              SizedBox(
                height: 10,
              ),
              TextFormField(
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  fillColor: Color(ColorUtils.colorWhite),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Type here",
                  hintStyle: TextStyle(color: Color(ColorUtils.color4)),
                ),
                onSaved: (newValue) => roomName = newValue!,
              ),
              Spacer(),
              GestureDetector(
                onTap: addDevice,
                child: Container(
                  child: Center(
                    child: Text(
                      "Add Door",
                      style: TextStyle(
                        color: Color(
                          ColorUtils.colorWhite,
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
              SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/data/data.controller.dart';
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
      appBar: AppBar(
        title: Text(
          "Add Room",
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Room name",
                ),
                onSaved: (newValue) => roomName = newValue!,
              ),
              ElevatedButton(
                onPressed: addDevice,
                child: Text("Add Room"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/main.dart';
import 'package:lockstate/utils/color_utils.dart';

class SelectConnectionScreen extends StatefulWidget {
  const SelectConnectionScreen({Key? key}) : super(key: key);

  @override
  _SelectConnectionScreenState createState() => _SelectConnectionScreenState();
}

class _SelectConnectionScreenState extends State<SelectConnectionScreen> {
  bool isSelected = false;
  bool isheliumSelected = false;
  bool isTtnSelected = false;
  bool isMinihubSelected = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(ColorUtils.colorDarkGrey),
      appBar: AppBar(
        backgroundColor: Color(ColorUtils.color2),
        title: Text(
          "Connection Type",
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
        actions: [
          if (isSelected)
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .update({
                  "connectionType": isMinihubSelected
                      ? "MINI_HUB"
                      : isTtnSelected
                          ? "TTN"
                          : "HELIUM",
                }).whenComplete(() {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) {
                      return Authenticate();
                    },
                  ));
                });
              },
              child: Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 20,
            ),
            Center(
              child: Text("How will you connect your detector?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            SizedBox(
              height: 30,
            ),
            GridView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: 10,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1 / 1.3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected = true;
                      isTtnSelected = false;
                      isMinihubSelected = true;
                      isheliumSelected = false;
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isMinihubSelected
                              ? Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/minihub.png"),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        "Mini-Hub",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected = true;
                      isTtnSelected = false;
                      isMinihubSelected = false;
                      isheliumSelected = true;
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isheliumSelected
                              ? Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/helium.png"),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        "Helium",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected = true;
                      isTtnSelected = true;
                      isMinihubSelected = false;
                      isheliumSelected = false;
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isTtnSelected
                              ? Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/ttn.png"),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        "The Things Network",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

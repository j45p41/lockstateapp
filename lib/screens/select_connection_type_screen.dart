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
      backgroundColor: const Color(ColorUtils.colorDarkGrey),
      appBar: AppBar(
        backgroundColor: const Color(ColorUtils.color2),
        title: const Text(
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
                      return const Authenticate();
                    },
                  ));
                });
              },
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            const Center(
              child: Text("How will you connect your detector?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const SizedBox(
              height: 30,
            ),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        padding: const EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isMinihubSelected
                              ? const Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/minihub.png"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
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
                        padding: const EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isheliumSelected
                              ? const Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/helium.png"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
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
                        padding: const EdgeInsets.all(10),
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isTtnSelected
                              ? const Color(ColorUtils.color2)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset("assets/images/ttn.png"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
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

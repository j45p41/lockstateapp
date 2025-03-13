import 'package:flutter/material.dart';
import 'package:lockstate/main.dart';
import 'package:lockstate/utils/color_utils.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int selectedIndex = 0;
  // @override
  // void initState() {
  //   _pageController = ;
  //   super.initState();
  // }

  // @override
  // void dispose() {
  //   _pageController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) {
                    return const Authenticate();
                  },
                ));
              },
              child: Text(
                selectedIndex == 2 ? "Done" : "Skip",
                style: const TextStyle(color: Colors.blue, fontSize: 15),
              ),
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              flex: 1,
              child: Container(),
            ),
            Expanded(
              flex: 7,
              child: PageView(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AspectRatio(
                          aspectRatio: 375 / 281,
                          child: Image.asset('assets/images/intro1.png')),
                      // SizedBox(
                      //   height: 100,
                      // ),
                      const Text(
                        "Know the state of all your doors from\nanywhere using your phone.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  // Column(
                  //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //   children: [
                  //     AspectRatio(
                  //         aspectRatio: 375 / 281,
                  //         child: Image.asset('assets/images/intro2.png')),
                  //     // SizedBox(
                  //     //   height: 100,
                  //     // ),
                  //     Text(
                  //       "Detectors are placed on the\ninside and outside of the door.",
                  //       textAlign: TextAlign.center,
                  //       style: TextStyle(
                  //           color: Colors.black,
                  //           fontSize: 20,
                  //           fontWeight: FontWeight.w800),
                  //     ),
                  //   ],
                  // ),
                  // Column(
                  //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //   children: [
                  //     AspectRatio(
                  //         aspectRatio: 375 / 281,
                  //         child: Image.asset('assets/images/intro3.png')),
                  //     // SizedBox(
                  //     //   height: 100,
                  //     // ),
                  //     Text(
                  //       "Get Instant notification of\nany change.",
                  //       textAlign: TextAlign.center,
                  //       style: TextStyle(
                  //           color: Colors.black,
                  //           fontSize: 20,
                  //           fontWeight: FontWeight.w800),
                  //     )
                  //   ],
                  // ),
                ],
              ),
            ),

            // Expanded(
            //   flex: 1,
            //   child: SmoothPageIndicator(
            //     controller: _pageController,
            //     effect: WormEffect(
            //         activeDotColor: Colors.blue,
            //         strokeWidth: 0.1,
            //         dotWidth: 10,
            //         dotHeight: 10),
            //     count: 3,
            //   ),
            // ),
            // Expanded(
            //   child: PageView(
            //     controller: _pageController,
            //     children: [
            //       Center(
            //         child: Text(
            //           "Browse & conquer\nnew goals",
            //         ),
            //       ),
            //       Center(
            //         child: Text(
            //             "Go solo, invite a friend\nor get matched with someone\nin our network"),
            //       ),
            //       Center(
            //           child: Text(
            //               "Access inspirational quotes\nto keep you motivated")),
            //     ],
            //   ),
            //   flex: 3,
            // ),
            Expanded(
              flex: 1,
              child: Container(),
            ),

            if (selectedIndex == 2)
              Expanded(
                flex: 1,
                child: Container(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) {
                          return const Authenticate();
                        },
                      ));
                    },
                    child: AspectRatio(
                      aspectRatio: 355 / 65,
                      child: Container(
                        // padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          // shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(10),

                          color: const Color(ColorUtils.color2),
                        ),
                        child: const Center(
                          child: Text(
                            "Get Started",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 1,
              child: Container(),
            ),
          ],
        ),
      ),
    );
  }
}

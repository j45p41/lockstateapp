import 'package:flutter/material.dart';
import 'package:im_stepper/stepper.dart';
import 'package:lockstate/utils/color_utils.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GridElement> mockData = [
    GridElement(icon: Icons.bed, isSelected: true, name: "Bedroom"),
    GridElement(icon: Icons.garage, isSelected: false, name: "Garage"),
    GridElement(icon: Icons.kitchen, isSelected: false, name: "Kitchen"),
    GridElement(icon: Icons.fence_sharp, isSelected: false, name: "Backyard"),
    GridElement(icon: Icons.door_front, isSelected: false, name: "Entrance"),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      drawer: Drawer(),
      appBar: AppBar(
        title: Text(
          'Lockstate',
          style: TextStyle(color: Colors.white70),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "Welcome to Lockstate",
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: GridView.builder(
              padding: EdgeInsets.all(
                15,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: mockData.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      mockData[index].isSelected = !mockData[index].isSelected;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: mockData[index].isSelected
                              ? Theme.of(context).accentColor
                              : Colors.transparent,
                        )
                      ],
                      border: Border.all(
                        color: mockData[index].isSelected
                            ? Theme.of(context).accentColor
                            : Color(ColorUtils.color3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mockData[index].icon,
                          size: 60,
                          color: mockData[index].isSelected
                              ? Colors.white
                              : Color(ColorUtils.color3),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          mockData[index].name,
                          style: TextStyle(
                            color: mockData[index].isSelected
                                ? Colors.white
                                : Color(ColorUtils.color3),
                            fontSize: 20,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Expanded(
          //   child: Container(),
          //   flex: 1,
          // ),
          Divider(
            thickness: 1,
            color: Color(
              ColorUtils.color3,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "Security Level",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Expanded(
            child: NumberStepper(
                lineColor: Color(ColorUtils.color3),
                activeStepColor: Theme.of(context).accentColor,
                activeStepBorderColor: Colors.white,
                stepColor: Color(
                  ColorUtils.color3,
                ),
                lineDotRadius: 3,
                activeStepBorderWidth: 3,
                lineLength: 60,
                numbers: [
                  1,
                  2,
                  3,
                  4,
                ]),
            flex: 1,
          ),
          Expanded(
            child: Container(),
            flex: 1,
          ),
        ],
      ),
    );
  }
}

class GridElement {
  late bool isSelected;
  late String name;
  late IconData icon;
  GridElement(
      {required this.icon, required this.isSelected, required this.name});
}

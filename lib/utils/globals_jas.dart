library globals;

import 'package:flutter/material.dart';

int lightSetting = 2; // Added by Jas to allow for different colour schemes
String activeHubID = "";
var DeviceObject;
String currentUser = "";
bool gotSettings = false;
bool gotLightSettings = false;
Color _lightSettingColour = Color.fromARGB(0, 255, 255, 255);

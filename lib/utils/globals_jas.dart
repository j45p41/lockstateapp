library globals;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

int lightSetting = 2; // Added by Jas to allow for different colour schemes
String activeHubID = "";
var DeviceObject;
String currentUser = "";
bool gotSettings = false;
bool gotLightSettings = false;
Color _lightSettingColour = const Color.fromARGB(0, 255, 255, 255);
bool showSignalStrength = false;
String email = '';
bool emailSucess = false;
String snapdata = '';
bool showBatteryPercentage = false;
FirebaseAuthException? e; // Added to store Firebase auth exceptions

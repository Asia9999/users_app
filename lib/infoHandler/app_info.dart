import 'package:flutter/cupertino.dart';
import 'package:users_app/models/directions.dart';

class AppInfo extends ChangeNotifier
{
  Directions? userPickUpLocation;

//update pickup address
  void updatePickUpLocationAddress(Directions userPickUpAddress)
  {
    userPickUpLocation = userPickUpAddress;
    notifyListeners();
  }
}
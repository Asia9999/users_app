import 'package:firebase_auth/firebase_auth.dart';
import 'package:users_app/models/direction_details_info.dart';
import 'package:users_app/models/driver.dart';
import 'package:users_app/models/user_model.dart';

final FirebaseAuth fAuth = FirebaseAuth.instance;
User? currentFirebaseUser;
UserModel? userModelCurrentInfo;
List<Driver> dList = []; //online drivers Information List
DirectionDetailsInfo? tripDirectionDetailsInfo;
String? chosenDriverId = "";
String cloudMessagingServerToken =
    "key=AAAApOgYFwU:APA91bFiMUp6UkfIEeNY0QIQEd5rCQ-br68nH__S9lVUDn6u-bEZhsQGnH3TAXZcLlvvpOPdOMGF9BjXHx1liqsg6lO6RI82jJbpsDLQe1zz1a893Nr-V1QKO5A-d-XxKYbTdjBSbkbK";
String userDropOffAddress = "";
String driverCarDetails = "";
String driverName = "";
String driverPhone = "";
double countRatingStars = 0.0;
String titleStarsRating = "";

double price = 0.0;

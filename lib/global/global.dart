import 'package:firebase_auth/firebase_auth.dart';
import 'package:users_app/models/user_model.dart';
//import 'package:firebase_core/firebase_core.dart';

final FirebaseAuth fAuth =FirebaseAuth.instance;
User? currentFirebaseUser;
UserModel? userModelCurrentInfo;
List dList = []; //online drivers Information List
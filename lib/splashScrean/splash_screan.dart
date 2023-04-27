import 'dart:async';
import 'package:flutter/material.dart';
import 'package:users_app/authentication/login-screen.dart';
import 'package:users_app/mainScreens/main_screen.dart';

import '../global/global.dart';

class MySplashScrean extends StatefulWidget {
  const MySplashScrean({Key? key}) : super(key: key);

  @override
  State<MySplashScrean> createState() => _MySplashScreanState();
}

class _MySplashScreanState extends State<MySplashScrean> {
  //display timer
  startTimer(){
    Timer(const Duration(seconds: 3),()async
    {
      if(await fAuth.currentUser != null)
        {
          currentFirebaseUser=fAuth.currentUser;
          // send user to home screen
          Navigator.push(context, MaterialPageRoute(builder: (c)=> MainsScreen()));

        }
      else
        {
          // send user to home screen
         Navigator.push(context, MaterialPageRoute(builder: (c)=> LoginScreen()));

        }
       });
  }
  
  @override
  //executed atomatically
  void initState() {
    // TODO: implement initState
    super.initState();
    
    startTimer(); //calling method
  }
  @override
  Widget build(BuildContext context) {
    return Container(
    color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("images/Logo.jpeg"),
           const Text(
              "Welcome to Group Ride Hailing",
              style: TextStyle(
                fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),
            ),
            const Text(
              "                                     "
                  "  A ride is just a click away Share "
                  "  your ride at the lowest cost ",
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}

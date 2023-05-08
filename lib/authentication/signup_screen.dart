import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:users_app/authentication/login-screen.dart';
import 'package:users_app/splashScrean/splash_screan.dart';

import '../global/global.dart';
import '../widgets/progress_dialog.dart';

class SignUpScreen extends StatefulWidget
{
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}


class _SignUpScreenState extends State<SignUpScreen>
{

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();




  validateFrom() {
    if (nameTextEditingController.text.length < 3) {
      Fluttertoast.showToast(msg: "Name must be at least 3 character.");
    }
    else if (!emailTextEditingController.text.contains("@")) {
      Fluttertoast.showToast(msg: "Email address is not Valid.");
    }
    else if (phoneTextEditingController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Phone number is required.");
    }
    else if (passwordTextEditingController.text.length < 6) {
      Fluttertoast.showToast(msg: "Password must be at least 6 character.");
     }
    else
    {
      saveUserInfoNow();
    }
  }

  saveUserInfoNow() async
  {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext c)
        {
          return ProgressDialog(message:"Processing, Please wait...",);

        }
    );
    //firebase
    final User? firebaseUser =(
        await fAuth.createUserWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          //for count the extra space
          password: passwordTextEditingController.text.trim(),
        ).catchError((msg)
        {
         Navigator.pop(context);
         Fluttertoast.showToast(msg: "Error" + msg.toString());

        })
    ).user;
    if(firebaseUser != null)
    {
       Map usersMap =
       {
         "id" :firebaseUser.uid,
         "name": nameTextEditingController.text.trim(),
         "email" :emailTextEditingController.text.trim(),
         "phone":phoneTextEditingController.text.trim(),
       };
       //all driver information
     DatabaseReference reference =  FirebaseDatabase.instance.ref().child("users");
       reference.child(firebaseUser.uid).set(usersMap);


       currentFirebaseUser = firebaseUser;
       Fluttertoast.showToast(msg: "Account has been Created.");
       Navigator.push(context, MaterialPageRoute(builder: (c)=> MySplashScrean()));
    }
    else
    {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Account has not been created");

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
          const SizedBox(height: 10,),
            Padding(
              padding :const EdgeInsets.all(20.0),
             child: Image.asset("images/Logo.jpeg"),
            ) ,
            const SizedBox(height: 10,),
           const Text(
              "Register as a Passenger",
                  style :TextStyle(
                    fontSize: 26,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextField(
              controller: nameTextEditingController,
              style: const TextStyle(
                color: Colors.grey
              ),
              decoration: const InputDecoration(
                labelText: "Name",
                hintText: "Name",
                enabledBorder: UnderlineInputBorder(
                   borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                labelStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),

              ),
            ),

            TextField(
              controller: emailTextEditingController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                  color: Colors.grey
              ),
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "Email",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                labelStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),

              ),
            ),

            TextField(
              controller: phoneTextEditingController,
              keyboardType: TextInputType.phone,

              style: const TextStyle(
                  color: Colors.grey
              ),
              decoration: const InputDecoration(
                labelText: "Phone",
                hintText: "Phone",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                labelStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),

              ),
            ),

            TextField(
              controller: passwordTextEditingController,
              keyboardType: TextInputType.text,
              obscureText: true,
              style: const TextStyle(
                  color: Colors.grey
              ),
              decoration: const InputDecoration(
                labelText: "Password",
                hintText: "Password",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                labelStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),

              ),
            ),

            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: ()
              {
                validateFrom();
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.purpleAccent,
              ),
              child: const Text(
                "Create account ",
                style: TextStyle(
                 color: Colors.white,
                fontSize:18,
                ),
              ),
            ),

            TextButton(
              child: const Text(
                "Already have an account? Login here",
                style: TextStyle(color: Colors.grey) ,
              ),
              onPressed: ()
              {
                Navigator.push(context, MaterialPageRoute(builder: (c)=>LoginScreen()));

              },
            ),

          ],
        ),
      ),
      ),
    );
  }
}

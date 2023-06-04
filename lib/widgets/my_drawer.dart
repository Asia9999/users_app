import 'package:flutter/material.dart';
import 'package:users_app/global/global.dart';
import 'package:users_app/splashScrean/splash_screan.dart';

import '../mainScreens/about_screen.dart';
import '../mainScreens/profile_screen.dart';
import '../mainScreens/trips_history_screen.dart';


class MyDrawer extends StatefulWidget
{
  String? name;
  String? email;


  MyDrawer({this.name,this.email});

  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer>
{
  @override
  Widget build(BuildContext context)
  {
    return Drawer(
      child: ListView(
        children: [
          //header of drawer
          Container(
            height: 165,
            color: Colors.deepPurple,
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
               const Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.purpleAccent,
                  ),
                const SizedBox(width: 16,),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10,),
                      Text(
                        widget.email.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,

                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0,),

          //body of header
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (c)=> TripsHistoryScreen()));

            },
            child: const ListTile(
              leading: Icon(Icons.history,color: Colors.purple,),
              title: Text(
                "History",
                style: TextStyle(
                  color: Colors.purpleAccent
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (c)=> ProfileScreen()));

            },
            child: const ListTile(
              leading: Icon(Icons.person,color: Colors.purple,),
              title: Text(
                "Visit Profile",
                style: TextStyle(
                    color: Colors.purpleAccent
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (c)=> AboutScreen()));

            },
            child: const ListTile(
              leading: Icon(Icons.info,color: Colors.purple,),
              title: Text(
                "About Us",
                style: TextStyle(
                    color: Colors.purpleAccent
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: (){
               fAuth.signOut();
                   Navigator.push(context, MaterialPageRoute(builder: (c)=> const MySplashScrean()));
            },
            child: const ListTile(
              leading: Icon(Icons.logout,color: Colors.purple,),
              title: Text(
                "Sign Out",
                style: TextStyle(
                    color: Colors.purpleAccent
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

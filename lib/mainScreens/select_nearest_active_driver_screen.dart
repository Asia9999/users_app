import 'package:flutter/material.dart';
import 'package:users_app/global/global.dart';
import 'package:smooth_star_rating_nsafe/smooth_star_rating.dart';
import 'package:flutter/services.dart';

class SelectNearestActiveDriversScreen extends StatefulWidget
{
  const SelectNearestActiveDriversScreen({Key? key}): super(key: key);

  @override
  _SelectNearestActiveDriversScreenState createState() => _SelectNearestActiveDriversScreenState();
}

class _SelectNearestActiveDriversScreenState extends State<SelectNearestActiveDriversScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.purpleAccent,
        title: const Text(
          "Nearest Online Drivers",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.close, color: Colors.purple,
          ),
          onPressed: ()
          {
            //remove the ride request from database
            SystemNavigator.pop();
          },
          ),
        ),
      body: ListView.builder(
        itemCount: dList.length,
        itemBuilder: (BuildContext context, int index )
          {
            return Card(
              color: Colors.grey,
              elevation: 3,
              shadowColor: Colors.purpleAccent,
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Image.asset(
                    "images/" + dList[index]["car_details"]["type"].toString() + ".jpeg",
                    width: 70,
                  ),
                ),
                title:Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                     dList[index]["name"],
                     style: const TextStyle(
                       fontSize: 14,
                       color: Colors.white,
                     ),
                    ),
                    Text(
                      dList[index]["car_details"]["car_model"],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purpleAccent,
                    ),
                    ),
                    SmoothStarRating(
                      rating: 3.5,
                      color: Colors.white,
                      borderColor: Colors.white,
                      allowHalfRating: true,
                      starCount: 5,
                      size: 15,
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "3",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2,),
                    Text(
                      "13 km",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                        fontSize: 12
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),

      );

  }
  }



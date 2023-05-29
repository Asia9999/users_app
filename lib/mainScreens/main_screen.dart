import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:shared_preferences/shared_preferences.dart';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:users_app/assistants/assistant_methods.dart';
import 'package:users_app/assistants/geofire_assistant.dart';
import 'package:users_app/authentication/login-screen.dart';
import 'package:users_app/global/global.dart';
import 'package:users_app/infoHandler/app_info.dart';
import 'package:users_app/main.dart';
import 'package:users_app/mainScreens/search_places_screen.dart';
import 'package:users_app/mainScreens/select_nearest_active_driver_screen.dart';
import 'package:users_app/models/active_nearby_available_drivers.dart';
import 'package:users_app/models/direction_details_info.dart';
import 'package:users_app/models/ticket.dart';
import 'package:users_app/widgets/my_drawer.dart';
import 'package:users_app/widgets/progress_dialog.dart';

class MainsScreen extends StatefulWidget {
  @override
  State<MainsScreen> createState() => _MainsScreenState();
}

class _MainsScreenState extends State<MainsScreen> {
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();

  @override
  void initState() {
    super.initState();
    context.read<AppInfo>().checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppInfo>(
      builder: (context, value, child) => Scaffold(
        key: value.sKey,
        drawer: Container(
          width: 240,
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
            ),
            child: MyDrawer(
              name: value.userName,
              email: value.userEmail,
            ),
          ),
        ),
        body: Stack(
          children: [
            GoogleMap(
              padding: EdgeInsets.only(bottom: value.bottomPaddingOfMap),
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: AppInfo.kGooglePlex,
              polylines: value.polyLineSet,
              markers: value.markersSet,
              circles: value.circlesSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                value.newGoogleMapController = controller;

                value.bottomPaddingOfMap = 240;

                value.locateUserPosition();
              },
            ),

            //custom button for drawer
            Positioned(
              top: 30,
              left: 14,
              child: GestureDetector(
                onTap: () {
                  if (value.openNavigationDrawer) {
                    value.sKey.currentState!.openDrawer();
                  } else {
                    //restart-refresh-minimize app progmatically
                    SystemNavigator.pop();
                  }
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    value.openNavigationDrawer ? Icons.menu : Icons.close,
                    color: Colors.purple,
                  ),
                ),
              ),
            ),
            // ui for searching location
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSize(
                curve: Curves.easeIn,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  height: value.searchLocationContainerHeight,
                  decoration: const BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      topLeft: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    child: Column(
                      children: [
                        //from
                        Row(
                          children: [
                            const Icon(
                              Icons.add_location_alt_outlined,
                              color: Colors.purpleAccent,
                            ),
                            const SizedBox(
                              width: 12.0,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "From",
                                  style: TextStyle(
                                      color: Colors.purpleAccent, fontSize: 12),
                                ),
                                Text(
                                  Provider.of<AppInfo>(context)
                                              .userPickUpLocation !=
                                          null
                                      ? "${(value.userPickUpLocation!.locationName!).substring(0, 24)}..."
                                      : "not getting address",
                                  style: const TextStyle(
                                      color: Colors.purpleAccent, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10.0,
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.purpleAccent,
                        ),

                        const SizedBox(
                          height: 16.0,
                        ),
                        // to

                        GestureDetector(
                          onTap: () async {
                            // go to  Search Places Screen
                            var responseFromSearchScreen = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => SearchPlacesScreen()));

                            if (responseFromSearchScreen == "obtainedDropoff") {
                              value.openNavigationDrawer = false;
                              //draw routes - draw polyline

                              await value.drawPolyLineFromOriginToDestination();
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_location_alt_outlined,
                                color: Colors.purpleAccent,
                              ),
                              const SizedBox(
                                width: 12.0,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "To",
                                    style: TextStyle(
                                        color: Colors.purpleAccent,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    Provider.of<AppInfo>(context)
                                                .userDropOffLocation !=
                                            null
                                        ? Provider.of<AppInfo>(context)
                                            .userDropOffLocation!
                                            .locationName!
                                        : "Where you want to go",
                                    style: const TextStyle(
                                        color: Colors.purpleAccent,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 10.0,
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.purpleAccent,
                        ),

                        const SizedBox(
                          height: 16.0,
                        ),
                        ElevatedButton(
                          child: const Text("Requeest a Ride"),
                          onPressed: () {
                            if (value.userDropOffLocation != null) {
                              value.saveRideRequestInformation();
                            } else {
                              Fluttertoast.showToast(
                                  msg: "Please select destionation location");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              primary: Colors.purple[500],
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: value.waitingResponseFromDriverContainerHeight,
                decoration: const BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: AnimatedTextKit(
                      animatedTexts: [
                        FadeAnimatedText(
                          'Waiting for Response\nfrom Driver',
                          duration: const Duration(seconds: 6),
                          textAlign: TextAlign.center,
                          textStyle: const TextStyle(
                              fontSize: 30.0,
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold),
                        ),
                        ScaleAnimatedText(
                          'Please wait...',
                          duration: const Duration(seconds: 10),
                          textAlign: TextAlign.center,
                          textStyle: const TextStyle(
                              fontSize: 32.0,
                              color: Colors.purpleAccent,
                              fontFamily: 'Canterbury'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            //ui for displaying assigned driver information
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: value.assignedDriverInfoContainerHeight,
                decoration: const BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //status of ride
                      Center(
                        child: Text(
                          value.driverRideStatus,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20.0,
                      ),

                      const Divider(
                        height: 2,
                        thickness: 2,
                        color: Colors.purpleAccent,
                      ),

                      const SizedBox(
                        height: 20.0,
                      ),

                      //driver vehicle details
                      Text(
                        driverCarDetails,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.purpleAccent,
                        ),
                      ),

                      const SizedBox(
                        height: 2.0,
                      ),

                      //driver name
                      Text(
                        driverName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                        ),
                      ),

                      const SizedBox(
                        height: 20.0,
                      ),

                      const Divider(
                        height: 2,
                        thickness: 2,
                        color: Colors.purpleAccent,
                      ),

                      const SizedBox(
                        height: 20.0,
                      ),

                      //call driver button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            primary: Colors.purple,
                          ),
                          icon: const Icon(
                            Icons.phone_android,
                            color: Colors.white38,
                            size: 22,
                          ),
                          label: const Text(
                            "Call Driver",
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      //ui for waiting response from driver
    );
  }
}

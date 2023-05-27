import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();


  @override
  void initState() {
    super.initState();
    context.read<AppInfo>().checkIfLocationPermissionAllowed();
  }




  @override
  Widget build(BuildContext context) {

    return Consumer<AppInfo>(
      builder: (context, value, child) => Scaffold(
        key: sKey,
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
              initialCameraPosition: _kGooglePlex,
              polylines: value.polyLineSet,
              markers: value.markersSet,
              circles: value.circlesSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                value.newGoogleMapController = controller;

                setState(() {
                  value.bottomPaddingOfMap = 240;
                });

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
                    sKey.currentState!.openDrawer();
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
                                      ? (Provider.of<AppInfo>(context)
                                                  .userPickUpLocation!
                                                  .locationName!)
                                              .substring(0, 24) +
                                          "..."
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
                              setState(() {
                                value.openNavigationDrawer = false;
                              });
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
                            if (Provider.of<AppInfo>(context, listen: false)
                                    .userDropOffLocation !=
                                null) {
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
          ],
        ),
      ),
    );
  }


}

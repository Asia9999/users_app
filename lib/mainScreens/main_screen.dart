import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:users_app/assistants/assistant_methods.dart';
import 'package:users_app/global/global.dart';
import 'package:users_app/mainScreens/search_places_screen.dart';
import 'package:users_app/widgets/my_drawer.dart';

import '../authentication/login-screen.dart';
import '../infoHandler/app_info.dart';


class MainsScreen extends StatefulWidget
{
  @override
  State<MainsScreen> createState() => _MainsScreenState();
}




class _MainsScreenState extends State<MainsScreen>
{

  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController ? newGoogleMapController;


  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey <ScaffoldState> sKey =GlobalKey<ScaffoldState>();
  double searchLocationContainerHeight =220;

  Position? userCurrentPosition;
  var geoLocator = Geolocator();

  LocationPermission? _locationPermission ;

  double bottmPaddingOfMap =0;

  checkIfLocationPermissionAllowed() async
  {
    _locationPermission = await Geolocator.requestPermission();

    if(_locationPermission == LocationPermission.denied)
      {
        _locationPermission = await Geolocator.requestPermission();
      }
  }

  locateUserPosition() async
  {
    //get the position of current user
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;
    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    //to move
    CameraPosition cameraPosition =CameraPosition(target: latLngPosition,zoom: 14);
    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoOrdinates(userCurrentPosition!, context);
    print("this is your address = " + humanReadableAddress);
  }
  @override
  void initState() {

    super.initState();
    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      key: sKey,
      drawer: Container(
        width: 240,
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.white,
          ),
          child: MyDrawer(
            name: userModelCurrentInfo?.name,
            email: userModelCurrentInfo?.email,
          ),
        ),
      ),
      body: Stack(
        children: [

          GoogleMap(
            padding: EdgeInsets.only(bottom: bottmPaddingOfMap),
            mapType: MapType.normal,
            myLocationEnabled: true,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: true,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller)
            {
              _controllerGoogleMap.complete(controller);
             newGoogleMapController = controller ;

            setState(() {
              bottmPaddingOfMap = 240;

            });

             locateUserPosition();
            },
          ),

          //custom button for drawer
          Positioned(
            top: 30,
            left: 14,
            child: GestureDetector(
              onTap: ()
              {
                   //onclick display nivegator
                sKey.currentState!.openDrawer();
              },
              child: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(
                  Icons.menu,
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
                height: searchLocationContainerHeight,
                decoration: const BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    children: [
                      //from
                      Row(
                        children: [
                         const Icon(Icons.add_location_alt_outlined, color: Colors.purpleAccent,),
                          const SizedBox(width: 12.0,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "From",
                                style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
                              ),
                              Text(
                                Provider.of<AppInfo>(context).userPickUpLocation != null
                                    ? (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0,24) + "..."
                                    : "not getting address",
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10.0,),
                     const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.purpleAccent,
                      ),

                      const SizedBox(height: 16.0,),
                      // to

                      GestureDetector(
                           onTap: ()
                           {
                             // go to  Search Places Screen
                             Navigator.push(context, MaterialPageRoute(builder: (c)=> SearchPlacesScreen()));
                             },
                        child: Row(
                          children: [
                            const Icon(Icons.add_location_alt_outlined, color: Colors.purpleAccent,),
                            const SizedBox(width: 12.0,),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "To",
                                  style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
                                ),
                                Text(
                                  "Where you want to go",
                                  style: const TextStyle(color: Colors.purpleAccent, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10.0,),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.purpleAccent,
                      ),

                      const SizedBox(height: 16.0,),
                      ElevatedButton(
                        child:const Text(
                          "Requeest a Ride"
                        ),
                        onPressed: ()
                        {

                        },
                        style: ElevatedButton.styleFrom(
                          primary: Colors.purpleAccent,
                            textStyle:const TextStyle(fontSize: 16,fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

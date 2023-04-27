import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:users_app/global/global.dart';

import '../authentication/login-screen.dart';


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


  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller)
            {
              _controllerGoogleMap.complete(controller);
             newGoogleMapController = controller ;
            },
          ),
        ],
      ),
    );
  }
}

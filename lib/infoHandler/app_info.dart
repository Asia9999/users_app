import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:users_app/main.dart';
import 'package:users_app/models/directions.dart';
import 'dart:async';

import '../assistants/assistant_methods.dart';
import '../assistants/geofire_assistant.dart';
import '../global/global.dart';
import '../mainScreens/select_nearest_active_driver_screen.dart';
import '../models/active_nearby_available_drivers.dart';
import '../models/ticket.dart';
import '../widgets/progress_dialog.dart';

class AppInfo extends ChangeNotifier {
  // variables
  Directions? userPickUpLocation, userDropOffLocation;
  LocationPermission? _locationPermission;
  Position? userCurrentPosition;
  GoogleMapController? newGoogleMapController;
  String userName = "your Name";
  String userEmail = "your Email";
  List<Ticket> tickets = [];
  bool activeNearbyDriverKeysLoaded = false;
  Set<Marker> markersSet = {};
  Set<Circle> circlesSet = {};
  List<LatLng> pLineCoOrdinatesList = [];
  Set<Polyline> polyLineSet = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ticketSnapshot;

  double searchLocationContainerHeight = 220;

  var geoLocator = Geolocator();

  double bottomPaddingOfMap = 0;

  bool openNavigationDrawer = true;

  BitmapDescriptor? activeNearbyIcon;

  List<ActiveNearbyAvailableDrivers> onlineNearbyAvailableDriversList = [];

  DatabaseReference? referenceRideRequest;
  // end of variables

  checkIfLocationPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();

    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
    } else {
      createActiveNearbyDriverIconMarker();
    }

    if (_locationPermission == LocationPermission.deniedForever) {
      Fluttertoast.showToast(
          msg: "Location permission is denied forever, we cannot request it",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.purple,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  locateUserPosition() async {
    //get the position of current user
    Position cPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;
    LatLng latLngPosition =
        LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    //to move
    CameraPosition cameraPosition =
        CameraPosition(target: latLngPosition, zoom: 14);
    newGoogleMapController!
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    String humanReadableAddress =
        await AssistantMethods.searchAddressForGeographicCoOrdinates(
            userCurrentPosition!, navigatorKey.currentContext!);
    print("this is your address = " + humanReadableAddress);

    userName = userModelCurrentInfo!.name!;
    userEmail = userModelCurrentInfo!.email!;

    initializeGeoFireListener();
  }

  void updatePickUpLocationAddress(Directions userPickUpAddress) {
    userPickUpLocation = userPickUpAddress;
    notifyListeners();
  }

  void updateDropOffLocationAddress(Directions dropOffAddress) {
    userDropOffLocation = dropOffAddress;
    notifyListeners();
  }

  void checkAvailableTickets(GeoPoint userDestination, GeoPoint userOrigin) {
    // compare the destenation of the user with the destenation of the tickets

    try {
      log("userDestination: ${userDestination.latitude} , ${userDestination.longitude}");
      log("userOrigin: ${userOrigin.latitude} , ${userOrigin.longitude}");
      _ticketSnapshot?.cancel();
      _ticketSnapshot = FirebaseFirestore.instance
          .collection('Tickets')
          .snapshots()
          .listen((event) async {
        log("event.docs.length: ${event.docs.length}");

        if (event.docs.isNotEmpty) {
          event.docs.forEach((element) async {
            // delete all documents

            // delete all tickets that are older than 1 hour
            if (DateTime.now()
                    .difference((element.data()['time'] as Timestamp).toDate())
                    .inHours >
                1) {
              await FirebaseFirestore.instance
                  .collection('Tickets')
                  .doc(element.id)
                  .delete();
              return;
            }

            // var data = element.data();
            // if ((data['destination'] as GeoPoint).latitude.toStringAsFixed(4) ==
            //         userDestination.latitude.toStringAsFixed(4) &&
            //     (data['destination'] as GeoPoint)
            //             .longitude
            //             .toStringAsFixed(4) ==
            //         userDestination.longitude.toStringAsFixed(4) &&
            //     Geolocator.distanceBetween(
            //                 (data['origin'] as GeoPoint).latitude,
            //                 (data['origin'] as GeoPoint).longitude,
            //                 userOrigin.latitude,
            //                 userOrigin.longitude) /
            //             1000 <
            //         1) tickets.add(Ticket.fromMap(element.data(), element.id));
            // log("tickets: ${tickets.length}");

            // print(element.data());
          });
        }
        // if (tickets.isEmpty) {
        //   Fluttertoast.showToast(
        //       msg: "No tickets available",
        //       toastLength: Toast.LENGTH_SHORT,
        //       gravity: ToastGravity.BOTTOM,
        //       timeInSecForIosWeb: 1,
        //       backgroundColor: Colors.purple,
        //       textColor: Colors.white,
        //       fontSize: 16.0);
        // }

        notifyListeners();
      }) as StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?;
    } catch (e) {
      print(e.toString());
    }
  }

  initializeGeoFireListener() {
    Geofire.initialize("activeDrivers");
    Geofire.queryAtLocation(
            userCurrentPosition!.latitude, userCurrentPosition!.longitude, 10)!
        .listen((map) {
      //5 is the distance in kilometers of any active online drivers along a circle from the center
      print(map);
      if (map != null) {
        var callBack = map['callBack'];

        //latitude will be retrieved from map['latitude']
        //longitude will be retrieved from map['longitude']

        switch (callBack) {
          //whenever any driver becomes active/online
          case Geofire.onKeyEntered:
            ActiveNearbyAvailableDrivers activeNearbyAvailableDriver =
                ActiveNearbyAvailableDrivers();
            activeNearbyAvailableDriver.locationLatitude = map['latitude'];
            activeNearbyAvailableDriver.locationLongitude = map['longitude'];
            activeNearbyAvailableDriver.driverId = map['key']; //driver key
            GeoFireAssistant.activeNearbyAvailableDriversList
                .add(activeNearbyAvailableDriver);
            if (activeNearbyDriverKeysLoaded == true) {
              displayActiveDriversOnUsersMap();
            }
            break;

          //whenever any driver becomes non-active/offline
          case Geofire.onKeyExited:
            GeoFireAssistant.deleteOfflineDriverFromList(map['key']);
            displayActiveDriversOnUsersMap();
            break;

          //whenever driver moves - update driver location
          case Geofire.onKeyMoved:
            ActiveNearbyAvailableDrivers activeNearbyAvailableDriver =
                ActiveNearbyAvailableDrivers();
            activeNearbyAvailableDriver.locationLatitude = map['latitude'];
            activeNearbyAvailableDriver.locationLongitude = map['longitude'];
            activeNearbyAvailableDriver.driverId = map['key']; //driver key
            GeoFireAssistant.updateActiveNearbyAvailableDriverLocation(
                activeNearbyAvailableDriver);
            displayActiveDriversOnUsersMap();
            break;

          // display those online/active drivers on user's map
          case Geofire.onGeoQueryReady:
            activeNearbyDriverKeysLoaded = true;
            displayActiveDriversOnUsersMap();
            break;
        }
      }

      notifyListeners();
    });
  }

  displayActiveDriversOnUsersMap() {
    markersSet.clear();
    circlesSet.clear();

    Set<Marker> driversMarkerSet = Set<Marker>();
    for (ActiveNearbyAvailableDrivers eachDriver
        in GeoFireAssistant.activeNearbyAvailableDriversList) {
      LatLng eachDriverActivePosition =
          LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);

      Marker marker = Marker(
        markerId: MarkerId("driver" + eachDriver.driverId!),
        position: eachDriverActivePosition,
        //icon: activeNearbyIcon!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueMagenta), /////////
        rotation: 360,
      );

      driversMarkerSet.add(marker);
    }
    markersSet = driversMarkerSet;
  }

  Future<void> drawPolyLineFromOriginToDestination() async {
    var originPosition = userPickUpLocation;
    var destinationPosition = userDropOffLocation;

    var originLatLng = LatLng(
        originPosition!.locationLatitude!, originPosition.locationLongitude!);
    var destinationLatLng = LatLng(destinationPosition!.locationLatitude!,
        destinationPosition.locationLongitude!);

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => ProgressDialog(
        message: "Please wait...",
      ),
    );

    var directionDetailsInfo =
        await AssistantMethods.obtainOriginToDestinationDirectionDetails(
            originLatLng, destinationLatLng);
    tripDirectionDetailsInfo = directionDetailsInfo;

    Navigator.pop(navigatorKey.currentContext!);

    print("These are points = ");
    print(directionDetailsInfo!.e_points);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodedPolyLinePointsResultList =
        pPoints.decodePolyline(directionDetailsInfo.e_points!);

    pLineCoOrdinatesList.clear();

    if (decodedPolyLinePointsResultList.isNotEmpty) {
      decodedPolyLinePointsResultList.forEach((PointLatLng pointLatLng) {
        pLineCoOrdinatesList
            .add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    polyLineSet.clear();

    Polyline polyline = Polyline(
      color: Colors.purpleAccent,
      polylineId: const PolylineId("PolylineID"),
      jointType: JointType.round,
      points: pLineCoOrdinatesList,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
    );

    polyLineSet.add(polyline);

    LatLngBounds boundsLatLng;
    if (originLatLng.latitude > destinationLatLng.latitude &&
        originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng =
          LatLngBounds(southwest: destinationLatLng, northeast: originLatLng);
    } else if (originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
        northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude),
      );
    } else if (originLatLng.latitude > destinationLatLng.latitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
        northeast: LatLng(originLatLng.latitude, destinationLatLng.longitude),
      );
    } else {
      boundsLatLng =
          LatLngBounds(southwest: originLatLng, northeast: destinationLatLng);
    }

    newGoogleMapController!
        .animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 65));

    Marker originMarker = Marker(
      markerId: const MarkerId("originID"),
      infoWindow:
          InfoWindow(title: originPosition.locationName, snippet: "Origin"),
      position: originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
    );

    Marker destinationMarker = Marker(
      markerId: const MarkerId("destinationID"),
      infoWindow: InfoWindow(
          title: destinationPosition.locationName, snippet: "Destination"),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );

    markersSet.add(originMarker);
    markersSet.add(destinationMarker);

    Circle originCircle = Circle(
      circleId: const CircleId("originID"),
      fillColor: Colors.deepPurpleAccent,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: originLatLng,
    );

    Circle destinationCircle = Circle(
      circleId: const CircleId("destinationID"),
      fillColor: Colors.lightGreenAccent,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: destinationLatLng,
    );

    circlesSet.add(originCircle);
    circlesSet.add(destinationCircle);

    notifyListeners();
  }

  searchNearestOnlineDrivers() async {
    // no active driver available
    if (onlineNearbyAvailableDriversList.length == 0) {
      //cancel the RideRequest information

      referenceRideRequest!.remove();
      polyLineSet.clear();
      markersSet.clear();
      circlesSet.clear();
      pLineCoOrdinatesList.clear();

      Fluttertoast.showToast(
          msg:
              " No online nearest driver available Search again for ride after some time, Restarting App Now. ");

      return;
    }

    //active driver available
    await retrieveOnlineDriversInformation(onlineNearbyAvailableDriversList);

    var response = await Navigator.push(
        navigatorKey.currentContext!,
        MaterialPageRoute(
            builder: (c) => SelectNearestActiveDriversScreen(
                referenceRideRequest: referenceRideRequest)));

    if (response == "driverChoosed") {
      FirebaseDatabase.instance
          .ref()
          .child("drivers")
          .child(chosenDriverId!)
          .once()
          .then((snap) {
        if (snap.snapshot.value != null) {
          //send notification to that specific driver
          sendNotificationToDriverNow(chosenDriverId!);
        } else {
          Fluttertoast.showToast(msg: "This driver do not exist. Try again.");
        }
      });
    }
  }

  saveRideRequestInformation() {
    //save the RideRequest information
    // 1

    referenceRideRequest =
        FirebaseDatabase.instance.ref().child("All Ride Requests").push();
    var originLocation = userPickUpLocation;
    var destinationLocation = userDropOffLocation;

    Map originLocationMap = {
      //"key": value
      "latitude": originLocation!.locationLatitude!.toStringAsFixed(3),
      "longitude": originLocation.locationLongitude!.toStringAsFixed(3),
    };

    Map destinationLocationMap = {
      //"key": value
      "latitude": destinationLocation!.locationLatitude!.toStringAsFixed(2),
      "longitude": destinationLocation.locationLongitude!.toStringAsFixed(2),
    };

    // Map userInformationMap = {
    //   "origin": originLocationMap,
    //   "destination": destinationLocationMap,
    //   "time": DateTime.now().toString(),
    //   "userName": userModelCurrentInfo!.name,
    //   "userPhone": userModelCurrentInfo!.phone,
    //   "originAddress": originLocation.locationName,
    //   "destinationAddress": destinationLocation.locationName,
    //   "driverId": "waiting",
    // };

    // referenceRideRequest!.set(userInformationMap);

    // onlineNearbyAvailableDriversList =
    //     GeoFireAssistant.activeNearbyAvailableDriversList;

    // FirebaseFirestore.instance
    //     .collection('Tickets')
    //     .add(Ticket(
    //             time: Timestamp.now(),
    //             destination: GeoPoint(24.7557919, 46.6325296),
    //             passengers: [
    //               Passenger(
    //                   name: "name",
    //                   phone: "phone",
    //                   id: "id",
    //                   origin: GeoPoint(24.689676, 46.683228),
    //                   isPickedUp: false)
    //             ],
    //             status: "status",
    //             id: "id",
    //             origin: GeoPoint(24.689676, 46.683228))
    //         .toMap())
    //     .then((value) {
    //   log("value.docs.length: ${value.id}");
    // });

    checkAvailableTickets(
        GeoPoint(destinationLocation.locationLatitude!,
            destinationLocation.locationLongitude!),
        GeoPoint(originLocation.locationLatitude!,
            originLocation.locationLongitude!));

    // searchNearestOnlineDrivers();
  }

  sendNotificationToDriverNow(String chosenDriverId) {
    //assign/SET rideRequestId to newRideStatus in
    // Drivers Parent node for that specific choosen driver
    FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(chosenDriverId)
        .child("newRideStatus")
        .set(referenceRideRequest!.key);

    //automate the push notification
  }

  retrieveOnlineDriversInformation(List onlineNearestDriversList) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("drivers");
    for (int i = 0; i < onlineNearestDriversList.length; i++) {
      await ref
          .child(onlineNearestDriversList[i].driverId.toString())
          .once()
          .then((dataSnapShot) {
        var driverKeyInfo = dataSnapShot.snapshot.value;
        dList.add(driverKeyInfo);
        // print("DriverKey Information"+ dList.toString());
      });
    }
  }

  createActiveNearbyDriverIconMarker() {
    if (activeNearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(
          navigatorKey.currentContext!,
          size: const Size(4, 4));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "images/car.jpg")
          .then((value) {
        activeNearbyIcon = value;
      });
    }
  }
}

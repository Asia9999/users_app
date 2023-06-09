import 'dart:developer';
import 'dart:typed_data';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:users_app/main.dart';
import 'package:users_app/models/direction_details_info.dart';
import 'package:users_app/models/directions.dart';
import 'package:users_app/models/driver.dart';
import 'dart:async';

import '../assistants/assistant_methods.dart';
import '../assistants/geofire_assistant.dart';
import '../global/global.dart';
import '../mainScreens/select_nearest_active_driver_screen.dart';
import '../models/active_nearby_available_drivers.dart';
import '../models/ticket.dart';
import '../models/trips_history_model.dart';
import '../widgets/progress_dialog.dart';
import 'dart:ui' as ui;

class AppInfo extends ChangeNotifier {
// variables
  // User Information
  String userName = "your Name";
  String userEmail = "your Email";
  int countTotalTrips = 0;
  List<String> historyTripsKeysList = [];
  List<TripsHistoryModel> allTripsHistoryInformationList = [];

// Map Configuration
  static const CameraPosition kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  double bottomPaddingOfMap = 0;

// Container Heights
  double searchLocationContainerHeight = 220;
  double waitingResponseFromDriverContainerHeight = 0;
  double assignedDriverInfoContainerHeight = 0;

// Booleans
  bool activeNearbyDriverKeysLoaded = false;
  bool openNavigationDrawer = true;
  bool requestPositionInfo = true;

// Lists
  List<Ticket> tickets = [];
  List<ActiveNearbyAvailableDrivers> onlineNearbyAvailableDriversList = [];
  List<LatLng> pLineCoOrdinatesList = [];

// Sets
  Set<Marker> markersSet = {};
  Set<Circle> circlesSet = {};
  Set<Polyline> polyLineSet = {};

// Other Variables
  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();

// Location and Maps
  Directions? userPickUpLocation, userDropOffLocation;
  LocationPermission? _locationPermission;
  Position? userCurrentPosition;
  GoogleMapController? newGoogleMapController;

// Subscriptions
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ticketSnapshot;
  StreamSubscription<DatabaseEvent>? tripRideRequestInfoStreamSubscription;

// Geolocation
  var geoLocator = Geolocator();

// Icons
  BitmapDescriptor? activeNearbyIcon;

// Database and References
  DatabaseReference? referenceRideRequest;

  // Widgets
  Widget ticketInfoWidget = Container();

// Ride Status
  String driverRideStatus = "Driver is Coming";
  String userRideRequestStatus = "";
  String availableTicketID = "";
  Ticket? ticket;
  Driver? ticketDriver;
  String? timeToArrive;
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
    notifyListeners();
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
    notifyListeners();
  }

  void updatePickUpLocationAddress(Directions userPickUpAddress) {
    userPickUpLocation = userPickUpAddress;
    notifyListeners();
  }

  void updateDropOffLocationAddress(Directions dropOffAddress) {
    userDropOffLocation = dropOffAddress;
    notifyListeners();
  }

  initializeGeoFireListener() {
    log("initializeGeoFireListener");
    Geofire.initialize("activeDrivers");
    Geofire.queryAtLocation(
            userCurrentPosition!.latitude, userCurrentPosition!.longitude, 10)!
        .listen((map) {
      log("map: $map");
      //5 is the distance in kilometers of any active online drivers along a circle from the center
      log(map.toString());
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
          default:
            ActiveNearbyAvailableDrivers activeNearbyAvailableDriver =
                ActiveNearbyAvailableDrivers();
            activeNearbyAvailableDriver.locationLatitude = map['latitude'];
            activeNearbyAvailableDriver.locationLongitude = map['longitude'];
            activeNearbyAvailableDriver.driverId = map['key']; //driver key
            GeoFireAssistant.updateActiveNearbyAvailableDriverLocation(
                activeNearbyAvailableDriver);
            displayActiveDriversOnUsersMap();
        }
      }

      notifyListeners();
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  displayActiveDriversOnUsersMap() async {
    log("displayActiveDriversOnUsersMap");
    markersSet.clear();
    circlesSet.clear();

    final Uint8List markerIcon =
        await getBytesFromAsset('images/car_icon.png', 200);

    // var custom = await BitmapDescriptor.fromAssetImage(
    //     const ImageConfiguration(devicePixelRatio: 1, size: Size(20, 10)),
    //     "images/car_icon.png");

    Set<Marker> driversMarkerSet = Set<Marker>();
    for (ActiveNearbyAvailableDrivers eachDriver
        in GeoFireAssistant.activeNearbyAvailableDriversList) {
      log("eachDriver: ${eachDriver.driverId}");

      LatLng eachDriverActivePosition =
          LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);

      if (ticketDriver != null && eachDriver.driverId == ticketDriver!.id) {
        log("1: " + eachDriverActivePosition.toString());
        updateArrivalTimeToUserPickupLocation(eachDriverActivePosition);
      }

      if (ticket != null && ticket!.driverId == eachDriver.driverId) {
        var passenger = ticket!.passengers!
            .where((element) => element.id == userModelCurrentInfo!.id)
            .first;

        if (passenger.isPickedUp == true) {
          timeToArrive =
              await AssistantMethods.obtainOriginToDestinationDirectionDetails(
            LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!),
            LatLng(userDropOffLocation!.locationLatitude!,
                userDropOffLocation!.locationLongitude!),
          ).then((value) => value!.duration_text.toString());

          showUIForStartedTrip();
        }
      }

      Marker marker = Marker(
        markerId: MarkerId("driver" + eachDriver.driverId!),
        position: eachDriverActivePosition,
        //icon: activeNearbyIcon!,
        //car icon
        icon: BitmapDescriptor.fromBytes(markerIcon),
        rotation: 360,
      );

      driversMarkerSet.add(marker);
    }
    markersSet = driversMarkerSet;
    notifyListeners();
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

    await saveRideRequestInformation();
    if (onlineNearbyAvailableDriversList.length == 0) {
      //cancel the RideRequest information

      // referenceRideRequest!.remove();
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
      //send notification to that specific driver
      sendNotificationToDriverNow(chosenDriverId!);
      showWaitingResponseFromDriverUI();
      log("chosenDriverId: $chosenDriverId");

      //Response from a Driver
      FirebaseDatabase.instance
          .ref()
          .child("drivers")
          .child(chosenDriverId!)
          .onValue
          .listen((eventSnapshot) {
        //1. driver has cancel the rideRequest :: Push Notification
        // (newRideStatus = idle)
        if ((eventSnapshot.snapshot.value as Map)['newRideStatus'] == "idle") {
          Fluttertoast.showToast(
              msg:
                  "The driver has cancelled your request , Please choose another driver.");

          Future.delayed(const Duration(milliseconds: 3000), () {
            Fluttertoast.showToast(msg: "Please Restart App Now.");
          });
        }

        //2. driver has accept the rideRequest :: Push Notification
        // (newRideStatus = accepted)
        if ((eventSnapshot.snapshot.value as Map)['newRideStatus'] ==
            "accepted") {
          //design and display ui for displaying assigned driver information

          // assign driver information to the user
          ticketDriver = Driver(
              name: (eventSnapshot.snapshot.value as Map)['name'].toString(),
              email: (eventSnapshot.snapshot.value as Map)['email'].toString(),
              phone: (eventSnapshot.snapshot.value as Map)['phone'].toString(),
              id: (eventSnapshot.snapshot.value as Map)['id'].toString(),
              token: (eventSnapshot.snapshot.value as Map)['token'].toString(),
              newRideStatus:
                  (eventSnapshot.snapshot.value as Map)['newRideStatus']
                      .toString(),
              car: Car(
                car_color: (eventSnapshot.snapshot.value as Map)['car_details']
                        ['car_color']
                    .toString(),
                car_model: (eventSnapshot.snapshot.value as Map)['car_details']
                        ['car_model']
                    .toString(),
                car_number: (eventSnapshot.snapshot.value as Map)['car_details']
                        ['car_number']
                    .toString(),
                type: (eventSnapshot.snapshot.value as Map)['car_details']
                        ['type']
                    .toString(),
              ));

          // log("ticket Data" + ticket!.toMap().toString());

          FirebaseFirestore.instance
              .collection('Tickets')
              .doc(ticket!.id)
              .update({
            "driverId": ticketDriver!.id,
            "status": "collecting",
            "seats": ticketDriver!.car.seats,
            "acceptNewPassenger": true,
          });

          log("ticketDriver: ${ticketDriver!.toJson()}");

          showUIForAssignedDriverInfo();
        }
        notifyListeners();
      });
    } else {
      Fluttertoast.showToast(msg: "This driver do not exist. Try again.");
    }
  }

  showUIForAssignedDriverInfo() {
    searchLocationContainerHeight = 0;

    ticketInfoWidget = Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 270,
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
                  driverRideStatus,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purpleAccent,
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      "Passengers: " +
                          ticket!.passengers!.length.toString() +
                          "/" +
                          ticket!.seats.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                      )),
                  Text(
                      "Estmated Price: " +
                          (ticket!.price! / ticket!.passengers!.length)
                              .toString() +
                          " SAR",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                      )),
                ],
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
                ticketDriver!.car.car_color +
                    " " +
                    ticketDriver!.car.car_model +
                    " " +
                    ticketDriver!.car.car_number,
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
                ticketDriver!.name,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        //call driver

                        launch("tel://" + ticketDriver!.phone);
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.purple,
                      ),
                      icon: const Icon(
                        Icons.phone_android,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: const Text(
                        "Call Driver",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Cancel Ticket Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        //cancel ticket
                        resignFromTicket();
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.purple,
                      ),
                      icon: const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 22,
                      ),
                      label: const Text(
                        "Cancel Ticket",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    notifyListeners();
  }

  showUICancelledTicket() {
    ticketInfoWidget = Container();
    searchLocationContainerHeight = 220;
    notifyListeners();
  }

  showWaitingResponseFromDriverUI() {
    searchLocationContainerHeight = 0;
    ticketInfoWidget = Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 260,
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
    );
    notifyListeners();
  }

  showUIForStartedTrip() {
    searchLocationContainerHeight = 0;
    ticketInfoWidget = Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 260,
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
                  (timeToArrive! + " to Arrive"),
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
                ticketDriver!.car.car_color +
                    " " +
                    ticketDriver!.car.car_model +
                    " " +
                    ticketDriver!.car.car_number,
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
                ticketDriver!.name,
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
              Text(
                "To: " + userDropOffLocation!.locationName!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    notifyListeners();
  }

  showUIForArrivedTrip() {
    showDialog(
        context: navigatorKey.currentContext!,
        builder: (c) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Colors.purpleAccent,
            child: Container(
              margin: const EdgeInsets.all(6),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  Text(
                    "Trip Fare Amount (  ${ticket!.price} SAR / ${ticket!.passengers!.length} )",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Divider(
                    thickness: 4,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    (ticket!.price! / ticket!.passengers!.length)
                            .toStringAsFixed(1) +
                        "SAR",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                      fontSize: 50,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "This is the total trip amount, Please Pay it to driver.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        primary: Colors.purpleAccent,
                      ),
                      onPressed: () {
                        Future.delayed(const Duration(milliseconds: 2000), () {
                          SystemNavigator.pop();
                        });
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Pay in Cash",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                ],
              ),
            ),
          );
        });

    searchLocationContainerHeight = 220;
    ticketInfoWidget = Container();
    notifyListeners();
  }

  saveRideRequestInformation() async {
    //save the RideRequest information
    // 1

    //save the RideRequest information

    referenceRideRequest =
        FirebaseDatabase.instance.ref().child("All Ride Requests").push();
    var originLocation = userPickUpLocation;
    var destinationLocation = userDropOffLocation;

    Map originLocationMap = {
      //"key": value
      "latitude": originLocation!.locationLatitude.toString(),
      "longitude": originLocation!.locationLongitude.toString(),
    };

    Map destinationLocationMap = {
      //"key": value
      "latitude": destinationLocation!.locationLatitude.toString(),
      "longitude": destinationLocation!.locationLongitude.toString(),
    };

    Map userInformationMap = {
      "origin": originLocationMap,
      "destination": destinationLocationMap,
      "time": DateTime.now().toString(),
      "userName": userModelCurrentInfo!.name,
      "userPhone": userModelCurrentInfo!.phone,
      "originAddress": originLocation.locationName,
      "destinationAddress": destinationLocation.locationName,
      "driverId": "waiting",
    };

    await referenceRideRequest!.set(userInformationMap);
  }

  updateArrivalTimeToUserPickupLocation(driverCurrentPositionLatLng) async {
    var isPickedUp = false;

    log("updateArrivalTimeToUserPickupLocation" +
        driverCurrentPositionLatLng.toString());

    LatLng userPickUpPosition =
        LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);

    if (isPickedUp) {
      driverCurrentPositionLatLng = LatLng(
          userDropOffLocation!.locationLatitude!,
          userDropOffLocation!.locationLongitude!);
    } else {
      driverCurrentPositionLatLng = LatLng(
        ticket!.driverLocation!.latitude,
        ticket!.driverLocation!.longitude,
      );
    }
    log("Driver current position:  " + driverCurrentPositionLatLng.toString());
    driverRideStatus = isPickedUp ? "Arrive in ::" : "Driver is Coming ::";
    var directionDetailsInfo =
        await AssistantMethods.obtainOriginToDestinationDirectionDetails(
      driverCurrentPositionLatLng,
      userPickUpPosition,
    );

    driverRideStatus =
        " Driver is Coming:: ${directionDetailsInfo!.duration_text}";

    if (requestPositionInfo == true) {
      requestPositionInfo = false;

      LatLng userPickUpPosition =
          LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);

      var directionDetailsInfo =
          await AssistantMethods.obtainOriginToDestinationDirectionDetails(
        driverCurrentPositionLatLng,
        userPickUpPosition,
      );

      if (directionDetailsInfo == null) {
        return;
      }

      if (ticket != null) {
        var passenger = ticket!.passengers!
            .where((element) => element.id == userModelCurrentInfo!.id)
            .first;
        if (passenger.isPickedUp == false) {
          showUIForAssignedDriverInfo();
        }
      }

      log("driverRideStatus: $driverRideStatus");

      requestPositionInfo = true;

      notifyListeners();
    }
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

    // searchNearestOnlineDrivers();
  }

  sendNotificationToDriverNow(String chosenDriverId) {
    //assign/SET rideRequestId to newRideStatus in
    // Drivers Parent node for that specific choosen driver
    FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(chosenDriverId!)
        .child("newRideStatus")
        .set(referenceRideRequest!.key);

    //automate the push notification system
    FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(chosenDriverId)
        .child("token")
        .once()
        .then((snap) {
      if (snap.snapshot.value != null) {
        String deviceRegistrationToken = snap.snapshot.value.toString();

        //send Notification Now
        AssistantMethods.sendNotificationToDriverNow(
          deviceRegistrationToken,
          referenceRideRequest!.key.toString(),
          ticket!.id!,
          navigatorKey.currentContext,
        );

        Fluttertoast.showToast(msg: "Requesting sent Successfully.");
      } else {
        Fluttertoast.showToast(msg: "Please choose another driver.");
        return;
      }
    });
  }

  retrieveOnlineDriversInformation(List onlineNearestDriversList) async {
    dList.clear();
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("drivers");
    for (int i = 0; i < onlineNearestDriversList.length; i++) {
      await ref
          .child(onlineNearestDriversList[i].driverId.toString())
          .get()
          .then((dataSnapShot) {
        final data = (dataSnapShot.value as Map).cast<String, dynamic>();
        log("DriverKey Information" + data.toString());

        var driver = Driver(
            name: data['name'].toString(),
            email: data['email'].toString(),
            phone: data['phone'].toString(),
            id: data['id'].toString(),
            token: data['token'].toString(),
            newRideStatus: data['newRideStatus'].toString(),
            car: Car(
              car_color: data['car_details']['car_color'].toString(),
              car_model: data['car_details']['car_model'].toString(),
              car_number: data['car_details']['car_number'].toString(),
              type: data['car_details']['type'].toString(),
            ));
        dList.add(driver);

        log("car Seats  " + driver.car.seats.toString());
        // print("DriverKey Information"+ dList.toString());
      });
    }
    notifyListeners();
  }

  createActiveNearbyDriverIconMarker() {
    if (activeNearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(
          navigatorKey.currentContext!,
          size: Size(4, 4));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "images/car.jpg")
          .then((value) {
        activeNearbyIcon = value;
      });
    }
    notifyListeners();
  }

  updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng) async {
    if (requestPositionInfo == true) {
      requestPositionInfo = false;

      var dropOffLocation = userDropOffLocation;

      LatLng userDestinationPosition = LatLng(
          dropOffLocation!.locationLatitude!,
          dropOffLocation!.locationLongitude!);

      var directionDetailsInfo =
          await AssistantMethods.obtainOriginToDestinationDirectionDetails(
        driverCurrentPositionLatLng,
        userDestinationPosition,
      );

      if (directionDetailsInfo == null) {
        return;
      }

      driverRideStatus = "Going towards Destination :: " +
          directionDetailsInfo.duration_text.toString();

      requestPositionInfo = true;
      notifyListeners();
    }
  }

  Future<Driver> getDriverData(String id) async {
    Driver driver = Driver(
        name: "",
        email: "",
        phone: "",
        id: "",
        token: "",
        newRideStatus: "",
        car: Car(
          car_color: "",
          car_model: "",
          car_number: "",
          type: "",
        ));
    await FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(id)
        .once()
        .then((dataSnapShot) {
      driver = Driver(
          name: (dataSnapShot.snapshot.value as Map)['name'].toString(),
          email: (dataSnapShot.snapshot.value as Map)['email'].toString(),
          phone: (dataSnapShot.snapshot.value as Map)['phone'].toString(),
          id: (dataSnapShot.snapshot.value as Map)['id'].toString(),
          token: (dataSnapShot.snapshot.value as Map)['token'].toString(),
          newRideStatus:
              (dataSnapShot.snapshot.value as Map)['newRideStatus'].toString(),
          car: Car(
            car_color: (dataSnapShot.snapshot.value as Map)['car_details']
                    ['car_color']
                .toString(),
            car_model: (dataSnapShot.snapshot.value as Map)['car_details']
                    ['car_model']
                .toString(),
            car_number: (dataSnapShot.snapshot.value as Map)['car_details']
                    ['car_number']
                .toString(),
            type: (dataSnapShot.snapshot.value as Map)['car_details']['type']
                .toString(),
          ));
    });
    return driver;
  }
  // Ticket Stuff

  ticketMainProcess() async {
    // check if there is available ticket

    var isAvailable = await checkAvailableTickets(
        GeoPoint(userDropOffLocation!.locationLatitude!,
            userDropOffLocation!.locationLongitude!),
        GeoPoint(userPickUpLocation!.locationLatitude!,
            userPickUpLocation!.locationLongitude!));

    // create a new ticket if there is no available tickets
    //
    // join the first ticket if there is available tickets
    //
    // open stream to listen to the ticket status
    //
    // if the ticket status is accepted then show the driver info
    //
    // if the ticket status is cancelled then show the user that the ticket is cancelled

    if (isAvailable == false) {
      await createNewTicket();
    } else {
      await joinExistTicket();
    }
  }

  joinExistTicket() async {
    // get the first ticket
    try {
      // add the user to the ticket
      onlineNearbyAvailableDriversList =
          GeoFireAssistant.activeNearbyAvailableDriversList;
      await retrieveOnlineDriversInformation(onlineNearbyAvailableDriversList);

      if (tickets.first.seats == tickets.first.passengers!.length) {
        Fluttertoast.showToast(
            msg: "No seats available for this trip .. Generating new ticket",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.purple,
            textColor: Colors.white,
            fontSize: 16.0);
        return;
      }

      if (tickets.first.seats! - 1 == tickets.first.passengers!.length) {
        await FirebaseFirestore.instance
            .collection('Tickets')
            .doc(tickets.first.id)
            .update({'acceptNewPassenger': false});
      }
      await FirebaseFirestore.instance
          .collection('Tickets')
          .doc(tickets.first.id)
          .update({
        'passengers': FieldValue.arrayUnion([
          Passenger(
                  name: userModelCurrentInfo!.name!,
                  phone: userModelCurrentInfo!.phone!,
                  id: userModelCurrentInfo!.id!,
                  origin: GeoPoint(userPickUpLocation!.locationLatitude!,
                      userPickUpLocation!.locationLongitude!),
                  isPickedUp: false)
              .toMap()
        ])
      }).then((value) async {
        ticket = tickets.first;
        ticketDriver = await getDriverData(ticket!.driverId!);

        // assign driver

        // log("ticket Data" + ticket!.toMap().toString());

        // ticketDriver =
        //     dList.where((element) => element.id == ticket!.driverId).first;

        Fluttertoast.showToast(
            msg: "You have joined the ticket successfully",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.purple,
            textColor: Colors.white,
            fontSize: 16.0);

        subscribeToTicket(ticket!);
        notifyListeners();
      });
    } on Exception catch (e) {
      log(e.toString());
      // TODO
    }
  }

  resignFromTicket() {
    FirebaseFirestore.instance.collection('Tickets').doc(ticket!.id).update({
      'passengers': FieldValue.arrayRemove([
        Passenger(
                name: userModelCurrentInfo!.name!,
                phone: userModelCurrentInfo!.phone!,
                id: userModelCurrentInfo!.id!,
                origin: GeoPoint(userPickUpLocation!.locationLatitude!,
                    userPickUpLocation!.locationLongitude!),
                isPickedUp: false)
            .toMap()
      ])
    }).then((value) {
      _ticketSnapshot!.cancel();
      ticket = null;
      ticketDriver = null;
      polyLineSet.clear();
      markersSet.clear();
      circlesSet.clear();
      pLineCoOrdinatesList.clear();

      showUICancelledTicket();
      Fluttertoast.showToast(
          msg: "You have resigned from the ticket successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.purple,
          textColor: Colors.white,
          fontSize: 16.0);
    });
  }

  createNewTicket() async {
    try {
      ticket = Ticket(
          time: Timestamp.now(),
          destination: GeoPoint(userDropOffLocation!.locationLatitude!,
              userDropOffLocation!.locationLongitude!),
          passengers: [
            Passenger(
                name: userModelCurrentInfo!.name!,
                phone: userModelCurrentInfo!.phone!,
                id: userModelCurrentInfo!.id!,
                origin: GeoPoint(userPickUpLocation!.locationLatitude!,
                    userPickUpLocation!.locationLongitude!),
                isPickedUp: false)
          ],
          status: "Pending",
          id: "id",
          origin: GeoPoint(userPickUpLocation!.locationLatitude!,
              userPickUpLocation!.locationLongitude!),
          acceptNewPassenger: false,
          humanReadableDestination: userDropOffLocation!.locationName!,
          seats: 0,
          timer: 15);

      await FirebaseFirestore.instance
          .collection('Tickets')
          .add(ticket!.toMap())
          .then((value) {
        ticket!.id = value.id;
        Fluttertoast.showToast(
            msg: "You have created a new ticket successfully",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.purple,
            textColor: Colors.white,
            fontSize: 16.0);
        onlineNearbyAvailableDriversList =
            GeoFireAssistant.activeNearbyAvailableDriversList;
        searchNearestOnlineDrivers();
        subscribeToTicket(ticket!);
      });
    } on Exception catch (e) {
      // TODO
      log(e.toString());
    }
  }

  sendDriverRequestAndWaitingResponse() {
    // saveRideRequestInformation();
    // showWaitingResponseFromDriverUI();

    try {
      tripRideRequestInfoStreamSubscription =
          referenceRideRequest!.onValue.listen((eventSnap) {
        log("eventSnap: ${eventSnap.snapshot.value}");
        if (eventSnap.snapshot.value == null) {
          return;
        }

        if ((eventSnap.snapshot.value as Map)["car_details"] != null) {
          driverCarDetails =
              (eventSnap.snapshot.value as Map)["car_details"].toString();
        }

        if ((eventSnap.snapshot.value as Map)["driverPhone"] != null) {
          driverPhone =
              (eventSnap.snapshot.value as Map)["driverPhone"].toString();
        }

        if ((eventSnap.snapshot.value as Map)["driverName"] != null) {
          driverName =
              (eventSnap.snapshot.value as Map)["driverName"].toString();
        }

        if ((eventSnap.snapshot.value as Map)["status"] != null) {
          userRideRequestStatus =
              (eventSnap.snapshot.value as Map)["status"].toString();
        }

        if ((eventSnap.snapshot.value as Map)["driverLocation"] != null) {
          double driverCurrentPositionLat = double.parse(
              (eventSnap.snapshot.value as Map)["driverLocation"]["latitude"]
                  .toString());
          double driverCurrentPositionLng = double.parse(
              (eventSnap.snapshot.value as Map)["driverLocation"]["longitude"]
                  .toString());

          LatLng driverCurrentPositionLatLng =
              LatLng(driverCurrentPositionLat, driverCurrentPositionLng);

          //status = accepted
          if (userRideRequestStatus == "accepted") {
            log("userRideRequestStatus: $userRideRequestStatus + accepted");

            ticketDriver = dList.firstWhere((element) =>
                element.id ==
                (eventSnap.snapshot.value as Map)["driverId"].toString());

            // estmate price calculation

            FirebaseFirestore.instance
                .collection('Tickets')
                .doc(ticket!.id)
                .update({
              "driverId": ticketDriver!.id,
              "status": "collecting",
              "seats": ticketDriver!.car.seats,
              "acceptNewPassenger": true,
              'price': price
            }).then((value) {
              log("2: " + driverCurrentPositionLatLng.toString());

              updateArrivalTimeToUserPickupLocation(
                  driverCurrentPositionLatLng);
              showUIForAssignedDriverInfo();

              notifyListeners();
            });
          }

          //status = arrived
          if (userRideRequestStatus == "arrived") {
            log("userRideRequestStatus: $userRideRequestStatus + arrived");
            driverRideStatus = "Driver has Arrived";
          }

          ////status = ontrip
          if (userRideRequestStatus == "ontrip") {
            log("userRideRequestStatus: $userRideRequestStatus + ontrip");
            updateReachingTimeToUserDropOffLocation(
                driverCurrentPositionLatLng);
          }
          notifyListeners();
        }
      });
    } catch (e) {
      log(e.toString());
    }
  }

  Future<bool> checkAvailableTickets(
      GeoPoint userDestination, GeoPoint userOrigin) async {
    // compare the destenation of the user with the destenation of the tickets
    var isThereTicket = false;

    try {
      log("userDestination: ${userDestination.latitude} , ${userDestination.longitude}");
      log("userOrigin: ${userOrigin.latitude} , ${userOrigin.longitude}");

      await FirebaseFirestore.instance
          .collection('Tickets')
          .get()
          .then((event) async {
        log("event.docs.length: ${event.docs.length}");

        if (event.docs.isNotEmpty) {
          event.docs.forEach((element) async {
            // delete all tickets that are older than 15 mins
            if (DateTime.now()
                        .difference(
                            (element.data()['time'] as Timestamp).toDate())
                        .inMinutes >
                    15 &&
                element.data()['status'] == "Pending") {
              await FirebaseFirestore.instance
                  .collection('Tickets')
                  .doc(element.id)
                  .delete();
              return;
            }

            var data = element.data();
            if ((data['destination'] as GeoPoint).latitude.toStringAsFixed(4) ==
                    userDestination.latitude.toStringAsFixed(4) &&
                (data['destination'] as GeoPoint)
                        .longitude
                        .toStringAsFixed(4) ==
                    userDestination.longitude.toStringAsFixed(4) &&
                Geolocator.distanceBetween(
                            (data['origin'] as GeoPoint).latitude,
                            (data['origin'] as GeoPoint).longitude,
                            userOrigin.latitude,
                            userOrigin.longitude) /
                        1000 <
                    1 &&
                data['acceptNewPassenger'] == true)
              tickets.add(Ticket.fromMap(element.data(), element.id));
            log("tickets: ${tickets.length}");
          });
        }
        if (tickets.isEmpty) {
          isThereTicket = false;
          Fluttertoast.showToast(
              msg:
                  "No tickets available for this trip .. Generating new ticket",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.purple,
              textColor: Colors.white,
              fontSize: 16.0);
        } else {
          isThereTicket = true;
        }

        notifyListeners();
      });

      return Future.value(isThereTicket);
    } catch (e) {
      print(e.toString());
    }
    return Future.value(isThereTicket);
  }

  showOtherPassengersOnMap() {
    markersSet.clear();
    for (var passenger in ticket!.passengers!) {
      if (passenger.id != userModelCurrentInfo!.id) {
        Marker passengerMarker = Marker(
          markerId: MarkerId(passenger.id),
          position:
              LatLng(passenger.origin.latitude, passenger.origin.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: passenger.name,
            snippet: "Passenger",
          ),
        );
        markersSet.add(passengerMarker);
      }
    }
    notifyListeners();
  }

  subscribeToTicket(Ticket tick) {
    try {
      _ticketSnapshot = FirebaseFirestore.instance
          .collection('Tickets')
          .doc(tick.id)
          .snapshots()
          .listen((event) async {
        log("event: ${event.data()}");
        if (event.data() != null) {
          var data = event.data()!;
          ticket = Ticket.fromMap(data, event.id);
          log("ticket: ${ticket!.toMap()}");

          if (ticket!.status == "Pending") {
            log("ticket!.status: ${ticket!.status}");
            showWaitingResponseFromDriverUI();
          } else if (ticket!.status == 'collecting') {
            log("ticket!.status: ${ticket!.status}");
            updateArrivalTimeToUserPickupLocation(LatLng(
                ticket!.driverLocation!.latitude,
                ticket!.driverLocation!.longitude));

            if (ticket!.passengers!
                    .where((element) => element.id == userModelCurrentInfo!.id)
                    .first
                    .isPickedUp ==
                true) {
              log("in Collecting and isPickedUp is true");
              updateReachingTimeToUserDropOffLocation(LatLng(
                  ticket!.driverLocation!.latitude,
                  ticket!.driverLocation!.longitude));
              showUIForStartedTrip();
            } else {
              log("in Collecting and isPickedUp is false");
              showOtherPassengersOnMap();
              showUIForAssignedDriverInfo();
            }

            if (ticket!.timer == 5 && ticket!.passengers!.length == 1) {
              Fluttertoast.showToast(
                  msg:
                      "Note that you have to Pay 50% of the ticket price, if no one joined the ticket",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.purple,
                  textColor: Colors.white,
                  fontSize: 16.0);
            }
          } else if (ticket!.status == 'started') {
            log("ticket!.status: ${ticket!.status}");
            updateReachingTimeToUserDropOffLocation(LatLng(
                ticket!.driverLocation!.latitude,
                ticket!.driverLocation!.longitude));
            showUIForStartedTrip();
          } else if (ticket!.status == "Cancelled") {
            showUICancelledTicket();
            Fluttertoast.showToast(
                msg: "The ticket is cancelled",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.purple,
                textColor: Colors.white,
                fontSize: 16.0);
          } else if (ticket!.status == "arrived") {
            showUIForArrivedTrip();

            polyLineSet.clear();
            markersSet.clear();
            circlesSet.clear();
            pLineCoOrdinatesList.clear();
            Fluttertoast.showToast(
                msg: "You have arrived to your destination",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.purple,
                textColor: Colors.white,
                fontSize: 16.0);
            ticket = null;
            ticketDriver = null;
          }
          notifyListeners();
        }
      });
    } on Exception catch (e) {
      log(e.toString());

      ticketInfoWidget = Positioned(
        child: Container(
          child: Text("No Ticket Found .. something went wrong /n $e "),
        ),
      );
      notifyListeners();
      // TODO
    }
  }

  updateOverAllTripsCounter(int overAllTripsCounter) {
    countTotalTrips = overAllTripsCounter;
    notifyListeners();
  }

  updateOverAllTripsKeys(List<String> tripsKeysList) {
    historyTripsKeysList = tripsKeysList;
    notifyListeners();
  }

  updateOverAllTripsHistoryInformation(TripsHistoryModel eachTripHistory) {
    allTripsHistoryInformationList.add(eachTripHistory);
    notifyListeners();
  }
}

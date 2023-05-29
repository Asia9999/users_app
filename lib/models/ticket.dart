import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  Timestamp? time;
  GeoPoint? destination;
  GeoPoint? origin;
  List<Passenger>? passengers;
  String? status;
  String? id;
  int? seats;
  bool? acceptNewPassenger;
  String? humanReadableDestination;

  Ticket({
    required this.time,
    required this.destination,
    required this.passengers,
    required this.status,
    required this.id,
    required this.origin,
    required this.seats,
    required this.acceptNewPassenger,
    required this.humanReadableDestination,
  });

  Ticket.fromMap(Map<String, dynamic> data, String documentId) {
    time = data['time'];
    destination = data['destination'];
    if (data['passengers'] != null) {
      passengers = [];
      data['passengers'].forEach((element) {
        passengers!.add(Passenger.fromMap(element));
      });
    }
    status = data['status'];
    id = documentId;
    origin = data['origin'];
    seats = data['seats'];
    acceptNewPassenger = data['acceptNewPassenger'];
    humanReadableDestination = data['humanReadableDestination'];
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'destination': destination,
      'passengers': passengers!.map((element) => element.toMap()).toList(),
      'status': status,
      'id': id,
      'origin': origin,
      'seats': seats,
      'acceptNewPassenger': acceptNewPassenger,
      'humanReadableDestination': humanReadableDestination,
    };
  }
}

class Passenger {
  String name;
  String phone;
  String id;
  GeoPoint origin;
  bool isPickedUp = false;

  Passenger(
      {required this.name,
      required this.phone,
      required this.id,
      required this.origin,
      this.isPickedUp = false});

  factory Passenger.fromMap(Map<String, dynamic> data) {
    return Passenger(
      name: data['name'],
      phone: data['phone'],
      id: data['id'],
      origin: data['origin'],
      isPickedUp: data['isPickedUp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'id': id,
      'origin': origin,
      'isPickedUp': isPickedUp,
    };
  }
}

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Driver {
  String name;
  String email;
  String phone;
  String id;
  String token;
  String newRideStatus;
  Car car;

  Driver({
    required this.name,
    required this.email,
    required this.phone,
    required this.id,
    required this.token,
    required this.newRideStatus,
    required this.car,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      id: json['id'],
      token: json['token'],
      newRideStatus: json['newRideStatus'],
      car: Car.fromJson(json['car_details']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'id': id,
        'token': token,
        'newRideStatus': newRideStatus,
      };
}

class Car {
  String car_model;
  String car_color;
  String car_number;
  String type;
  int? seats;

  Car(
      {required this.car_model,
      required this.car_color,
      required this.car_number,
      required this.type,
      this.seats}) {
    switch (type) {
      case 'car-3seats':
        seats = 3;
        break;
      case 'car-6seats':
        seats = 6;
        break;
      case 'car-9seats':
        seats = 9;
        break;
      default:
        seats = 3;
    }
  }

  factory Car.fromJson(Map<String, dynamic> json) {
    int _seats = 0;
    switch (json['type']) {
      case 'car-3seats':
        _seats = 3;
        break;
      case 'car-6seats':
        _seats = 6;
        break;
      case 'car-9seats':
        _seats = 9;
        break;
      default:
        _seats = 3;
    }

    return Car(
      car_model: json['car_model'],
      car_color: json['car_color'],
      car_number: json['car_number'],
      type: json['type'],
      seats: _seats,
    );
  }

  Map<String, dynamic> toJson() => {
        'car_model': car_model,
        'car_color': car_color,
        'car_number': car_number,
        'type': type,
        'seats': seats,
      };
}

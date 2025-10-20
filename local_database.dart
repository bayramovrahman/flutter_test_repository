// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/functions/permission.dart';
import 'package:shaylan_agent/models/customer.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/database/config.dart';

Future<void> saveOrUpdateVisitOrders(
    int visitId, List<OrderForServer> orders) async {
  if (db.isOpen) {
    String ordersJson =
        jsonEncode(orders.map((order) => order.toMap()).toList());
    List<Map<String, dynamic>> resultDB = await db.rawQuery(
      '''SELECT * FROM orders_in_visits WHERE visit_id = "$visitId"''',
    );

    if (resultDB.isNotEmpty) {
      await db.update(
        'orders_in_visits',
        {
          'body': ordersJson,
          'status': 'dont send',
        },
        where: 'visit_id = ?',
        whereArgs: [visitId],
      );
    } else {
      await db.insert(
        'orders_in_visits',
        {
          'visit_id': visitId,
          'body': ordersJson,
          'status': 'dont send',
        },
      );
    }
  }
}

// sort Customers from near to far (Begli)
Future<List<Customer>> sortCustomersFromNearToFar(String filterVal, String status, {String? district}) async {
  bool locationPermitted = await hasLocationPermission();

  // Get customers from database with getListCustomers (Begli)
  final customers = await getListCustomers(filterVal, status, district: district);

  if (locationPermitted) {
    Position currentPosition = await Geolocator.getCurrentPosition();

    // Start sorting with sort (Begli)
    customers.sort((a, b) {
      double? latA = double.tryParse(a.uLat?.trim() ?? '');
      double? lngA = double.tryParse(a.uLng?.trim() ?? '');
      double? latB = double.tryParse(b.uLat?.trim() ?? '');
      double? lngB = double.tryParse(b.uLng?.trim() ?? '');

      // Handle null positions by assigning a very large distance (Begli)
      if (latA == null || lngA == null) {
        return 1;
      }
      if (latB == null || lngB == null) {
        return -1;
      }

      // Calculate distances for valid positions (Begli)
      double distanceA = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        latA,
        lngA,
      );

      double distanceB = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        latB,
        lngB,
      );

      return distanceA.compareTo(distanceB);
    });
  }
  // if has no permission return unsorted customers (Begli)
  return customers;
}

// get VisitOrders from database (Begli)

Future<List<OrderForServer>> getOrdersFromDB(int visitId) async {
  List<Map<String, dynamic>> resultDB = await db.rawQuery(
    '''SELECT body FROM orders_in_visits WHERE visit_id = "$visitId"''',
  );
  if (resultDB.isNotEmpty) {
    List<OrderForServer> orders = [];
    List<dynamic> jsonData = jsonDecode(resultDB.toString());
    List<dynamic> ordersJson = jsonData.first['body'];
    orders = ordersJson
        .map((orderJson) => OrderForServer.fromJson(orderJson))
        .toList();

    return orders;
  }
  return [];
}

Future<List<OrderForServer>> getVisitOrdersFromDB(int visitId) async {
  List<Map<String, dynamic>> resultDB = await db.rawQuery(
    '''SELECT body FROM orders_in_visits WHERE visit_id = "$visitId"''',
  );

  if (resultDB.isNotEmpty) {
    List<OrderForServer> orders = [];

    for (var row in resultDB) {
      try {
        Map<String, dynamic> map = {
          for (var item in jsonDecode(row['body'])) item[0] as String: item[1]
        };
        OrderForServer order = OrderForServer.fromJson(map);
        debugPrint('Parsed order: ${order.orderSellerName}');
        orders.add(order);
      } catch (e) {
        print('Error parsing JSON: $e');
        // Skip adding a null value for failed parsing
      }
    }

    return orders;
  } else {
    return [];
  }
}

Future<OrderForServer?> getOrder(int visitId) async {
  final result = await db.query(
    'orders_in_visits',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );

  if (result.isNotEmpty) {
    OrderForServer order = OrderForServer.defaultOrderForServer();
    final jsonString = result.first['body'] as String;

    final jsonMap = jsonDecode(jsonString); // Ensure valid JSON formatting
    order = OrderForServer.fromJsonDB(jsonMap);
    return order;
  }

  return null; // Return null if no record found
}

Future<String?> getOrderStatus(int visitId) async {
  final result = await db.query(
    'orders_in_visits',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );

  if (result.isNotEmpty) {
    // OrderForServer order = OrderForServer.defaultOrderForServer();
    final jsonString = result.first['status'] as String;
    debugPrint(jsonString);
    // final jsonMap = jsonDecode(jsonString); // Ensure valid JSON formatting
    // order = OrderForServer.fromJsonDB(jsonMap);
    return jsonString;
  }

  return null; // Return null if no record found
}

Future<NewCustomer?> getUpdatedCustomer(int visitId) async {
  final result = await db.query(
    'updated_customer',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );

  if (result.isNotEmpty) {
    final jsonString = result.first['updated_customer_body'] as String;

    final jsonMap = jsonDecode(jsonString); // Ensure valid JSON formatting
    NewCustomer newCustomer = NewCustomer.fromMap(jsonMap);
    return newCustomer;
  }

  return null; // Return null if no record found
}

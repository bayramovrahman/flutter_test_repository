import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shaylan_agent/database/config.dart';
import 'package:shaylan_agent/functions/file_upload.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/return_item_body.dart';
import 'package:shaylan_agent/models/static_data.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:sqflite/sqflite.dart';

Future<int> createVisit(VisitModel visit) async {
  if (db.isOpen) {
    await db.insert(
      'visits',
      visit.toJsonForDB(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT id FROM visits ORDER BY id DESC LIMIT 1');
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }
  return 0;
}

Future<int> createVisitForSynh(VisitModel visit) async {
  if (db.isOpen) {
    await db.insert(
      'visits',
      visit.toJsonForSynh(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT id FROM visits ORDER BY id DESC LIMIT 1');
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return 0;
  }
  return 0;
}

Future<int> updateVisitHasInventor(int hasInventor) async {
  if (db.isOpen) {
    await db.rawUpdate(
      'UPDATE visits SET hasInventor = $hasInventor WHERE id = (SELECT id FROM visits ORDER BY id DESC LIMIT 1)',
    );

    final List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT id FROM visits ORDER BY id DESC LIMIT 1');

    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
  }
  return 0;
}

Future<void> updateVisitHasInventorContract(int hasInventorContract) async {
  if (db.isOpen) {
    await db.rawUpdate(
        'UPDATE visits SET hasInventorContract=$hasInventorContract WHERE id=(SELECT id FROM visits ORDER BY id DESC)');
  }
}

Future<String> getCardCodeByVisitID(int visitID) async {
  if (db.isOpen) {
    final List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT cardCode FROM visits WHERE id = $visitID');

    if (result.isNotEmpty) {
      return result.first['cardCode'] as String;
    }
    return '';
  }
  return '';
}

Future<void> saveReturnItemBody(
    int visitId, ReturnItemBody item, String? status) async {
  final jsonString = jsonEncode(item.toJson());

  // await deleteNotSentReturnItemBody();

  await db.insert(
    'return_item_body_table',
    {
      'visit_id': visitId,
      'return_item_body': jsonString,
      'status': status ??
          (item.returnHistories.isNotEmpty
              ? item.returnHistories.first.status
              : null),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> saveOrder(
    int visitId, OrderForServer order, String? status) async {
  final jsonString = jsonEncode(order.toJson());

  // debugPrint(ordertoJson.toString());

  debugPrint(jsonString);

  // Check if visit_id already exists
  final existingOrders = await db.query(
    'orders_in_visits',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );

  if (existingOrders.isNotEmpty) {
    // If it exists, update the existing record
    await db.update(
      'orders_in_visits',
      {
        'visit_id': visitId,
        'body': jsonString,
        'status': status ?? order.status,
      },
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
  } else {
    // If it doesn't exist, insert a new record
    await db.insert(
      'orders_in_visits',
      {
        'visit_id': visitId,
        'body': jsonString,
        'status': status ?? order.status,
      },
    );
  }
}

Future<void> removeOrder(int visitId) async {
  await db.delete(
    'orders_in_visits',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );
  debugPrint('Order for visitId \$visitId has been removed');
}

Future<void> saveVerifiedCustomer(int visitId, NewCustomer newCustomer) async {
  final jsonString = jsonEncode(newCustomer.toMap());

  debugPrint(jsonString);

  await db.insert(
    'updated_customer',
    {
      'visit_id': visitId,
      'updated_customer_body': jsonString,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> deleteSentOrderForServer() async {
  await db.delete(
    'orders_in_visits',
    where: "status != ?",
    whereArgs: ['dont send'],
  );
}

Future<List<OrderForServer>> fetchOrdersForServer() async {
  try {
    // Query the database to fetch all rows in descending order
    final List<Map<String, dynamic>> queryResult = await db.query(
      'orders_in_visits',
      columns: ['body', 'status'], // Fetch both 'body' and 'status' columns
      orderBy: 'visit_id DESC',
    );

    // Convert the JSON strings into OrderForServer objects
    List<OrderForServer> orders = queryResult.expand((row) {
      String ordersJson = row['body'] as String;

      // Parse the JSON string into a Map or List
      final parsedJson = jsonDecode(ordersJson);

      List<OrderForServer> parsedOrders = [];

      if (parsedJson is List) {
        parsedOrders = parsedJson
            .map((json) =>
                OrderForServer.fromJsonDB(json as Map<String, dynamic>))
            .toList();
      } else if (parsedJson is Map) {
        parsedOrders = [
          OrderForServer.fromJsonDB(parsedJson as Map<String, dynamic>)
        ];
      } else {
        throw Exception('Unexpected JSON format');
      }

      // Check if the status in the database is "dont send"
      if (row['status'] == 'dont send') {
        // Update the status of each order to "dont send" before returning
        parsedOrders = parsedOrders.map((order) {
          return order.copyWith(status: 'dont send');
        }).toList();
      }

      return parsedOrders;
    }).toList();

    return orders;
  } catch (e) {
    debugPrint('Error fetching and parsing orderForServer: $e');
    return []; // Return an empty list in case of an error
  }
}

Future<ReturnItemBody?> getReturnItemBody(int visitId) async {
  final result = await db.query(
    'return_item_body_table',
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );

  if (result.isNotEmpty) {
    final jsonString = result.first['return_item_body'] as String;

    final jsonMap = jsonDecode(jsonString); // Ensure valid JSON formatting
    return ReturnItemBody.fromJson(jsonMap);
  }

  return null; // Return null if no record found
}

Future<void> setWithNoImagesTo(int visitID, String isImageSet) async {
  if (db.isOpen) {
    await db.rawUpdate(
      'UPDATE merchandising SET withNoImages = ? WHERE VisitId = ?',
      [isImageSet, visitID],
    );
  }
}

Future<String?> getWithNoImagesValue(int visitId) async {
  List<Map<String, dynamic>> result = await db.query(
    'merchandising',
    columns: ['withNoImages'],
    where: 'visitId = ?',
    whereArgs: [visitId],
  );

  if (result.isNotEmpty) {
    return result.first['withNoImages'] as String?; // Assumes String value
  }
  return null;
}

Future<List<Merchandising>> getMerchandisingWithNoImages() async {
  final List<Map<String, dynamic>> maps = await db.query(
    'merchandising',
    where: 'withNoImages = ?',
    whereArgs: ['true'],
  );

  return List<Merchandising>.from(maps.map((e) => Merchandising.fromMap(e)));
}

Future<Merchandising?> getMerchandising(int visitId, bool withImage) async {
  if (!withImage) {
    await setWithNoImagesTo(visitId, 'ok');
  }

  final result = await db.query(
    'merchandising',
    where: 'VisitId = ?',
    whereArgs: [visitId],
  );

  // Check if the result contains any rows.
  if (result.isNotEmpty) {
    // Create a mutable copy of the result row
    final Map<String, dynamic> row = Map<String, dynamic>.from(result.first);

    if (!withImage) {
      return Merchandising.fromMapWithNoImages(row);
    } else {
      return Merchandising.fromMap(row);
    }
  }

  // Return null if no records are found.
  return null;
}

Future<void> deleteSentReturnItemBody() async {
  await db.delete(
    'return_item_body_table',
    where: "status != ?",
    whereArgs: ['dont sent'],
  );
}

Future<void> setStatusToTable(
    int visitId, String tableName, String status) async {
  await db.update(
    tableName,
    {'status': status},
    where: 'visit_id = ?',
    whereArgs: [visitId],
  );
}

// Function to fetch and parse ReturnItemBody objects
Future<List<ReturnItemBody>> fetchReturnItemBodies() async {
  try {
    // Query the database to fetch all rows in descending order
    final List<Map<String, dynamic>> queryResult = await db.query(
      'return_item_body_table',
      columns: ['return_item_body'], // Fetch only the 'return_item_body' column
      orderBy:
          'visit_id DESC', // Replace 'id' with the column you want to order by
    );

    // Convert the JSON strings into ReturnItemBody objects
    List<ReturnItemBody> returnItemBodies = queryResult.map((row) {
      String returnItemBodyJson = row['return_item_body'] as String;

      // Parse the JSON string into a Map and then into a ReturnItemBody object
      return ReturnItemBody.fromJson(json.decode(returnItemBodyJson));
    }).toList();

    return returnItemBodies;
  } catch (e) {
    debugPrint('Error fetching and parsing ReturnItemBody: $e');
    return []; // Return an empty list in case of an error
  }
}

Future<void> setEndTimeToVisit(int visitID) async {
  if (db.isOpen) {
    await db.update(
      'visits',
      {'endTime': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [visitID],
    );
  }
}

Future<void> setCommentToVisit(int visitID, String str) async {
  if (db.isOpen) {
    await db.update(
      'visits',
      {'comment': str},
      where: 'id = ?',
      whereArgs: [visitID],
    );
  }
}

Future<VisitModel?> getVisitByID(int visitID) async {
  if (db.isOpen) {
    List<Map<String, dynamic>> result = await db.query(
      'visits',
      where: 'id = ?',
      whereArgs: [visitID],
    );
    if (result.isNotEmpty) {
      return VisitModel.fromJson(result.first);
    }
    return null;
  }
  return null;
}

Future<int> getDontSentVisitsCount() async {
  if (db.isOpen) {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM visits WHERE status = ?',
      ['dont sent'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  } else {
    if (kDebugMode) {
      print('Database connection is closed');
    }
    return 0;
  }
}

Future<String?> getOrderBody(int visitId) async {
  // Query to fetch the body for a specific visit_id
  final List<Map<String, dynamic>> maps = await db.query(
    'orders_in_visits',
    columns: ['body'], // Only select the body column
    where: 'visit_id = ?',
    whereArgs: [visitId],
    limit: 1, // Fetch only one result
  );

  // Return the first body's value or null if not found
  if (maps.isNotEmpty) {
    return maps.first['body'] as String?;
  }
  return null; // Return null if no matching record is found
}

Future<List<VisitModel>> getVisits() async {
  if (db.isOpen) {
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''SELECT * FROM visits WHERE endTime != "" ORDER BY startTime DESC;''',
    );

    if (result.isNotEmpty) {
      return result.map((json) => VisitModel.fromJson(json)).toList();
    }
    return [];
  }
  return [];
}

Future<List<VisitModel>> getAllVisits({
  DateTime? startTime,
  DateTime? endTime,
}) async {
 

  if (db.isOpen) {
    String query = 'SELECT * FROM visits';
    List<dynamic> whereArgs = [];

    if (startTime != null && endTime != null) {
      String startDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime);
      String endDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime);
      query += ' WHERE datetime(startTime) BETWEEN ? AND ?';
      // whereArgs.add(startTime.toIso8601String());
      // whereArgs.add(endTime.toIso8601String());
      whereArgs.add(startDate);
      whereArgs.add(endDate);
    }

    query += ' ORDER BY datetime(startTime) DESC;';

    final List<Map<String, dynamic>> result =
        await db.rawQuery(query, whereArgs);

    if (result.isNotEmpty) {
      return result.map((json) => VisitModel.fromJson(json)).toList();
    }
    return [];
  }
  return [];
}

Future<List<VisitModel>> getRecentVisits({
  DateTime? startTime,
  DateTime? endTime,
  int limit = 50,
}) async {
  if (db.isOpen) {
    String query = 'SELECT * FROM visits';
    List<dynamic> whereArgs = [];

    if (startTime != null && endTime != null) {
      String startDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime);
      String endDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime);
      query += ' WHERE datetime(startTime) BETWEEN ? AND ?';
      whereArgs.add(startDate);
      whereArgs.add(endDate);
    }

    query += ' ORDER BY datetime(startTime) DESC LIMIT ?';
    whereArgs.add(limit);

    final List<Map<String, dynamic>> result =
        await db.rawQuery(query, whereArgs);

    if (result.isNotEmpty) {
      return result.map((json) => VisitModel.fromJson(json)).toList();
    }
    return [];
  }
  return [];
}

Future<List<VisitModel>> getDontSentVisits() async {
  if (db.isOpen) {
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
        SELECT * FROM visits WHERE endTime != "" 
        AND status="${VisitPaymentStatus.dontSent}" ORDER BY id DESC;
      ''',
    );

    if (result.isNotEmpty) {
      return result.map((json) => VisitModel.fromJson(json)).toList();
    }
    return [];
  }
  return [];
}

Future<void> setStatusToVisit(int visitId, String status) async {
  if (db.isOpen) {
    await db.update(
      'visits',
      {'status': status},
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }
}

Future<void> deleteIncompleteVisits() async {
  if (db.isOpen) {
    final List<Map<String, dynamic>> resultVisits = await db.query(
      'visits',
      columns: ['id'],
      where: 'endTime = ""',
    );

    List<int> visitIDs =
        resultVisits.map((record) => record['id'] as int).toList();

    if (visitIDs.isNotEmpty) {
      for (var visitID in visitIDs) {
        // delete visit steps --------------------
        await db.delete(
          'visit_steps',
          where: 'visit_id = ?',
          whereArgs: [visitID],
        );

        await db.delete(
          'visit_steps',
          where: 'visit_id = ?',
          whereArgs: [visitID],
        );

        // delete visit inventor images --------------------
        List<Map<String, dynamic>> resultImages = await db.rawQuery(
          '''SELECT image_path FROM inventor_images WHERE visit_id = $visitID''',
        );
        if (resultImages.isNotEmpty) {
          for (var image in resultImages) {
            await deleteFile(image['image_path'] as String);
          }
        }
        await db.delete(
          'inventor_images',
          where: 'visit_id = ?',
          whereArgs: [visitID],
        );

        // delete visit payment and payment invoices --------------------
        List<Map<String, dynamic>> resultPayments = await db.rawQuery(
          '''SELECT id FROM visit_payments WHERE visitId = $visitID''',
        );
        if (resultPayments.isNotEmpty) {
          for (var payment in resultPayments) {
            await db.delete(
              'visit_payment_invoices',
              where: 'invPayId = ?',
              whereArgs: [payment['id'] as int],
            );
          }
        }
        await db.delete(
          'visit_payments',
          where: 'visitId = ?',
          whereArgs: [visitID],
        );
      }
    }

    // delete visits
    await db.delete('visits', where: 'endTime = ""');
  }
}

Future<void> deleteVisits(String status) async {
  if (db.isOpen) {
    final List<Map<String, dynamic>> resultVisits = await db.query(
      'visits',
      columns: ['id'],
      where: 'status != ? OR status IS NULL',
      whereArgs: [status],
    );

    List<int> visitIDs =
        resultVisits.map((record) => record['id'] as int).toList();

    for (var visitID in visitIDs) {
      await db.delete(
        'visit_steps',
        where: 'visit_id = ?',
        whereArgs: [visitID],
      );

      await db.delete(
        'inventor_images',
        where: 'visit_id = ?',
        whereArgs: [visitID],
      );
    }

    final List<Map<String, dynamic>> resultVisitPayments = await db.query(
      'visit_payments',
      columns: ['id'],
      where: 'status != ?',
      whereArgs: [status],
    );

    List<int> visitPaymentIDs =
        resultVisitPayments.map((record) => record['id'] as int).toList();

    for (var element in visitPaymentIDs) {
      await db.delete(
        'visit_payment_invoices',
        where: 'invPayId = ?',
        whereArgs: [element],
      );
    }

    await db.delete(
      'visit_payments',
      where: 'status != ?',
      whereArgs: [status],
    );

    await db.delete('visit_reviews');

    await db.delete(
      'visits',
      where: 'status != ?',
      whereArgs: [status],
    );
  }
}

// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shaylan_agent/database/functions/user.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/database/functions/visit_step.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/return_item_body.dart';
import 'package:shaylan_agent/models/user.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/models/visit_step.dart';
import 'package:shaylan_agent/services/local_database.dart';

Future<Map<String, dynamic>> prepareVisitForSend(
    VisitModel visit, bool sendWithPhoto) async {
  List<Merchandising> merchandisersInfoList = [];
  List<OrderForServer> orders = [];
  List<ReturnItemBody> returnList = [];
  bool hasOrder = false;
  bool hasReturn = false;
  bool hasMerchandising = false;
  bool hasVerification = false;

  List<VisitStepModel> steps = await getVisitStepsByVisitID(visit.id!);
  Merchandising? merchandising =
      await getMerchandising(visit.id!, sendWithPhoto);
  OrderForServer? order = await getOrder(visit.id!);
  ReturnItemBody? returnItemBody = await getReturnItemBody(visit.id!);
  NewCustomer? newCustomer = await getUpdatedCustomer(visit.id!);

  if (merchandising != null) {
    hasMerchandising = true;

debugPrint(merchandising.merchandiserImages!.first.encodedImage ?? 'yok' );

    if (sendWithPhoto) {
      for (int i = 0; i < merchandising.merchandiserImages!.length; i++) {
        MerchandiserImage mImage = merchandising.merchandiserImages![i];
        debugPrint(mImage.imagePath);

        File compressedPhoto = File(mImage.imagePath!);
        debugPrint(compressedPhoto.path);

        final bytes = await compressedPhoto.readAsBytes();
        final String base64String = base64Encode(bytes);

        // Create a new updated image
        MerchandiserImage updatedImage =
            mImage.copyWith(encodedImage: base64String);

        // Replace the old image with the updated one in the list
        merchandising.merchandiserImages![i] = updatedImage;
      }
    }

    for (MerchandiserImage mImage in merchandising.merchandiserImages!) {
      debugPrint(mImage.encodedImage ?? "");
    }

    merchandisersInfoList.add(merchandising);
    debugPrint('the merchandising data : \n${merchandising.toJson()}');
  }
  if (order != null) {
    hasOrder = true;
    orders.add(order);
  }
  if (returnItemBody != null) {
    hasReturn = true;
    returnList.add(returnItemBody);
  }
  if (newCustomer != null) {
    hasVerification = true;
  }

  User user = await getUser();

  VisitModel visitToSend = visit.copyWith(
      empID: user.empId,
      empName: user.firstName,
      empLastName: user.lastName,
      newCustomer: newCustomer,
      endTime: DateTime.now().add(const Duration(hours: 5)).toIso8601String(),
      visitType: 'visit_trader',
      orderList: orders,
      returnList: returnList,
      stepsList: steps,
      merchandisersInfoList: merchandisersInfoList);

  return {
    "visitBody": visitToSend,
    "hasMerchandising": hasMerchandising,
    "hasOrder": hasOrder,
    "hasVerification": hasVerification,
    "hasReturn": hasReturn
  };
}

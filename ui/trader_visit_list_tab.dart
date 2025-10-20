// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/database/functions/user.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/database/functions/visit_step.dart';
import 'package:shaylan_agent/main.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/program_error.dart';
import 'package:shaylan_agent/models/return_item_body.dart';
import 'package:shaylan_agent/models/user.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/models/visit_step.dart';
import 'package:shaylan_agent/pages/list_actions_page.dart';
import 'package:shaylan_agent/pages/trader_visits/trader_visits.dart';
import 'package:shaylan_agent/pages/visit_details_page.dart';
import 'package:shaylan_agent/services/local_database.dart';

part 'utils/trader_visit_tab_methods.dart';

class TraderVisitListTab extends StatelessWidget {
  final String filter;

  const TraderVisitListTab({
    super.key,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TraderVisitBloc, TraderVisitState>(
          listener: (context, state) {
            if (state is ImageUploadSuccess) {
              // Trigger a rebuild by fetching visits again
              context.read<TraderVisitBloc>().add(LoadVisits());
            } else if (state is ImageUploadFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error)),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<TraderVisitBloc, TraderVisitState>(
        builder: (context, state) {
          if (state is VisitLoading) {
            return Center(child: CircularProgressIndicator());
          } else if (state is VisitLoaded) {
            final visits = filter == 'send'
                ? state.sendVisits
                : filter == 'dont send'
                    ? state.dontSendVisits
                    : state.notFinishedVisits;
            return ListView.builder(
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];

                return FutureBuilder<bool>(
                  future: getWithNoImagesValue(visit.id!)
                      .then((value) => value == 'true'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return const Text("Ýalňyşlyk ýüze çykdy!");
                    }

                    final withNoImage = snapshot.data ?? false;

                    debugPrint(withNoImage.toString());

                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              color: withNoImage
                                  ? Colors.pink.shade100
                                  : Colors.white),
                          child: GestureDetector(
                            onTap: () async {
                              User user = await getUser();

                              List<ProductGroups> userGroups =
                                  user.productGroups ?? [];
                              VisitModel notFinishedVisit = visit;
                              if (visit.merchandisersInfoList != null) {
                                if (visit.merchandisersInfoList!.isNotEmpty) {
                                  notFinishedVisit =
                                      visit.copyWith(isMerchandisingDone: true);
                                }
                              }
                              filter == 'not finished'
                                  ? navigatorPushMethod(
                                      context,
                                      ListActionsPage(
                                        visit: notFinishedVisit,
                                        customer: await getCustomerByCardCode(
                                            notFinishedVisit.cardCode),
                                        productGroups: userGroups,
                                      ),
                                      false)
                                  //
                                  : navigatorPushMethod(
                                      context,
                                      VisitDetailsPage(visit: visit),
                                      false,
                                    );
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  ListTile(
                                      title: Text(visit.cardName),
                                      subtitle: Row(
                                        children: [
                                          Container(
                                              padding: EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Text(
                                                formatDateTime(visit.endTime!),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white),
                                              )),
                                          SizedBox(
                                            width: 4,
                                          ),
                                          visit.orderList != null &&
                                                  visit.orderList!.isNotEmpty
                                              ? Container(
                                                  padding: EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                  child: Text(
                                                    'Sargyt',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white),
                                                  ))
                                              : SizedBox.shrink()
                                        ],
                                      ),
                                      trailing: filter == 'dont send'
                                          ? InkWell(
                                              child: CircleAvatar(
                                                  child:
                                                      Icon(IconlyLight.send)),
                                              onTap: () async {

                                     
                                                final traderBloc = context
                                                    .read<TraderVisitBloc>();

                                                SharedPreferences prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                bool? sendwithphotopref = prefs
                                                    .getBool('sendWithPhoto');

                                                if (sendwithphotopref == true) {
                                                  Merchandising? merchandising =
                                                      await getMerchandising(
                                                          visit.id!, true);

                                                  List<OrderForServer> orders =
                                                      [];
                                                  OrderForServer? order =
                                                      await getOrder(visit.id!);
                                                  if (order != null) {
                                                    orders.add(order);
                                                  }

                                                  List<VisitStepModel> steps =
                                                      await getVisitStepsByVisitID(
                                                          visit.id!);
                                                  List<ReturnItemBody>
                                                      returnList = [];
                                                  ReturnItemBody?
                                                      returnItemBody =
                                                      await getReturnItemBody(
                                                          visit.id!);
                                                  if (returnItemBody != null) {
                                                    returnList
                                                        .add(returnItemBody);
                                                  }

                                                  NewCustomer? newCustomer =
                                                      await getUpdatedCustomer(
                                                          visit.id!);
                                                  User user = await getUser();

                                                  await setWithNoImagesTo(
                                                      visit.id!, '');
                                                  if (merchandising != null) {
                                                    merchandising =
                                                        merchandising.copyWith(
                                                            withNoImages: '');
                                                  }

                                                  List<Merchandising>
                                                      merchandisersInfoList =
                                                      [];
                                                  if (merchandising != null) {
                                                    merchandisersInfoList
                                                        .add(merchandising);
                                                  }

                                                  VisitModel visitToSend =
                                                      visit.copyWith(
                                                    empID: user.empId,
                                                    empName: user.firstName,
                                                    empLastName: user.lastName,
                                                    newCustomer: newCustomer,
                                                    endTime: DateTime.now()
                                                        .add(const Duration(
                                                            hours: 5))
                                                        .toIso8601String(),
                                                    visitType: 'visit_trader',
                                                    orderList: orders,
                                                    returnList: returnList,
                                                    stepsList: steps,
                                                    merchandisersInfoList:
                                                        merchandisersInfoList,
                                                  );

// visits with image
                                                  traderBloc.add(SendVisit(
                                                      true, visitToSend, context));

                                                  if (merchandising != null &&
                                                      merchandising
                                                          .merchandiserImages!
                                                          .isNotEmpty) {
                                                    // String? token = prefs
                                                    //     .getString('authToken');
                                                    final data = [];

                                                    for (MerchandiserImage image
                                                        in merchandising
                                                            .merchandiserImages!) {
                                                      File imageFile = File(
                                                          image.imagePath!);
                                                      MultipartFile
                                                          multipartImage =
                                                          await MultipartFile
                                                              .fromFile(
                                                        imageFile.path,
                                                        filename:
                                                            image.imageName ??
                                                                'image.jpg',
                                                      );

                                                      final jsonImage = {
                                                        "MerchandiserImageId":
                                                            image.merchandiserImageId ??
                                                                0,
                                                        "ImagePath":
                                                            image.imagePath,
                                                        "ImageName":
                                                            image.imageName,
                                                        "BeforeAfter": "before",
                                                        "Merchandiser": null,
                                                        "EncodedImage":
                                                            multipartImage,
                                                      };
                                                      data.add(jsonImage);
                                                    }

                                                    // traderBloc.add(
                                                    //   UploadMerchImages(
                                                    //       images: data,
                                                    //       token: token!,
                                                    //       visit: visit),
                                                    // );
                                                  }
                                                } else if (sendwithphotopref ==
                                                    false) {
                                                  Merchandising? merchandising =
                                                      await getMerchandising(
                                                          visit.id!,
                                                          // sendWithPhoto!
                                                          false);

                                                  List<OrderForServer> orders =
                                                      [];
                                                  debugPrint(
                                                      visit.id!.toString());
                                                  OrderForServer? order =
                                                      await getOrder(visit.id!);
                                                  if (order != null) {
                                                    debugPrint(order
                                                        .orderItems.first
                                                        .toJson()
                                                        .toString());
                                                    orders.add(order);
                                                  } else {
                                                    debugPrint('null');
                                                  }

                                                  List<VisitStepModel> steps =
                                                      await getVisitStepsByVisitID(
                                                          visit.id!);

                                                  List<ReturnItemBody>
                                                      returnList = [];
                                                  ReturnItemBody?
                                                      returnItemBody =
                                                      await getReturnItemBody(
                                                          visit.id!);

                                                  if (returnItemBody != null) {
                                                    returnList
                                                        .add(returnItemBody);
                                                  }

                                                  List<Merchandising>
                                                      merchandisersInfoList =
                                                      [];
                                                  // Merchandising? merchandising =
                                                  //     await getMerchandising(
                                                  //         visit.id!);

                                                  if (merchandising != null) {
                                                    for (MerchandiserImage mImage
                                                        in merchandising
                                                            .merchandiserImages!) {
                                                      debugPrint(
                                                          mImage.encodedImage ??
                                                              "");
                                                    }

                                                    merchandisersInfoList
                                                        .add(merchandising);
                                                    debugPrint(
                                                        'the merchandising data : \n${merchandising.toJson()}');
                                                  } else {
                                                    debugPrint('its null');
                                                  }
                                                  NewCustomer? newCustomer =
                                                      await getUpdatedCustomer(
                                                          visit.id!);

                                                  User user = await getUser();
                                                  VisitModel visitToSend =
                                                      visit.copyWith(
                                                          empID: user.empId,
                                                          empName:
                                                              user.firstName,
                                                          empLastName:
                                                              user.lastName,
                                                          newCustomer:
                                                              newCustomer,
                                                          endTime: DateTime
                                                                  .now()
                                                              .add(
                                                                  const Duration(
                                                                      hours: 5))
                                                              .toIso8601String(),
                                                          visitType:
                                                              'visit_trader',
                                                          orderList: orders,
                                                          returnList:
                                                              returnList,
                                                          stepsList: steps,
                                                          merchandisersInfoList:
                                                              merchandisersInfoList);

                                                  if (!context.mounted) return;

                                                  try {
                                                    context
                                                        .read<TraderVisitBloc>()
                                                        .add(SendVisit(false,
                                                            visitToSend,
                                                            context));
                                                  } catch (e) {
                                                    final error = ProgramError(
                                                      empId: user.empId,
                                                      fromWhere:
                                                          'Sending Visit',
                                                      happenedAt: DateTime.now()
                                                          .toIso8601String(),
                                                      errorText: e.toString(),
                                                    );

                                                    await ProgramError
                                                        .sendOrSaveError(error);
                                                  }
                                                } else {
                                                  final traderBloc = context
                                                      .read<TraderVisitBloc>();
                                                  bool? sendWithPhoto =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      bool selectedOption =
                                                          true;

                                                      return StatefulBuilder(
                                                        builder: (context,
                                                            setState) {
                                                          return AlertDialog(
                                                            title: Text(
                                                                "Birini saýlaň!"),
                                                            content: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                RadioListTile<
                                                                    bool>(
                                                                  title: Text(
                                                                      "Suratlar bilen ugrat"),
                                                                  value: true,
                                                                  groupValue:
                                                                      selectedOption,
                                                                  onChanged:
                                                                      (bool?
                                                                          value) {
                                                                    setState(() =>
                                                                        selectedOption =
                                                                            value!);
                                                                  },
                                                                ),
                                                                RadioListTile<
                                                                    bool>(
                                                                  title: Text(
                                                                      "Suratsyz ugrat"),
                                                                  value: false,
                                                                  groupValue:
                                                                      selectedOption,
                                                                  onChanged:
                                                                      (bool?
                                                                          value) {
                                                                    setState(() =>
                                                                        selectedOption =
                                                                            value!);
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        null), // Cancel
                                                                child: Text(
                                                                    "Goýbolsun"),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        selectedOption),
                                                                child:
                                                                    Text("Ok"),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                  );

                                                  if (sendWithPhoto != null) {
                                                    Merchandising?
                                                        merchandising =
                                                        await getMerchandising(
                                                            visit.id!,
                                                            sendWithPhoto);

                                                    List<OrderForServer>
                                                        orders = [];
                                                    OrderForServer? order =
                                                        await getOrder(
                                                            visit.id!);
                                                    if (order != null) {
                                                      orders.add(order);
                                                    }

                                                    List<VisitStepModel> steps =
                                                        await getVisitStepsByVisitID(
                                                            visit.id!);
                                                    List<ReturnItemBody>
                                                        returnList = [];
                                                    ReturnItemBody?
                                                        returnItemBody =
                                                        await getReturnItemBody(
                                                            visit.id!);
                                                    if (returnItemBody !=
                                                        null) {
                                                      returnList
                                                          .add(returnItemBody);
                                                    }

                                                    List<Merchandising>
                                                        merchandisersInfoList =
                                                        [];
                                                    if (merchandising != null) {
                                                      merchandisersInfoList
                                                          .add(merchandising);
                                                    }

                                                    NewCustomer? newCustomer =
                                                        await getUpdatedCustomer(
                                                            visit.id!);
                                                    User user = await getUser();

                                                    VisitModel visitToSend =
                                                        visit.copyWith(
                                                      empID: user.empId,
                                                      empName: user.firstName,
                                                      empLastName:
                                                          user.lastName,
                                                      newCustomer: newCustomer,
                                                      endTime: DateTime.now()
                                                          .add(const Duration(
                                                              hours: 5))
                                                          .toIso8601String(),
                                                      visitType: 'visit_trader',
                                                      orderList: orders,
                                                      returnList: returnList,
                                                      stepsList: steps,
                                                      merchandisersInfoList:
                                                          merchandisersInfoList,
                                                    );


          // default one
                                                    traderBloc.add(SendVisit(sendWithPhoto,
                                                        visitToSend, context));

                                                    if (sendWithPhoto &&
                                                        merchandising != null &&
                                                        merchandising
                                                            .merchandiserImages!
                                                            .isNotEmpty) {
                                                      // String? token =
                                                      //     prefs.getString(
                                                      //         'authToken');
                                                      final data = [];
                                                      for (MerchandiserImage image
                                                          in merchandising
                                                              .merchandiserImages!) {
                                                        File imageFile = File(
                                                            image.imagePath!);
                                                        MultipartFile
                                                            multipartImage =
                                                            await MultipartFile
                                                                .fromFile(
                                                          imageFile.path,
                                                          filename:
                                                              image.imageName ??
                                                                  'image.jpg',
                                                        );
                                                        final jsonImage = {
                                                          "MerchandiserImageId":
                                                              image.merchandiserImageId ??
                                                                  0,
                                                          "ImagePath":
                                                              image.imagePath,
                                                          "ImageName":
                                                              image.imageName,
                                                          "BeforeAfter":
                                                              "before",
                                                          "Merchandiser": null,
                                                          "EncodedImage":
                                                              multipartImage,
                                                        };
                                                        data.add(jsonImage);
                                                      }
                                                      // traderBloc.add(
                                                      //   UploadMerchImages(
                                                      //       images: data,
                                                      //       token: token!,
                                                      //       visit: visit),
                                                      // );
                                                    }
                                                  }
                                                }
                                              }
                                                )
                                          : withNoImage
                                              ? GestureDetector(
                                                  onTap: () async {
                                                    Merchandising?
                                                        merchandising =
                                                        await getMerchandising(
                                                            visit.id!, true);

                                                    if (merchandising != null &&
                                                        merchandising
                                                            .merchandiserImages!
                                                            .isNotEmpty) {
                                                      debugPrint(merchandising
                                                          .merchandiserImages!
                                                          .first
                                                          .toMap()
                                                          .toString());

                                                      SharedPreferences prefs =
                                                          await SharedPreferences
                                                              .getInstance();
                                                      String? token =
                                                          prefs.getString(
                                                              'authToken');

                                                      debugPrint(token);

                                                      final data = [];
                                                      for (MerchandiserImage image
                                                          in merchandising
                                                              .merchandiserImages!) {
                                                        File imageFile = File(
                                                            image.imagePath!);

                                                        MultipartFile
                                                            multipartImage =
                                                            await MultipartFile
                                                                .fromFile(
                                                          imageFile.path,
                                                          filename:
                                                              image.imageName ??
                                                                  'image.jpg',
                                                        );

                                                        final jsonImage = {
                                                          "MerchandiserImageId":
                                                              image.merchandiserImageId ??
                                                                  0, // Ensure int type
                                                          "ImagePath":
                                                              image.imagePath,
                                                          "ImageName": image
                                                              .imageName, // Fix wrong field
                                                          "BeforeAfter":
                                                              "before",
                                                          "Merchandiser": null,
                                                          "EncodedImage":
                                                              multipartImage,
                                                        };
                                                        data.add(jsonImage);
                                                      }

                                                      // context
                                                      //     .read<
                                                      //         TraderVisitBloc>()
                                                      //     .add(
                                                      //       UploadMerchImages(
                                                      //           images: data,
                                                      //           token: token!,
                                                      //           visit: visit),
                                                      //     );
                                                    }
                                                  },
                                                  child: CircleAvatar(
                                                    child: Icon(
                                                        size: 18,
                                                        IconlyLight.send),
                                                  ),
                                                )
                                              : null),
                                  Container(
                                    decoration:
                                        BoxDecoration(color: Colors.black),
                                    height: 0.5,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          } else if (state is VisitError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CircleAvatar(
                          child: IconButton(
                              onPressed: () {
                                navigatorPushMethod(context, MyApp(), false);
                              },
                              icon: Icon(Icons.login)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CircleAvatar(
                          child: IconButton(
                              onPressed: () {
                                context
                                    .read<TraderVisitBloc>()
                                    .add(LoadVisits());
                              },
                              icon: Icon(Icons.refresh)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else if (state is VisitVerificationWarning) {
            debugPrint('barder men');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(state.message),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircleAvatar(
                      child: IconButton(
                          onPressed: () {
                            context.read<TraderVisitBloc>().add(LoadVisits());
                          },
                          icon: Icon(Icons.refresh)),
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(child: Text("Wizit tapylmady"));
        },
      ),
    );
  }
}

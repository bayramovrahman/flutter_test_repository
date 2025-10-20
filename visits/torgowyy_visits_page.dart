// ignore_for_file: unused_field, use_build_context_synchronously

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:shaylan_agent/app/app_colors.dart';
import 'package:shaylan_agent/constants/asset_path.dart';
import 'package:shaylan_agent/database/config.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/database/functions/user.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/database/functions/visit_step.dart';
import 'package:shaylan_agent/methods/functions.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:shaylan_agent/models/customer.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/program_error.dart';
import 'package:shaylan_agent/models/return_item_body.dart';
import 'package:shaylan_agent/models/user.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/models/visit_step.dart';
import 'package:shaylan_agent/pages/accounts/supervisor/widgets/visits/show_visit_count_page.dart';
import 'package:shaylan_agent/pages/accounts/torgowyy/widgets/visits/torgowyy_view_visit_page.dart';
import 'package:shaylan_agent/pages/accounts/torgowyy/widgets/visits/torgowyy_visit_list_page.dart';
import 'package:shaylan_agent/pages/list_actions_page.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_bloc.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_event.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_state.dart';
import 'package:shaylan_agent/services/local_database.dart';
import 'package:shaylan_agent/utilities/alert_utils.dart';

class TorgowyyVisitsPage extends StatefulWidget {
  const TorgowyyVisitsPage({super.key});

  @override
  State<TorgowyyVisitsPage> createState() => _TorgowyyVisitsPageState();
}

class _TorgowyyVisitsPageState extends State<TorgowyyVisitsPage> {
  // Just empty column

  int selectedTabIndex = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPerformer;
  List<Customer> filteredCustomers = [];
  bool isLoading = false;
  DateTimeRange? _selectedDateRange;
  final String _selectedFilter = "";
  String? _selectedPointOfSale;
  final int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _selectedDateRange = DateTimeRange(start: todayStart, end: todayEnd);
    _loadFilteredVisits();
  }

  Future<void> _loadFilteredVisits() async {
    if (_selectedDateRange != null && context.mounted) {
      context.read<TraderVisitBloc>().add(
            LoadVisits(
              startTime: _selectedDateRange!.start,
              endTime: _selectedDateRange!.end,
            ),
          );
    }
  }

  void refreshTabs() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    final List<String> statusValues = [
      lang.statusSent,
      lang.statusNotSent,
      lang.statusNotApproved,
    ];
    debugPrint("Torgowyyvisitspage");

    return BlocListener<TraderVisitBloc, TraderVisitState>(
      listener: (context, state) {
        debugPrint("the state $state");
        if (state is VisitSendSuccess) {
          // showDialog (
          //   context: context,
          //   builder: (_) => AlertDialog(
          //     title: const Text("Üstünlik"),
          //     content: Text(state.message),
          //     actions: [
          //       TextButton(
          //         onPressed: () => Navigator.pop(context),
          //         child: const Text("Ok"),
          //       ),
          //     ],
          //   ),
          // );

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message ,style: TextStyle(color: Colors.black),), backgroundColor: Colors.lightGreen,));

        } else if (state is VisitError) {
                    ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent,));
        } else if (state is ImageUploadSuccess) {
        } else if (state is ImageUploadFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: AppBar(
            title: Text(
              lang.visits,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.monserratBold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                color: Colors.white,
                onSelected: (String value) async {
                  if (value == 'filter') {
                    pickDateRange();
                  } else if (value == 'download') {
                    bool hasInternet = await checkIntConn();

                    if (hasInternet) {
                      Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => ShowVisitCountPage()));
                    } else {
                      if (context.mounted) {
                        AlertUtils.noInternetConnection(
                            context: context,
                            message: lang.noIntConn,
                            lang: lang);

                        bool connected = false;
                        while (!connected) {
                          await Future.delayed(Duration(seconds: 1));
                          connected = await checkIntConn();
                        }
                        if (context.mounted) {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (context) => ShowVisitCountPage()));
                        }
                      }
                    }
                  }
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    side: BorderSide(color: Colors.white, width: 2.0)),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'filter',
                    child: GestureDetector(
                      child: Row(
                        children: [
                          Icon(
                            IconlyLight.filter_2,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Text(
                            lang.filter,
                            style: TextStyle(fontSize: 15, color: Colors.black),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
                offset: Offset(0, 40),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: AppColors.appBarGradient,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                IconlyLight.arrow_left_circle,
                size: 32.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDateRange != null)
              Container(
                padding:
                    EdgeInsets.symmetric(vertical: 2.0.h, horizontal: 16.0.w),
                color: Colors.grey[200],
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        IconlyLight.calendar,
                        size: 27.0.sp,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () async {
                        await pickDateRange();
                      },
                    ),
                    SizedBox(width: 5.0.w),
                    Text(
                      '${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.start)}  ➞  ${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.end)}',
                      style: TextStyle(
                        fontSize: 15.0.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.monserratBold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.clear_circled,
                        size: 23.0.sp,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                        });
                        getSelectedExpandedContent();
                      },
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                children: List.generate(statusValues.length, (index) {
                  return GestureDetector(
                    onTap: () => setState(() {
                      selectedTabIndex = index;
                    }),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: 4.0.w, vertical: 8.0.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.0.w, vertical: 6.0.h),
                      decoration: BoxDecoration(
                        color: selectedTabIndex == index
                            ? Colors.blue[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: selectedTabIndex == index
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Text(
                        statusValues[index],
                        style: TextStyle(
                          color: selectedTabIndex == index
                              ? Theme.of(context).primaryColor
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppFonts.secondaryFont,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
                child: _selectedDateRange == null
                    ? getSelectedExpandedContent()
                    : TorgowyyVisitListPage(
                        statusFilter: selectedTabIndex == 0
                            ? 'send'
                            : selectedTabIndex == 1
                                ? 'dont send'
                                : 'not finished',
                        startDate: _selectedDateRange?.start,
                        endDate: _selectedDateRange?.end,
                      )),
          ],
        ),
        floatingActionButton: selectedTabIndex == 0
            ? FloatingActionButton(
                onPressed: () async {
                  final outerContext = context;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      double progress = 0.0;
                      bool isClosed = false;
                      bool started = false;
                      List<Merchandising> merchToUpload = [];

                      return StatefulBuilder(
                        builder: (context, setState) {
                          if (!started) {
                            started = true;
                            Future.doWhile(() async {
                              await Future.delayed(Duration(milliseconds: 500));
                              if (isClosed) return false;

                              if (merchToUpload.isEmpty) {
                                merchToUpload = await getUnsentMerchImages();
                                if (merchToUpload.isEmpty) {
                                  isClosed = true;

                                  Navigator.of(dialogContext).pop();
                                  return false;
                                }
                              }

                              int total = merchToUpload.length;
                              for (int i = 0; i < total; i++) {
                                Merchandising merch = merchToUpload[i];

                                if (merch.merchandiserImages == null ||
                                    merch.merchandiserImages!.isEmpty) {
                                  continue;
                                }

                                List<dynamic> data = [];
                                for (var image in merch.merchandiserImages!) {
                                  File file = File(image.imagePath!);
                                  MultipartFile multipartImage =
                                      await MultipartFile.fromFile(
                                    file.path,
                                    filename: image.imageName ?? 'image.jpg',
                                  );

                                  data.add({
                                    "MerchandiserImageId":
                                        image.merchandiserImageId ?? 0,
                                    "ImagePath": image.imagePath,
                                    "ImageName": image.imageName,
                                    "BeforeAfter": "before",
                                    "Merchandiser": null,
                                    "EncodedImage": multipartImage,
                                  });
                                }

                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                String? token = prefs.getString('authToken');

                                if (token == null) {
                                  isClosed = true;
                                  Navigator.of(dialogContext).pop();
                                  return false;
                                }

                                outerContext.read<TraderVisitBloc>().add(
                                      UploadMerchImages(
                                          images: data,
                                          token: token,
                                          visit: merch.visit),
                                    );

                                await updateMerchandisingWithNoImageFlag(
                                    merch.merchandiserId!, false);

                                setState(() {
                                  progress = (i + 1) / total;
                                });

                                if (isClosed) return false;
                              }
                              refreshTabs();

                              if (!isClosed) {
                                isClosed = true;
                                Navigator.of(dialogContext).pop();
                              }
                              return false;
                            });
                          }

                          return PopScope(
                            canPop: true,
                            onPopInvokedWithResult: (didPop, result) async {
                              if (didPop) {
                                isClosed = true;
                              }
                            },
                            child: Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Wizit suratlary ugradylýar",
                                        style: TextStyle(fontSize: 20)),
                                    SizedBox(height: 10),
                                    Text("${(progress * 100).toInt()}%",
                                        style: TextStyle(fontSize: 16)),
                                    SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: Icon(IconlyLight.send),
              )
            : null,
      ),
    );
  }

  Widget getSelectedExpandedContent() {
    final List<String> filters = ['send', 'dont send', 'not finished'];
    final String selectedFilter = filters[selectedTabIndex];
    var lang = AppLocalizations.of(context)!;
    return Center(
      child: BlocProvider(
        create: (context) => TraderVisitBloc(dio: (Dio()))..add(LoadVisits()),
        child: BlocBuilder<TraderVisitBloc, TraderVisitState>(
          builder: (context, state) {
            if (state is VisitLoading || state is ImageUploading) {
              return Center(child: CircularProgressIndicator());
            } else if (state is VisitLoaded) {
              final visits = selectedFilter == 'send'
                  ? state.sendVisits
                  : selectedFilter == 'dont send'
                      ? state.dontSendVisits
                      : state.notFinishedVisits;

              if (visits.isEmpty) {
                return _showErrorMessage(context,
                    description: lang.notFoundVisit);
              }

              return ListView.builder(
                padding: EdgeInsets.only(bottom: 16.0),
                itemCount: visits.length,
                itemBuilder: (context, index) {
                  final visit = visits[index];
                  return Card(
                      child: FutureBuilder<bool>(
                          future: getWithNoImagesValue(visit.id!)
                              .then((value) => value == 'true'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            if (snapshot.hasError) {
                              return ListTile(
                                title: Text('Ýalňyşlyk ýüze çykdy!'),
                                trailing: Icon(Icons.error, color: Colors.red),
                              );
                            }
                            final withNoImage = snapshot.data ?? false;
                            return Container(
                              color: withNoImage
                                  ? Color.fromARGB(255, 243, 194, 210)
                                  : null,
                              child: ListTile(
                                  onTap: () async {
                                    User user = await getUser();

                                    List<ProductGroups> userGroups =
                                        user.productGroups ?? [];
                                    VisitModel notFinishedVisit = visit;
                                    if (visit.merchandisersInfoList != null) {
                                      if (visit
                                          .merchandisersInfoList!.isNotEmpty) {
                                        notFinishedVisit = visit.copyWith(
                                            isMerchandisingDone: true);
                                      }
                                    }
                                    selectedFilter == 'not finished'
                                        ? navigatorPushMethod(
                                            context,
                                            ListActionsPage(
                                              visit: notFinishedVisit,
                                              customer:
                                                  await getCustomerByCardCode(
                                                      notFinishedVisit
                                                          .cardCode),
                                              productGroups: userGroups,
                                            ),
                                            false)
                                        : navigatorPushMethod(
                                            context,
                                            TorgowyyViewVisitPage(
                                              visit: visit,
                                            ),
                                            false,
                                          );
                                  },
                                  leading: Icon(
                                    selectedTabIndex == 0
                                        ? CupertinoIcons.check_mark_circled
                                        : selectedTabIndex == 1
                                            ? CupertinoIcons.clock
                                            : CupertinoIcons.clear_circled,
                                    size: 24.0.sp,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  title: Text(
                                    visit.cardName,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 12.0.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppFonts.secondaryFont,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.calendar,
                                        size: 14.0.sp,
                                      ),
                                      SizedBox(width: 3.0.w),
                                      Text(
                                        formatDateTime(visit.endTime!),
                                        style: TextStyle(
                                          fontSize: 11.0.sp,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: AppFonts.secondaryFont,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: selectedFilter == 'send'
                                      ? InkWell(
                                          onTap: () {
                                            navigatorPushMethod(
                                              context,
                                              BlocProvider(
                                                create: (_) =>
                                                    TraderVisitBloc(dio: Dio()),
                                                child: TorgowyyViewVisitPage(
                                                    visit: visit),
                                              ),
                                              false,
                                            );
                                          },
                                          child: Icon(
                                            IconlyLight.arrow_right_circle,
                                            size: 24.0.sp,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        )
                                      : selectedFilter == 'dont send'
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

                                                  traderBloc.add(SendVisit(true,
                                                      visitToSend, context));

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
                                                        .add(SendVisit(
                                                            false,
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

                                                    traderBloc.add(SendVisit(
                                                        sendWithPhoto,
                                                        visitToSend,
                                                        context));

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
                                              })
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
                            );
                          }));
                },
              );
            } else {
              return Center(child: Text("Unexpected state"));
            }
          },
        ),
      ),
    );
  }

  String formatDateTime(String dateTimeString) {
    DateTime dateTime = DateTime.parse(dateTimeString);
    DateTime now = DateTime.now();

    bool isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return DateFormat('HH:mm').format(dateTime);
    } else {
      return DateFormat('dd-MM-yy').format(dateTime);
    }
  }

  Future<void> pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          ),
      locale: Localizations.localeOf(context),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              secondary: Colors.blue.shade100,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            iconTheme: IconThemeData(
              color: Colors.black,
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade400,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: picked.start,
          end: picked.end.add(Duration(hours: 23, minutes: 59, seconds: 59)),
        );
      });

      _loadFilteredVisits();
    }
  }

  Widget _showErrorMessage(BuildContext context,
      {required String description}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            AssetPath.walkingManAnimation,
            width: 150.0,
            height: 150.0,
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              fontFamily: AppFonts.secondaryFont,
            ),
          )
        ],
      ),
    );
  }
}

Future<List<Merchandising>> getUnsentMerchImages() async {
  final List<Map<String, dynamic>> results = await db.query(
    'merchandising',
    where: 'withNoImages = ?',
    whereArgs: ['true'],
  );
  return results.map((map) => Merchandising.fromMap(map)).toList();
}

Future<void> updateMerchandisingWithNoImageFlag(int merchId, bool flag) async {
  await db.update(
    'merchandising',
    {'withNoImages': flag ? 'true' : ''},
    where: 'id = ?',
    whereArgs: [merchId],
  );
}

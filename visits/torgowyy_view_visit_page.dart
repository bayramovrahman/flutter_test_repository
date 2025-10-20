import 'dart:io';
import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:shaylan_agent/models/customer.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/pages/items_list_page/items_list_view.dart';
import 'package:shaylan_agent/services/local_database.dart';

class TorgowyyViewVisitPage extends StatefulWidget {
  final VisitModel visit;

  const TorgowyyViewVisitPage({super.key, required this.visit});

  @override
  State<TorgowyyViewVisitPage> createState() => _TorgowyyViewVisitPageState();
}

class _TorgowyyViewVisitPageState extends State<TorgowyyViewVisitPage> {
  OrderForServer? order;
  String? imagePath;
  int selectedTabIndex = 0;
  String? orderStatus;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
    _fetchOrder();
  }

  Future<void> _loadImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      imagePath = directory.path;
    });
  }

  Future<void> _fetchOrder() async {
    final result = await getOrder(widget.visit.id!);
    final status = await getOrderStatus(widget.visit.id!);
    setState(() {
      order = result;
      orderStatus = status;
    });
  }

  double calculateTotalSum() {
    if (order == null || order!.orderItems.isEmpty) return 0.0;
    double total = order!.orderItems.fold(0.0, (sum, item) {
      return sum + (item.itemCountForOrder * double.parse(item.price));
    });

    return double.parse(total.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    // final Map<int, String> paymentOptions = {
    //   -1: lang.cashPayment,
    //   5: lang.enumeration,
    //   1: lang.sevenCredit,
    //   2: lang.fourteenCredit,
    //   3: lang.thirtyCredit,
    // };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            IconlyLight.arrow_left_circle,
            size: 28.0.r,
            color: Colors.white,
          ),
        ),
        title: Text(
          lang.informationVisit,
          style: TextStyle(
            fontSize: 18.0.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: AppFonts.monserratBold,
          ),
        ),
        actions: orderStatus == 'dont send'
            ? [
                IconButton(
                  onPressed: () async {
                    Customer customer =
                        await getCustomerByCardCode(widget.visit.cardCode);
                    List<OrderForServer> orderList = [];
                    orderList.add(order!);
                    VisitModel visitModel =
                        widget.visit.copyWith(orderList: orderList);
                    navigatorPushMethod(
                      // ignore: use_build_context_synchronously
                      context,
                      ItemListView(
                        visit: visitModel,
                        customer: customer,
                        editingCurrentOrder: true,
                        productGroup: order!.orderItems.first.productGroupId,
                        mmlList: [],
                        editBeforeSend: true,
                      ),
                      false,
                    );
                  },
                  icon: Icon(Icons.edit_sharp),
                  color: Colors.white,
                )
              ]
            : [],
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order != null && order!.orderItems.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    lang.ordersList,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: AppFonts.monserratBold,
                    ),
                  ),
                  initiallyExpanded: true,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0.r),
                      ),
                      elevation: 4,
                      child: Column(
                        children: [
                          ...order!.orderItems.map((item) {
                            final totalPrice = item.itemCountForOrder *
                                double.parse(item.price);
                            return ListTile(
                              leading: imagePath != null
                                  ? Image.file(
                                      File('$imagePath/${item.picturName}'),
                                      width: 50,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.no_photography,
                                          size: 40,
                                        );
                                      },
                                    )
                                  : const Icon(Icons.image, size: 40),
                              title: Text(
                                item.itemName,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 10.0.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.monserratBold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${lang.orderhistoryitemprice}: ${item.price} ${lang.manat}",
                                    style: TextStyle(
                                      fontSize: 10.0.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppFonts.secondaryFont,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    "${lang.total}: ${item.itemCountForOrder} ${lang.quantityforItems}",
                                    style: TextStyle(
                                      fontSize: 10.0.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppFonts.secondaryFont,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                "${totalPrice.toStringAsFixed(2)}\n${lang.manat}",
                                style: TextStyle(
                                  fontSize: 10.0.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.secondaryFont,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          })
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              order == null
                                  ? SizedBox.shrink()
                                  : Flexible(
                                    child: Text(
                                        "${lang.paymentOption}: ${switch (order!.groupNum) {
                                          -1 => lang.cashPayment,
                                          5 => lang.enumeration,
                                          1 => lang.sevenCredit,
                                          2 => lang.fourteenCredit,
                                          3 => lang.thirtyCredit,
                                          _ => 'Töleg görnüşi saýlanmady',
                                        }}",
                                        style: TextStyle(
                                          fontSize: 12.0.sp,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: AppFonts.secondaryFont,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ),
                              Text(
                                "${calculateTotalSum()} TMT",
                                style: TextStyle(
                                    fontSize: 12.0.sp,
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                          Divider(),
                          Text(
                            "${lang.comment}: ${order?.comment}",
                            style: TextStyle(
                              fontSize: 12.0.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppFonts.secondaryFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

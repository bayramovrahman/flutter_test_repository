// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconly/iconly.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/database/config.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/pages/trader_visits/trader_visits.dart';

class TraderVisitsPage extends StatefulWidget {
  const TraderVisitsPage({super.key});

  @override
  State<TraderVisitsPage> createState() => _TraderVisitsPageState();
}

class _TraderVisitsPageState extends State<TraderVisitsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool sendAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void refreshTabs() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TraderVisitBloc(dio: Dio())..add(LoadVisits()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text("Meniň wizitlerim"),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Ugradylan"),
              Tab(text: "Ugradylmadyk"),
              Tab(text: "Tamamlanmadyk"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            TraderVisitListTab(
              filter: 'send',
            ),
            TraderVisitListTab(filter: 'dont send'),
            TraderVisitListTab(filter: 'not finished'),
          ],
        ),
        floatingActionButton: _tabController.index == 0
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

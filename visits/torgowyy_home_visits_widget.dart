import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:shaylan_agent/app/app_colors.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_bloc.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_event.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_state.dart';

int selectedTabIndex = 0;

Widget torgowyHomeVisitsWidget(BuildContext context) {
  final List<String> filters = ['send', 'dont send', 'not finished'];
  final String selectedFilter = filters[selectedTabIndex];
  var lang = AppLocalizations.of(context)!;
  
  return Expanded(
    child: BlocProvider(
      create: (context) => TraderVisitBloc(dio: Dio())..add(LoadRecentVisits(limit: 50)),
      child: BlocBuilder<TraderVisitBloc, TraderVisitState>(
        builder: (context, state) {
          if (state is VisitLoading) {
            return Center(child: CircularProgressIndicator());
          } else if (state is VisitLoaded || state is RecentVisitsLoaded) {
            List<VisitModel> visits = [];
            
            if (state is VisitLoaded) {
              visits = selectedFilter == 'send'
                  ? state.sendVisits
                  : selectedFilter == 'dont send'
                      ? state.dontSendVisits
                      : state.notFinishedVisits;
            } else if (state is RecentVisitsLoaded) {
              visits = selectedFilter == 'send'
                  ? state.sendVisits
                  : selectedFilter == 'dont send'
                      ? state.dontSendVisits
                      : state.notFinishedVisits;
            }

            if (visits.isEmpty) {
              return Center(child: Text(lang.notFoundVisit));
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    Colors.blue.shade600,
                    Colors.blue,
                    Colors.blue.shade400,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.r),
                  topRight: Radius.circular(30.r),
                ),
              ),
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                itemCount: visits.length,
                itemBuilder: (context, index) {
                  final visit = visits[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            CupertinoIcons.check_mark_circled,
                            size: 28.sp,
                            color: Colors.white,
                          ),
                          title: Text(
                            visit.cardName,
                            maxLines: 2,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontFamily: AppFonts.monserratBold,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Divider(
                            color: Color.fromRGBO(255, 255, 255, 0.5),
                            thickness: 1.h,
                            height: 4.h,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          } else {
            return Center(
              child: Text("Unexpected state"),
            );
          }
        },
      ),
    ),
  );
}

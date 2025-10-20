
part of "../trader_visit_list_tab.dart";



String formatDateTime(String dateTimeString) {
    DateTime dateTime = DateTime.parse(dateTimeString);
    DateTime now = DateTime.now();

    // Check if it's today
    bool isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    // Format accordingly
    if (isToday) {
      return DateFormat('HH:mm').format(dateTime); // Format as hh:mm if today
    } else {
      return DateFormat('dd-MM-yy')
          .format(dateTime); // Format as dd-MM-yy if not today
    }
  }
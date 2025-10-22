import 'dart:io';
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

part 'internet_connection_state.dart';

class InternetConnectionCubit extends Cubit<InternetConnectionState> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  InternetConnectionCubit() : super(InternetConnectionInitial()) {
    _monitorInternetConnection();
    _checkInitialConnection();
  }

  void _monitorInternetConnection() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.contains(ConnectivityResult.none)) {
          emit(InternetConnectionDisconnected());
        } else {
          // Check if we have any actual connectivity (wifi, mobile, ethernet)
          if (results.any((result) => 
              result == ConnectivityResult.wifi || 
              result == ConnectivityResult.mobile ||
              result == ConnectivityResult.ethernet)) {
            _checkActualInternetAccess();
          } else {
            emit(InternetConnectionDisconnected());
          }
        }
      },
    );
  }

  Future<void> _checkInitialConnection() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      emit(InternetConnectionDisconnected());
    } else if (connectivityResults.any((result) => 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet)) {
      _checkActualInternetAccess();
    } else {
      emit(InternetConnectionDisconnected());
    }
  }

  Future<void> _checkActualInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        emit(InternetConnectionConnected());
      } else {
        emit(InternetConnectionDisconnected());
      }
    } on SocketException catch (_) {
      emit(InternetConnectionDisconnected());
    } catch (e) {
      emit(InternetConnectionDisconnected());
    }
  }

  Future<void> checkConnection() async {
    await _checkInitialConnection();
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}

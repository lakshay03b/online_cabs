
import 'package:flutter/cupertino.dart';
import 'package:user1/models/directions.dart';

class AppInfo extends ChangeNotifier{
  Directions? userPickUpLocation, userDropOffLocation;
  int countTotalTrips =0;
  // List<String> historyTripKeysList =[];
  // List<TripHistoryModel> allTripHistoryInformationList =[];

  void updatePickUpLocationAddress(Directions userPickUpAddress){
    userPickUpLocation = userPickUpAddress;
    notifyListeners();
  }

  void updateDropOffLocationAddress(Directions dropOffAddress){
    userDropOffLocation = dropOffAddress;
    notifyListeners();
  }


}
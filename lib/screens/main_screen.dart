import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:user1/Assistants/assistant_methods.dart';
import 'package:user1/Assistants/grofire_assistant.dart';
import 'package:user1/global/global.dart';
import 'package:user1/global/map_key.dart';
import 'package:user1/infoHandler/app_info.dart';
import 'package:user1/models/active_nearby_available_drivers.dart';
import 'package:user1/screens/drawer_screen.dart';
import 'package:user1/screens/precise_pickup_location.dart';
import 'package:user1/screens/search_places_screen.dart';
import 'package:user1/widgets/progress_dialog.dart';

import '../models/directions.dart';
import '../splashScreen/splash_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}): super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  LatLng? pickLocation;
  loc.Location location = loc.Location();
  String? _address;

  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  double searchLocationContainerHeight = 220;
  double waitingResponseFromDriverContainerHeight =0;
  double assignedDriverInfoContainerHeight = 0;
  double suggestedRidesContainerHeight = 0 ;
  double searchingForDriverContainerHeight = 0;

  Position? userCurrentPosition;
  var geoLocation = Geolocator();

  LocationPermission? _locationPermission;
  double bottomPaddingOfMap = 0;

  List<LatLng> pLineCoOrdinatesList = [];
  Set<Polyline> polylineSet = {};

  Set<Marker> markersSet = {};
  Set<Circle> circlesSet = {};

  String userName = "";
  String userEmail = "";



  bool openNavigationDrawer = true;

  bool activeNearbyDriverKeyLoaded = false;

  BitmapDescriptor? activeNearbyIcon;

  DatabaseReference? referenceRideRequest;

  String selectedVehicleType = "";

  String driverRideStatus = "Driver is coming";
  StreamSubscription<DatabaseEvent>? tripRidesRequestInfoStreamSubscription ;

  List<ActiveNearByAvailableDrivers> onlineNearByAvailableDriverList = [];

  String userRideRequestStatus ="";
  bool requestPositionInfo = true;

  locateUserPosition() async{
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 15);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoOrdinates(userCurrentPosition!, context);
    print("This is our address = "+ humanReadableAddress);

    userName = userModelCurrentInfo!.name!;
    userEmail = userModelCurrentInfo!.email!;

    initializeGeoFireListener();
    //
    // AssistantMethods.readTripsKeysForOnlineUser(context);
  }

  initializeGeoFireListener(){
    Geofire.initialize("activeDrivers");

    Geofire.queryAtLocation(userCurrentPosition!.latitude, userCurrentPosition!.longitude, 10)!
    .listen((map) {
      print(map);

      if(map != null){
        var callBack = map["callBack"];

        switch(callBack){
          case Geofire.onKeyEntered:
              ActiveNearByAvailableDrivers activeNearByAvailableDrivers = ActiveNearByAvailableDrivers();
              activeNearByAvailableDrivers.locationLatitude = map["latitude"];
              activeNearByAvailableDrivers.locationLongitude = map["longitude"];
              activeNearByAvailableDrivers.driverId = map["key"];
              GeofireAssistant.activeNearByAvailableDriversList.add(activeNearByAvailableDrivers);
              if(activeNearbyDriverKeyLoaded == true){
                  displayActiveDriversOnUserMap();
              }
              break;

          case Geofire.onKeyExited:
              GeofireAssistant.deleteOfflineDriverFromList(map["key"]);
              displayActiveDriversOnUserMap();
              break;

          case Geofire.onKeyMoved:
              ActiveNearByAvailableDrivers activeNearByAvailableDrivers = ActiveNearByAvailableDrivers();
              activeNearByAvailableDrivers.locationLatitude = map["latitude"];
              activeNearByAvailableDrivers.locationLongitude = map["longitude"];
              activeNearByAvailableDrivers.driverId = map["key"];
              GeofireAssistant.updateActiveNearByAvailableDriverLocation(activeNearByAvailableDrivers);
              displayActiveDriversOnUserMap();
              break;
              //display those online active drivers on user's map
          case Geofire.onGeoQueryReady:
            activeNearbyDriverKeyLoaded = true;
            displayActiveDriversOnUserMap();
            break;
        }
      }

      setState(() {

      });
    });
  }

  displayActiveDriversOnUserMap() {
    setState(() {
      markersSet.clear();
      circlesSet.clear();

      Set<Marker> driversMarkerSet = Set<Marker>();

      for(ActiveNearByAvailableDrivers eachDriver in GeofireAssistant.activeNearByAvailableDriversList){
        LatLng eachDriverActivePosition = LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);

        Marker marker = Marker(
            markerId: MarkerId(eachDriver.driverId!),
            position: eachDriverActivePosition,
            icon: activeNearbyIcon!,
            rotation: 360,
        );

        driversMarkerSet.add(marker);
      }

      setState(() {
        markersSet = driversMarkerSet;
      });
    });
  }

  createActiveNearByDriverIconMarker(){
    if(activeNearbyIcon == null){
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: Size(2,2));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "images/car.png").then((value){
        activeNearbyIcon =value;
      });
    }
  }

  Future<void> drawPolyLineFromOriginToDestination(bool darkTheme) async{
    var originPosition = Provider.of<AppInfo>(context, listen: false).userPickUpLocation;
    var destinationPosition = Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

    var originLatLng = LatLng(originPosition!.locationLatitude!, originPosition.locationLongitude!);
    var destinationLatLng = LatLng(destinationPosition!.locationLatitude!, destinationPosition.locationLongitude!);

    showDialog(
        context: context,
        builder: (BuildContext context) => ProgressDialog(message: "Please Wait...",),
    );

    var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(originLatLng, destinationLatLng);

    setState(() {
        tripDirectionDetailsInfo = directionDetailsInfo;
    });

    Navigator.pop(context);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodePolyLinePointsResultList = pPoints.decodePolyline(directionDetailsInfo.e_points!);
    
    pLineCoOrdinatesList.clear();
    
    if(decodePolyLinePointsResultList.isNotEmpty){
      decodePolyLinePointsResultList.forEach((PointLatLng pointLatLng) {
        pLineCoOrdinatesList.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    polylineSet.clear();

    setState(() {
      Polyline polyline = Polyline(
        color: Colors.black,
          polylineId: PolylineId("PolylineId"),
        jointType: JointType.round,
        points: pLineCoOrdinatesList,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        width: 5,
      );

      polylineSet.add(polyline);
    });

    LatLngBounds boundsLatLng;
    if(originLatLng.latitude > destinationLatLng.latitude && originLatLng.longitude > destinationLatLng.longitude){
      boundsLatLng = LatLngBounds(southwest: destinationLatLng, northeast: originLatLng);
    }
    else if(originLatLng.longitude > destinationLatLng.longitude){
      boundsLatLng = LatLngBounds(
          southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
          northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude),
      );
    }
    else if (originLatLng.latitude > destinationLatLng.latitude){
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
        northeast:LatLng(originLatLng.latitude, destinationLatLng.longitude),
      );
    }
    else{
      boundsLatLng = LatLngBounds(southwest: originLatLng, northeast: destinationLatLng);
    }

    newGoogleMapController!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng,65));
    Marker originMarker = Marker(
      markerId: MarkerId("originID"),
      infoWindow: InfoWindow(title: originPosition.locationName, snippet: "Origin"),
      position: originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    Marker destinationMarker = Marker(
      markerId: MarkerId("destinationID"),
      infoWindow: InfoWindow(title: destinationPosition.locationName, snippet: "Destination"),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      markersSet.add(originMarker);
      markersSet.add(destinationMarker);
    });

    Circle originCircle = Circle(
        circleId: CircleId("originID"),
        fillColor: Colors.green,
        radius: 12,
        strokeWidth: 3,
        strokeColor: Colors.white,
        center: originLatLng,
    );

    Circle destinationCircle = Circle(
      circleId: CircleId("destinationID"),
      fillColor: Colors.red,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: destinationLatLng,
    );

    setState(() {
      circlesSet.add(originCircle);
      circlesSet.add(destinationCircle);
    });

  }

  void _animateToUser() async {
    // Get the current position of the user.
    var position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Create a LatLng object from the user's position.
    LatLng userLocation = LatLng(position.latitude, position.longitude);

    // Animate the camera to the user's location.
    newGoogleMapController?.animateCamera(
      CameraUpdate.newLatLng(userLocation),
    );
  }


  void showSearchingForDriversContainer(){
    setState(() {
      searchingForDriverContainerHeight = 200;
    });
  }

  void showSuggestedRidesContainer(){
    setState(() {
      suggestedRidesContainerHeight = 400;
      bottomPaddingOfMap = 1000;
    });
  }


  checkIfLocationPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();

    if(_locationPermission == LocationPermission.denied){
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  saveRideRequestInformation(String selectedVehicleType){
    //1. save the ride request Information
      referenceRideRequest = FirebaseDatabase.instance.ref().child("All Ride Request").push();

      var originLocation = Provider.of<AppInfo>(context,listen: false).userPickUpLocation;
      var destinationLocation = Provider.of<AppInfo>(context,listen: false).userDropOffLocation;

      Map originLocationMap = {
        //"key: value"
        "latitude" : originLocation!.locationLatitude.toString(),
        "longitude" : originLocation.locationLongitude.toString(),
      };

      Map destinationLocationMap = {
        "latitude" : destinationLocation!.locationLatitude.toString(),
        "longitude" : destinationLocation.locationLongitude.toString(),
      };

      Map userInformationMap = {
        "origin" : originLocationMap,
        "destination" : destinationLocationMap,
        "time" : DateTime.now().toString(),
        "userName" : userModelCurrentInfo!.name,
        "userPhone" : userModelCurrentInfo!.phone,
        "originAddress" : originLocation.locationName,
        "destinationAddress" : destinationLocation.locationName,
        "driverId": "waiting"
      };

      referenceRideRequest!.set(userInformationMap);

      tripRidesRequestInfoStreamSubscription = referenceRideRequest!.onValue.listen((eventSnap) async {
        if(eventSnap.snapshot.value == null){
          return;
        }
        if((eventSnap.snapshot.value as Map)["car_details"] != null){
          setState(() {
            driverCarDetails = (eventSnap.snapshot.value as Map)["Car_details"].toString();
          });
        }

        if((eventSnap.snapshot.value as Map)["driverPhone"] != null){
          setState(() {
            driverCarDetails = (eventSnap.snapshot.value as Map)["driverPhone"].toString();
          });
        }
        if((eventSnap.snapshot.value as Map)["driverName"] != null){
          setState(() {
            driverCarDetails = (eventSnap.snapshot.value as Map)["driverName"].toString();
          });
        }
        if((eventSnap.snapshot.value as Map)["status"] != null){
          setState(() {
             userRideRequestStatus = (eventSnap.snapshot.value as Map)["status"].toString();
          });
        }

        if((eventSnap.snapshot.value as Map)["driverLocation"] != null){
          double driverCurrentPositionLat = double.parse((eventSnap.snapshot.value as Map)["driverLocation"]["latitude"].toString());
          double driverCurrentPositionLng = double.parse((eventSnap.snapshot.value as Map)["driverLocation"]["longitude"].toString());

          LatLng driverCurrentPositionLatLng = LatLng(driverCurrentPositionLat, driverCurrentPositionLng);

          //status = accepted
          if(userRideRequestStatus == "accepted"){
            updateArrivalTimeToUserPickUpLocation(driverCurrentPositionLatLng);
          }
          //status = arrived
          if(userRideRequestStatus == "arrived"){
            setState(() {
              driverRideStatus = "Driver has arrived";
            });
          }

          //status = onTrip
          if(userRideRequestStatus == "ontrip"){
            updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng);
          }

          // if(userRideRequestStatus == "ended"){
          //   if((eventSnap.snapshot.value as Map)["fareAmount"] != null){
          //     double fareAmount = double.parse((eventSnap.snapshot.value as Map)["fareAmount"].toString());
          //
          //     var response = await showDialog(
          //         context: context,
          //         builder: (BuildContext context) => PayFareAmountDialog(
          //           fareAmount : fareAmount,
          //         )
          //     );
          //
          //     if(response == "Cash Paid"){
          //       //user can rate the driver now
          //       if((eventSnap.snapshot.value as Map)["driverId"] != null){
          //         String assignedDriverId = (eventSnap.snapshot.value as Map)["driverId"].toString();
          //         //Navigator.push(context, MaterialPageRoute(builder: (c) => RateDriverScreen()));
          //
          //         referenceRideRequest!.onDisconnect();
          //         tripRidesRequestInfoStreamSubscription!.cancel();
          //       }
          //     }
          //   }
          // }
        }
      });

      onlineNearByAvailableDriverList = GeofireAssistant.activeNearByAvailableDriversList;
      searchNearestOnlineDriers(selectedVehicleType);
  }

  searchNearestOnlineDriers(String selectedVehicleType) async{
    if(onlineNearByAvailableDriverList.length == 0){
      //cancel/delete the rideRequest Information
      referenceRideRequest!.remove();

      setState(() {
        polylineSet.clear();
        markersSet.clear();
        circlesSet.clear();
        pLineCoOrdinatesList.clear();
      });

      Fluttertoast.showToast(msg: "No online nearest Driver Available");
      Fluttertoast.showToast(msg: "Search Again.");

      Future.delayed(Duration(milliseconds: 4000), (){
        referenceRideRequest!.remove();
        Navigator.push(context, MaterialPageRoute(builder: (c) => MainScreen()));
      });

      return;
    }

    await retrieveOnlineDriversInformation(onlineNearByAvailableDriverList);

    print("Driver List: "+ driversList.toString());

    for(int i=0; i< driversList.length;i++){
      if(driversList[i]["car_details"]["type"] == selectedVehicleType){
        AssistantMethods.sendNotificationTODriverNow(driversList[i]["token"],referenceRideRequest!.key!,context);
      }
    }

    Fluttertoast.showToast(msg: "Notification sent Successfully");

    showSearchingForDriversContainer();

    await FirebaseDatabase.instance.ref().child("All Ride Requests").child(referenceRideRequest!.key!).child("driverId").onValue.listen((eventRideRequestSnapshot) {
      print("EventSnapshot: ${eventRideRequestSnapshot.snapshot.value}");
      if(eventRideRequestSnapshot.snapshot.value != null){
        if(eventRideRequestSnapshot.snapshot.value != "waiting"){
          showUIForAssignedDriverInfo();
       }
     }
    });
  }

  updateArrivalTimeToUserPickUpLocation(driverCurrentPositionLatLng) async {
    if(requestPositionInfo == true){
      requestPositionInfo = false;
      LatLng userPickUpPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);

      var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(
            driverCurrentPositionLatLng,userPickUpPosition,
      );

      if((directionDetailsInfo == null)){
        return;
      }

      setState(() {
        driverRideStatus = "Driver is Coming: " + directionDetailsInfo.duration_text.toString();
      });

      requestPositionInfo = true;
    }
  }

  updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng) async {
    if(requestPositionInfo == true){
      requestPositionInfo = false;

      var dropOffLocation = Provider.of<AppInfo>(context,listen: false).userDropOffLocation;

      LatLng userDestinationPosition = LatLng(dropOffLocation!.locationLatitude!,dropOffLocation.locationLongitude!);

      var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(driverCurrentPositionLatLng, userDestinationPosition);

      if(directionDetailsInfo == null){
        return;
      }
      setState(() {
        driverRideStatus = "Going Towards Destination:" + directionDetailsInfo.duration_text.toString();
      });

      requestPositionInfo = true;
    }
  }

  showUIForAssignedDriverInfo() {
    setState(() {
      waitingResponseFromDriverContainerHeight = 0;
      searchLocationContainerHeight = 0;
      assignedDriverInfoContainerHeight = 200;
      suggestedRidesContainerHeight = 0;
      bottomPaddingOfMap = 200;
    });
  }

  retrieveOnlineDriversInformation(List onlineNearByAvailableDriversList) async {
    driversList.clear();
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("drivers");

    for(int i=0;i< onlineNearByAvailableDriverList.length; i++ ){
      await ref.child(onlineNearByAvailableDriversList[i].driverId.toString()).once().then((dataSnapshot){
        var driverKeyInfo = dataSnapshot.snapshot.value;

        driversList.add(driverKeyInfo);
        print("driver key information = " + driversList.toString());
      });
    }
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {

    bool darkTheme= MediaQuery.of(context).platformBrightness == Brightness.dark;
    createActiveNearByDriverIconMarker();

    return GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _scaffoldState,
        drawer: DrawerScreen(),
        body: Stack(
          children: [
            GoogleMap(
                mapType: MapType.normal,
                myLocationEnabled: true,
                zoomGesturesEnabled: true,
                zoomControlsEnabled: false,
                initialCameraPosition: _kGooglePlex,
                polylines: polylineSet,
                markers: markersSet,
                circles: circlesSet,
                myLocationButtonEnabled: false,
                onMapCreated: (GoogleMapController controller){
                  _controllerGoogleMap.complete(controller);
                  newGoogleMapController = controller;
                  setState(() {
                    bottomPaddingOfMap =500;
                  });

                  locateUserPosition();
                },
            ),

            Positioned(
              bottom: 190,
              right: 16,
              child: CircleAvatar(
                  backgroundColor: Colors.black,
                  radius: 25,
                  child: IconButton(
                    onPressed: (){
                      _animateToUser();
                    },
                    icon:Icon(Icons.my_location,color: Colors.white),
              ),
                )
              ),
            //custom hamburger button for drawer
            Positioned(
                top:50,
                left:20,
                child: Container(
                  child: GestureDetector(
                    onTap: (){
                      _scaffoldState.currentState!.openDrawer();
                    },
                    child: CircleAvatar(
                     backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.white,
                      child: Icon(
                        Icons.menu,
                        color:Colors.black,
                      ),
                    ),
                  ),
                ),
            ),

            //ui for searching location
           Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 50, 10, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: darkTheme ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: darkTheme ? Colors.grey.shade900 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, color: darkTheme ? Colors.amber.shade400 : Colors.blue,),
                                          SizedBox(width: 10,),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("From",
                                                style: TextStyle(color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                                fontSize: 12,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              Text(Provider.of<AppInfo>(context).userPickUpLocation != null
                                                  ? (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0,30)+"..."
                                                  :"Not Getting Address",
                                                style: TextStyle(color: Colors.grey,
                                                fontSize: 14
                                                ),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                  ),

                                  SizedBox(height: 5,),

                                  Divider(height: 1,
                                    thickness: 2,
                                    color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                  ),

                                  SizedBox(height: 5,),

                                  Padding(
                                      padding:EdgeInsets.all(5),
                                      child: GestureDetector(
                                        onTap: () async {
                                          //go to search places screen
                                          var responseFromSearchScreen = await Navigator.push(context, MaterialPageRoute(builder:(c) => SearchPlacesScreen()));

                                          if(responseFromSearchScreen == "obtainedDropOff"){
                                            setState(() {
                                              openNavigationDrawer = false;
                                            });
                                          }

                                          await drawPolyLineFromOriginToDestination(darkTheme);
                                        },
                                        child: Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, color: darkTheme ? Colors.amber.shade400 : Colors.blue,),
                                            SizedBox(width: 10,),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("To",
                                                  style: TextStyle(
                                                      color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                                Text(Provider.of<AppInfo>(context).userDropOffLocation != null
                                                    ? (Provider.of<AppInfo>(context).userDropOffLocation!.locationName!)
                                                    :"Where to?",
                                                  style: TextStyle(color: Colors.grey,
                                                      fontSize: 14
                                                  ),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),

                      SizedBox(height: 5,),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                              onPressed: (){
                                Navigator.push(context, MaterialPageRoute(builder: (c) => PrecisePickUpScreen()));
                              },
                              child: Text(
                                "Change Pick Up Address",
                                style: TextStyle(
                                  color: darkTheme ? Colors.black : Colors.white,
                                ),
                              ),
                            style: ElevatedButton.styleFrom(
                              primary: darkTheme ? Colors.amber.shade400 : Colors.blue,
                              textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              )
                            ),
                          ),

                          SizedBox(width: 10,),
                          ElevatedButton(
                            onPressed: (){
                              if(Provider.of<AppInfo>(context, listen: false).userDropOffLocation != null){
                                showSuggestedRidesContainer();
                              }
                              else{
                                Fluttertoast.showToast(msg: "Please select destination location");
                              }
                            },
                            child: Text(
                              "Show Fare",
                              style: TextStyle(
                                color: darkTheme ? Colors.black : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                                primary: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                textStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                )
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
           ),

            // ui for suggested rides
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: suggestedRidesContainerHeight,
                  decoration: BoxDecoration(
                    color: darkTheme ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    )
                  ),
                  child:Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Icon(
                                  Icons.star,
                                  color: Colors.white,
                                ),
                              ),

                              SizedBox(width: 15,),

                              Text(
                                Provider.of<AppInfo>(context).userPickUpLocation != null
                                    ? (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0,30)+"..."
                                    :"Not Getting Address",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20,),


                        SizedBox(width: 20,),

                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Icon(
                                  Icons.star,
                                  color: Colors.white,
                                ),
                              ),

                              SizedBox(width: 15,),

                              Text(
                                Provider.of<AppInfo>(context).userDropOffLocation != null
                                    ? (Provider.of<AppInfo>(context).userDropOffLocation!.locationName!)
                                    :"Where to?",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),

                        SizedBox(height: 20,),

                        Text("SUGGESTED RIDES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 20,),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: (){
                                setState(() {
                                  selectedVehicleType = "Car";
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == "Car" ? (darkTheme ? Colors.amber.shade400 : Colors.lightBlue) : (darkTheme ? Colors.black54 : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(25),
                                  child: Column(
                                    children: [
                                      Image.asset("images/cars.png", scale: 2,),
                              
                                      SizedBox(height: 8,),
                              
                                      Text(
                                        "Car",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedVehicleType == "Car" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      ),
                              
                                      SizedBox(height: 2,),
                              
                                      Text(
                                      tripDirectionDetailsInfo != null ? "₹ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 2) * 83).toStringAsFixed(2)}"
                                        : "null",
                                        style: TextStyle(
                                          color: selectedVehicleType == "Car" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: (){
                                setState(() {
                                  selectedVehicleType = "Bike";
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == "Bike" ? (darkTheme ? Colors.amber.shade400 : Colors.lightBlue) : (darkTheme ? Colors.black26 : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(25),
                                  child: Column(
                                    children: [
                                      Image.asset("images/bike.png", scale: 2,),

                                      SizedBox(height: 8,),

                                      Text(
                                        "Bike",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedVehicleType == "Bike" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      ),

                                      SizedBox(height: 2,),

                                      Text(
                                        tripDirectionDetailsInfo != null ? "₹ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 0.5) * 83).toStringAsFixed(2)}"
                                            : "null",
                                        style: TextStyle(
                                          color: selectedVehicleType == "Bike" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: (){
                                setState(() {
                                  selectedVehicleType = "Auto";
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedVehicleType == "Auto" ? (darkTheme ? Colors.amber.shade400 : Colors.lightBlue) : (darkTheme ? Colors.black54 : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(25),
                                  child: Column(
                                    children: [
                                      Image.asset("images/cng.png", scale: 2,),

                                      SizedBox(height: 8,),

                                      Text(
                                        "Auto",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedVehicleType == "Auto" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      ),

                                      SizedBox(height: 2,),

                                      Text(
                                        tripDirectionDetailsInfo != null ? "₹ ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 1.5) * 83).toStringAsFixed(2)}"
                                            : "null",
                                        style: TextStyle(
                                          color: selectedVehicleType == "Auto" ? (darkTheme? Colors.black : Colors.white) : (darkTheme ? Colors.white : Colors.black),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),

                        SizedBox(height: 20,),

                        Expanded(
                            child: GestureDetector(
                              onTap: (){
                                if(selectedVehicleType != ""){
                                  saveRideRequestInformation(selectedVehicleType);
                                }
                                else{
                                  Fluttertoast.showToast(msg: "Please select a vehicle from \n suggested rides.");
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: darkTheme ? Colors.amber.shade400 : Colors.green,
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Center(
                                  child: Text(
                                    "Request A Ride",
                                    style: TextStyle(
                                      color: darkTheme ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            )
                        )


                      ],
                    ),
                  )
                )
            )
          ],
        )
      ),
    );
  }
}


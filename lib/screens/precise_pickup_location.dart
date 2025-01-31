import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';

import '../Assistants/assistant_methods.dart';
import '../global/map_key.dart';
import '../infoHandler/app_info.dart';
import '../models/directions.dart';

class PrecisePickUpScreen extends StatefulWidget {
  const PrecisePickUpScreen({super.key});

  @override
  State<PrecisePickUpScreen> createState() => _PrecisePickUpScreenState();
}

class _PrecisePickUpScreenState extends State<PrecisePickUpScreen> {

  LatLng? pickLocation;
  loc.Location location = loc.Location();

  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;

  Position? userCurrentPosition;
  double bottomPaddingOfMap = 0;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  locateUserPosition() async{
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 15);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoOrdinates(userCurrentPosition!, context);

  }

  getAddressFromLatLng() async{
    try{
      GeoData data = await Geocoder2.getDataFromCoordinates(
          latitude: pickLocation!.latitude,
          longitude: pickLocation!.longitude,
          googleMapApiKey: mapKey
      );
      setState(() {
        Directions userPickUpAddress = Directions();
        userPickUpAddress.locationLatitude=pickLocation!.latitude;
        userPickUpAddress.locationLongitude =pickLocation!.longitude;
        userPickUpAddress.locationName= data.address;

        Provider.of<AppInfo>(context, listen: false).updatePickUpLocationAddress(userPickUpAddress);
      });
    }catch(e){
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {

    bool darkTheme= MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller){
              _controllerGoogleMap.complete(controller);
              newGoogleMapController = controller;

              setState(() {
                  bottomPaddingOfMap =50;
              });

              locateUserPosition();
            },
              onCameraMove: (CameraPosition? position){
                if(pickLocation != position!.target){
                  setState(() {
                    pickLocation = position.target;
                  });
                }
            },
            onCameraIdle: (){
                getAddressFromLatLng();
            },
          ),
          Positioned(
              bottom: 60,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black,
                child: IconButton(
                  onPressed: (){
                    locateUserPosition();
                  },
                  icon:Icon(Icons.my_location,color: Colors.white),
                ),
              )
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(top: 60, bottom: bottomPaddingOfMap),
              child: Image.asset("images/pick.png",height: 45,width: 45,),
            ),
          ),

          Positioned(
              top: 40,
              right: 20,
              left: 20,
              child: GestureDetector(
                onTap: (){
                },
                child:  Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.all(20),
                  child: Text(Provider.of<AppInfo>(context).userPickUpLocation != null
                      ? (Provider.of<AppInfo>(context).userPickUpLocation!.locationName!).substring(0,30)+"..."
                      :"Not Getting Address",
                    overflow: TextOverflow.visible, softWrap: true,
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

          ),

          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: (){
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    primary: darkTheme ? Colors.amber.shade400 : Colors.blue,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                  child: Text(
                      "Set Current Location",
                    style: TextStyle(
                      color: darkTheme ? Colors.black : Colors.white,
                    ),
                  ),
              ),
          ),
          )
        ],

      )
    );
  }
}

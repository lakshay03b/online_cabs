import 'package:firebase_auth/firebase_auth.dart';
import 'package:user1/models/direction_details_info.dart';

import '../models/user_model.dart';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
User? currentUser;

UserModel? userModelCurrentInfo;

String cloudMessagingServerToken = "key=AAAAOa2Bt70:APA91bHwWvFPRyxqXugP8ixErIBvp-svSOsSQIFAy-BjAMPlmgmKcVl-z9HowAhpE3-b60KW_5KGUYHPWjqcERJm1TnIMDSyzAq3-3e7zUX1b6EBtpVzvuy3sKwL6bhWUPE7LH_kvo9c";
List driversList = [];
DirectionDetailsInfo? tripDirectionDetailsInfo;
String userDropOffAddress="";
String driverCarDetails = "" ;
String driverName ="";
String driverPhone = "";

double countRatingStar = 0.0;
String titleStarRating ="";

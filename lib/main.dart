import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user1/infoHandler/app_info.dart';
import 'package:user1/splashScreen/splash_screen.dart';
import 'package:user1/themeProvider/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async{
  runApp(const MyApp());
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => AppInfo(),
      child: MaterialApp(
        title: 'Uber_clone',
        themeMode: ThemeMode.system,
        theme: MyThemes.lightTheme,
        darkTheme: MyThemes.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}

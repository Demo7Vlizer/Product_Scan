import 'package:eopystocknew/views/camera.dart';
import 'package:eopystocknew/views/home.dart';
import 'package:eopystocknew/views/orderCreate.dart';
import 'package:eopystocknew/views/order_ops/order_list.dart';
import 'package:eopystocknew/views/settings.dart';
import 'package:eopystocknew/views/product_list.dart';
import 'package:flutter/material.dart';
import 'controllers/stockController.dart';
import 'controllers/userController.dart';
import 'package:eopystocknew/services/network/request_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RequestClient.loadServerUrl();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eopy Stock Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => HomePage(),
        "/camera": (context) => CameraPage(title: "Barcode Scanner"),
        "/settings": (context) => SettingsPage(),
        "/user": (context) => UserList(),
        "/stock": (context) => StockList(),
        "/order": (context) => OrderListPage(),
        "/orderCreate": (context) => OrderCreate(),
        "/products": (context) => ProductListPage(),
      },
    );
  }
}

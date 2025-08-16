import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import views
import 'package:eopystocknew/views/camera.dart';
import 'package:eopystocknew/views/home.dart';
import 'package:eopystocknew/views/settings.dart';
import 'package:eopystocknew/views/product_list.dart';
import 'package:eopystocknew/views/multi_item_sale.dart';
import 'package:eopystocknew/views/sales_dashboard.dart';
import 'package:eopystocknew/views/sales_history.dart';
import 'package:eopystocknew/views/add_product.dart';

// Import controllers
import 'controllers/stockController.dart';
import 'controllers/userController.dart';

// Import services
import 'package:eopystocknew/services/network/request_service.dart';

/// Entry point of the application
/// Initializes Flutter widgets and loads server configuration
Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations (portrait mode)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Load server URL configuration
  try {
    await RequestClient.loadServerUrl();
    print('🌐 Server URL loaded: ${RequestClient.baseUrl}');
  } catch (e) {
    debugPrint('❌ Error loading server URL: $e');
  }
  
  // Run the application
  runApp(StockManagementApp());
}

/// Main application widget
/// Configures app theme, routes, and navigation
class StockManagementApp extends StatelessWidget {
  const StockManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App configuration
      title: 'Eopy Stock Management',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: _buildAppTheme(),
      
      // Navigation configuration
      initialRoute: AppRoutes.home,
      routes: _buildAppRoutes(),
      
      // Error handling
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }

  /// Builds the application theme
  ThemeData _buildAppTheme() {
    const primaryColor = Color(0xFF2196F3); // Blue
    const secondaryColor = Color(0xFF4CAF50); // Green
    
    return ThemeData(
      // Use Material 3 design system
        useMaterial3: true,
      
      // Color scheme
        colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
          brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        ),


      
      // App bar theme
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(
          color: Colors.black87,
          size: 24,
        ),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          ),
        ),
      
      // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      
      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // List tile theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Builds application routes
  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      AppRoutes.home: (context) => HomePage(),
      AppRoutes.camera: (context) => CameraPage(title: "Barcode Scanner"),
      AppRoutes.settings: (context) => SettingsPage(),
      AppRoutes.users: (context) => UserList(),
      AppRoutes.stock: (context) => StockList(),
      AppRoutes.products: (context) => ProductListPage(),
      AppRoutes.multiItemSale: (context) => MultiItemSalePage(),
      AppRoutes.salesDashboard: (context) => SalesDashboardPage(),
      AppRoutes.salesHistory: (context) => SalesHistoryPage(),
      AppRoutes.addProduct: (context) {
        // Extract barcode from route arguments
          final String? barcode = ModalRoute.of(context)?.settings.arguments as String?;
          return AddProductPage(barcode: barcode ?? '');
        },
    };
  }
}

/// Application route constants
/// Centralized route management for better maintainability
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  // Route constants
  static const String home = "/";
  static const String camera = "/camera";
  static const String settings = "/settings";
  static const String users = "/user";
  static const String stock = "/stock";
  static const String products = "/products";
  static const String multiItemSale = "/multiItemSale";
  static const String salesDashboard = "/salesDashboard";
  static const String salesHistory = "/salesHistory";
  static const String addProduct = "/addProduct";

  /// Get all available routes
  static List<String> get allRoutes => [
        home,
        camera,
        settings,
        users,
        stock,
        products,
        multiItemSale,
        salesDashboard,
        salesHistory,
        addProduct,
      ];

  /// Check if a route exists
  static bool isValidRoute(String route) {
    return allRoutes.contains(route);
  }
}

/// Application constants
/// Centralized configuration values
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App information
  static const String appName = 'Eopy Stock Management';
  static const String appVersion = '1.0.0';
  
  // Network timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Snackbar durations
  static const Duration successSnackbarDuration = Duration(seconds: 2);
  static const Duration errorSnackbarDuration = Duration(seconds: 4);
  static const Duration infoSnackbarDuration = Duration(seconds: 3);
}

/// Application utilities
/// Helper functions and extensions
class AppUtils {
  // Private constructor to prevent instantiation
  AppUtils._();

  /// Show a success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: AppConstants.successSnackbarDuration,
      ),
    );
  }

  /// Show an error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: AppConstants.errorSnackbarDuration,
      ),
    );
  }

  /// Show an info snackbar
  static void showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: AppConstants.infoSnackbarDuration,
      ),
    );
  }

  /// Show a loading snackbar
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoadingSnackbar(
    BuildContext context,
    String message,
  ) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(minutes: 5), // Long duration for loading
      ),
    );
  }

  /// Hide current snackbar
  static void hideCurrentSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                : null,
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor != null ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Format date string for display
  static String formatDisplayDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Unknown date';
    }
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference == 1) {
        return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference < 7) {
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return '${weekdays[date.weekday - 1]} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateString;
    }
  }

  /// Validate phone number
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{8,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'\s'), ''));
  }

  /// Validate barcode
  static bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;
    // Allow alphanumeric characters, hyphens, and underscores
    final barcodeRegex = RegExp(r'^[a-zA-Z0-9\-_]+$');
    return barcodeRegex.hasMatch(barcode) && barcode.length >= 3;
  }

  /// Format quantity for display
  static String formatQuantity(int? quantity) {
    if (quantity == null || quantity == 0) return '0';
    if (quantity == 1) return '1 unit';
    return '$quantity units';
  }

  /// Get color for quantity status
  static Color getQuantityStatusColor(int? quantity) {
    if (quantity == null || quantity == 0) {
      return Colors.red;
    } else if (quantity < 5) {
      return Colors.orange;
    } else if (quantity < 20) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }
}
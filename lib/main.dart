import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/screens/splash_redirect.dart';
import 'package:untitled/services/connectivity_service.dart';
import 'package:untitled/utils/performance_helper.dart';
import 'package:untitled/widgets/connectivity_wrapper.dart';

import 'exports/providers_export.dart';
import 'exports/screens_export.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply performance optimizations
  PerformanceHelper.optimizeSystemUI();
  PerformanceHelper.optimizeForLowEndDevices();

  // Initialize Firebase and connectivity in parallel
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    ConnectivityService().initialize(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      builder: (context, child) {
        return ConnectivityWrapper(child: child ?? Container());
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashRedirector());
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const SplashRedirector());
          case '/signIn':
            return MaterialPageRoute(builder: (_) => SignInScreen());
          case '/signUp':
            return MaterialPageRoute(builder: (_) => SignUpScreen());
          case '/forgetPassword':
            return MaterialPageRoute(builder: (_) => ForgetPasswordScreen());
          case '/admin':
            return MaterialPageRoute(builder: (_) => AdminDashboard());
          case '/salesman':
            return MaterialPageRoute(builder: (_) => SalesmanDashboard());
          case '/vendor':
            return MaterialPageRoute(builder: (_) => VendorDashboard());
          case '/customer':
            return MaterialPageRoute(builder: (_) => CustomerDashboard());
          case '/storeuser':
            return MaterialPageRoute(builder: (_) => StoreuserDashboard());

          // Sales Management Routes
          case '/sales':
            return MaterialPageRoute(builder: (_) => const SalesScreen());
          case '/add-sale':
            return MaterialPageRoute(builder: (_) => const AddSaleScreen());
          case '/draft-sales':
            return MaterialPageRoute(builder: (_) => const DraftSalesScreen());
          case '/sales-history':
            return MaterialPageRoute(
              builder: (_) => const SalesHistoryScreen(),
            );
          case '/customer-payments':
            return MaterialPageRoute(
              builder: (_) => const CustomerPaymentsScreen(),
            );
          case '/process-return':
            return MaterialPageRoute(
              builder: (_) => const ProcessReturnScreen(),
            );
          case '/sales-reports':
            return MaterialPageRoute(
              builder: (_) => const SalesReportsScreen(),
            );
          // Purchase Management Routes
          case '/purchase':
            return MaterialPageRoute(builder: (_) => const PurchaseScreen());
          case '/add-purchase':
            return MaterialPageRoute(builder: (_) => const AddPurchaseScreen());
          case '/draft-purchases':
            return MaterialPageRoute(
              builder: (_) => const DraftPurchasesScreen(),
            );
          case '/purchase-history':
            return MaterialPageRoute(
              builder: (_) => const PurchaseHistoryScreen(),
            );
          case '/vendor-payments':
            return MaterialPageRoute(
              builder: (_) => const VendorPaymentsScreen(),
            );
          case '/process-purchase-return':
            return MaterialPageRoute(
              builder: (_) => const ProcessPurchaseReturnScreen(),
            );
          case '/purchase-reports':
            return MaterialPageRoute(
              builder: (_) => const PurchaseReportsScreen(),
            );

          // Settings Routes
          case '/onboarding-settings':
            return MaterialPageRoute(
              builder: (_) => const OnboardingSettingsScreen(),
            );

          default:
            return MaterialPageRoute(
              builder: (_) =>
                  Scaffold(body: Center(child: Text("No page found"))),
            );
        }
      },
    );
  }
}

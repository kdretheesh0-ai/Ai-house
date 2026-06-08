import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PlanXApp());
}

class PlanXApp extends StatelessWidget {
  const PlanXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nirai – AI Floor Plan Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C896),
          surface: Color(0xFF132237),
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFCDD6E0)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFCDD6E0)),
        ),
      ),
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: Builder(
          builder: (context) {
            return Container(
              color: const Color(0xFF0D1B2A),
              child: MaxWidthBox(
                maxWidth: 1200,
                child: ResponsiveScaledBox(
                  width: ResponsiveValue<double>(
                    context,
                    defaultValue: 430, // Default to a standard mobile width (iPhone 14 Pro Max size)
                    conditionalValues: [
                    Condition.equals(name: MOBILE, value: 430),
                    Condition.between(start: 451, end: 800, value: 600),
                    Condition.between(start: 801, end: 1200, value: 800),
                    Condition.largerThan(name: DESKTOP, value: 1000),
                  ],
                ).value,
                child: BouncingScrollWrapper.builder(context, child!),
              ),
             ),
            );
          },
        ),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: const SplashScreen(),
    );
  }
}

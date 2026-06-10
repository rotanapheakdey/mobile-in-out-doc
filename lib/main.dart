import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/document_viewmodel.dart';
import 'views/login_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => DocumentViewModel()),
      ],
      child: const MinistryApp(),
    ),
  );
}

class MinistryApp extends StatelessWidget {
  const MinistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INB Document System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003F88),
          primary: const Color(0xFF003F88),    
          secondary: const Color(0xFFE01A22),   
          background: const Color(0xFFF1F5F9), 
          surface: Colors.white,
        ),
        
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003F88),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 0.5
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF003F88), width: 2),
          ),
        ),
      ),
      home: LoginView(),
    );
  }
}
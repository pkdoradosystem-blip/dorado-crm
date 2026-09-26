import 'package:flutter/material.dart';

import 'core/auth/auth_service.dart';
import 'core/network/api_client.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/change_password_page.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'services/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DoradoCRM());
}

class DoradoCRM extends StatefulWidget {
  const DoradoCRM({super.key});

  @override
  State<DoradoCRM> createState() => _DoradoCRMState();
}

class _DoradoCRMState extends State<DoradoCRM> {
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final MenuService _menuService;
  late final FormService _formService;

  bool _checkingSession = true;
  bool _loggedIn = false;
  bool _forcePasswordReset = false;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);

    _menuService = MenuService(_apiClient);
    _formService = FormService(_apiClient);

    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await _authService.hasSession();

    if (!mounted) return;

    bool forcePasswordReset = false;

    if (loggedIn) {
      final user = await _authService.getSavedUser();

      forcePasswordReset =
          user?['force_password_reset'] == true;
    }

    if (!mounted) return;

    setState(() {
      _loggedIn = loggedIn;
      _forcePasswordReset = forcePasswordReset;
      _checkingSession = false;
    });
  }

  Future<void> _onLoginSuccess() async {
    final user = await _authService.getSavedUser();

    if (!mounted) return;

    setState(() {
      _loggedIn = true;
      _forcePasswordReset =
          user?['force_password_reset'] == true;
    });
  }

  void _onPasswordChanged() {
    setState(() {
      _forcePasswordReset = false;
    });
  }

  void _onLogout() {
    setState(() {
      _loggedIn = false;
      _forcePasswordReset = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dorado CRM',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5C9E),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF4F7FB),
        inputDecorationTheme:
            const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: _checkingSession
          ? const _StartupPage()
          : !_loggedIn
              ? LoginPage(
                  authService: _authService,
                  onLoginSuccess: _onLoginSuccess,
                )
              : _forcePasswordReset
                  ? ChangePasswordPage(
                      authService: _authService,
                      onPasswordChanged:
                          _onPasswordChanged,
                    )
                  : DashboardPage(
                      authService: _authService,
                      menuService: _menuService,
                      formService: _formService,
                      onLogout: _onLogout,
                    ),
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 56,
              color: Color(0xFF0B5C9E),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Dorado CRM'),
          ],
        ),
      ),
    );
  }
}
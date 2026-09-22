import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'screens/menu/dynamic_menu_page.dart';
import 'services/services.dart';

void main() {
  runApp(const DoradoCRM());
}

class DoradoCRM extends StatelessWidget {
  const DoradoCRM({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = ApiClient();

    final MenuService menuService = MenuService(apiClient);
    final FormService formService = FormService(apiClient);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dorado CRM',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5C9E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      ),
      home: DynamicMenuPage(
        title: 'Dorado CRM',
        menuService: menuService,
        formService: formService,
      ),
    );
  }
}
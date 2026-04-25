import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/admin_service.dart';
import 'tabs/admin_home_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_food_tab.dart';
import 'tabs/admin_health_tab.dart';
import 'tabs/admin_education_tab.dart';

enum _AdminTab { home, users, food, health, education }

class AdminScreen extends StatefulWidget {
  final int initialTabIndex;
  const AdminScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminService _adminService = AdminService();
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  String _titleForTab(_AdminTab tab) {
    switch (tab) {
      case _AdminTab.home: return 'Dashboard Admin';
      case _AdminTab.users: return 'Manajemen User';
      case _AdminTab.food: return 'Manajer Makanan';
      case _AdminTab.health: return 'Rekam Medis';
      case _AdminTab.education: return 'Edukasi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _AdminTab.values[_selectedTabIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titleForTab(currentTab)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/admin-settings'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          AdminHomeTab(adminService: _adminService),
          AdminUsersTab(adminService: _adminService),
          AdminFoodTab(adminService: _adminService),
          AdminHealthTab(adminService: _adminService),
          AdminEducationTab(adminService: _adminService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'User'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'Food'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Edukasi'),
        ],
      ),
    );
  }
}

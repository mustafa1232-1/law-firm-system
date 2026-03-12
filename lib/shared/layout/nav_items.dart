import 'package:flutter/material.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}

const appNavItems = <AppNavItem>[
  AppNavItem(label: 'Dashboard', path: '/dashboard', icon: Icons.dashboard_rounded),
  AppNavItem(label: 'Lawyer Hub', path: '/lawyer-hub', icon: Icons.hub_rounded),
  AppNavItem(label: 'Cases', path: '/cases', icon: Icons.balance_rounded),
  AppNavItem(label: 'Clients', path: '/clients', icon: Icons.people_alt_rounded),
  AppNavItem(label: 'Research', path: '/research', icon: Icons.travel_explore_rounded),
  AppNavItem(label: 'Constitution', path: '/constitution', icon: Icons.account_balance_rounded),
  AppNavItem(label: 'Laws', path: '/laws', icon: Icons.menu_book_rounded),
  AppNavItem(label: 'Decisions', path: '/decisions', icon: Icons.gavel_rounded),
  AppNavItem(label: 'AI Workspace', path: '/ai-workspace', icon: Icons.auto_awesome_rounded),
  AppNavItem(label: 'Hearings', path: '/hearings', icon: Icons.event_note_rounded),
  AppNavItem(label: 'Tasks', path: '/tasks', icon: Icons.task_alt_rounded),
  AppNavItem(label: 'Documents', path: '/documents', icon: Icons.folder_copy_rounded),
  AppNavItem(label: 'Billing', path: '/billing', icon: Icons.receipt_long_rounded),
  AppNavItem(label: 'Notifications', path: '/notifications', icon: Icons.notifications_active_rounded),
  AppNavItem(label: 'Admin', path: '/admin', icon: Icons.admin_panel_settings_rounded),
  AppNavItem(label: 'Settings', path: '/settings', icon: Icons.settings_rounded),
];

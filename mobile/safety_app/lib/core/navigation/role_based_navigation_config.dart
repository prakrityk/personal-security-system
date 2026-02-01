// lib/core/navigation/role_based_navigation_config.dart

import 'package:flutter/material.dart';

/// Defines the bottom navigation tabs available for each user role
class RoleBasedNavigationConfig {
  /// Navigation items for Guardian and Personal users
  static const List<NavigationItem> guardianPersonalTabs = [
    NavigationItem(
      index: 0,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      route: 'sos',
    ),
    NavigationItem(
      index: 1,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Family',
      route: 'family',
    ),
    NavigationItem(
      index: 2,
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
      label: 'Safety',
      route: 'safety',
    ),
    NavigationItem(
      index: 3,
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      label: 'Map',
      route: 'map',
    ),
  ];

  /// Navigation items for Dependent users (Child/Elderly)
  static const List<NavigationItem> dependentTabs = [
    NavigationItem(
      index: 0,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      route: 'sos',
    ),
    NavigationItem(
      index: 1,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Family',
      route: 'family',
    ),
  ];

  /// Get navigation items based on user role
  static List<NavigationItem> getNavigationItemsForRole(String? roleName) {
    if (roleName == null) return guardianPersonalTabs;

    switch (roleName.toLowerCase()) {
      case 'child':
      case 'elderly':
        return dependentTabs;
      case 'guardian':
      case 'global_user':
      default:
        return guardianPersonalTabs;
    }
  }

  /// Check if a user role has access to a specific tab
  static bool hasAccessToTab(String? roleName, String tabRoute) {
    final items = getNavigationItemsForRole(roleName);
    return items.any((item) => item.route == tabRoute);
  }

  /// Get the default landing tab index for a role
  static int getDefaultTabIndex(String? roleName) {
    return 0; // Always start at Home (SOS) tab
  }
}

/// Represents a navigation item in the bottom navigation bar
class NavigationItem {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const NavigationItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
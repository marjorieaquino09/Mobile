
import 'package:flutter/material.dart';

import '../../models/notification_item.dart';
import '../../services/cart_store.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/app_bottom_nav.dart';

import '../cart/cart_screen.dart';
import '../credit/credit_screen.dart';
import '../inventory/inventory_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';

import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const int homeTab = 0;
  static const int inventoryTab = 1;
  static const int scanTab = 2;
  static const int notifTab = 3;
  static const int profileTab = 4;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = MainShell.homeTab;
  int _coveringRoutes = 0;

  @override
  void initState() {
    super.initState();

    CartStore.instance.onOpenCartRequested = _openCart;

    PushNotificationService.instance.onNotificationOpened =
        _handleNotificationOpen;

    final pending =
        PushNotificationService.instance.consumePendingOpen();

    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleNotificationOpen(pending);
        }
      });
    }
  }

  @override
  void dispose() {
    CartStore.instance.onOpenCartRequested = null;

    PushNotificationService.instance.onNotificationOpened = null;

    super.dispose();
  }

  Future<void> _pushRoute(Widget screen) async {
    if (!mounted) return;

    setState(() {
      _coveringRoutes++;
    });

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => screen,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _coveringRoutes--;
        });
      }
    }
  }

  void _openCart() {
    _pushRoute(const CartScreen());
  }

  void _openNotif() {
    _onTabSelected(MainShell.notifTab);
  }

  void _onTabSelected(int index) {
    if (index < MainShell.homeTab ||
        index > MainShell.profileTab) {
      return;
    }

    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  void _handleNotificationOpen(NotificationType type) {
    if (!mounted) return;

    switch (type) {
      case NotificationType.lowStock:
      case NotificationType.inventory:
        _onTabSelected(MainShell.inventoryTab);
        break;

      case NotificationType.payment:
      case NotificationType.orderReady:
      case NotificationType.transaction:
        _onTabSelected(MainShell.profileTab);
        _pushRoute(const OrdersScreen());
        break;

      case NotificationType.creditOverdue:
        _onTabSelected(MainShell.profileTab);
        _pushRoute(const CreditScreen());
        break;
    }
  }

  void _onNotifRelated(NotificationType type) {
    if (type == NotificationType.lowStock ||
        type == NotificationType.inventory) {
      _onTabSelected(MainShell.inventoryTab);
    } else {
      _handleNotificationOpen(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == MainShell.homeTab,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          _onTabSelected(MainShell.homeTab);
        }
      },
      child: Scaffold(
        extendBody: true,

        body: IndexedStack(
          index: _currentIndex,
          children: [
            // HOME
            HomeScreen(
              onOpenCart: _openCart,
              onOpenNotif: _openNotif,
              onOpenProfile: () {
                _onTabSelected(MainShell.profileTab);
              },
            ),

            // INVENTORY
            const InventoryScreen(),

            // SCAN
            ScanScreen(
              onOpenCart: _openCart,
              isActive: _currentIndex == MainShell.scanTab &&
                  _coveringRoutes == 0,
            ),

            // NOTIFICATIONS
            NotificationsScreen(
              onOpenRelated: _onNotifRelated,
            ),

            // PROFILE
            const ProfileScreen(),
          ],
        ),

        // BOTTOM NAVIGATION
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}

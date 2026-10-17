# Redesign & Theming Checklist (Light / Dark / System)

This checklist tracks the redesign of the entire Sari-Sari app to match the reference design (`docs/reference/auth_reference.png`), with full Light, Dark, and System theme support.

---

## 1. Design System & Theme Foundation

| Component / File | Light OK | Dark OK | Notes |
| :--- | :---: | :---: | :--- |
| `lib/core/theme/app_colors.dart` | [ ] | [ ] | Exact light & dark palettes, cream ~#F5F4E8, dark ~#0F1F1A, mint ~#7FBF9F, amber ~#F4A93A |
| `lib/core/theme/app_text_styles.dart` | [ ] | [ ] | Outfit font hierarchy with semantic coloring |
| `lib/core/theme/app_theme.dart` | [ ] | [ ] | Material 3 ColorScheme + SariColors ThemeExtension + full widget themes |
| `lib/core/theme/theme_controller.dart` | [ ] | [ ] | 3 modes (Light/Dark/System), SharedPreferences persistence, reactive system brightness |
| `lib/main.dart` theme binding | [ ] | [ ] | Loads mode before runApp, no theme flash, dynamic SystemUiOverlayStyle |

---

## 2. Reusable Core Widgets (`lib/core/widgets/`)

| Widget | File Path | Light OK | Dark OK |
| :--- | :--- | :---: | :---: |
| `AuthWaveBackground` | `lib/core/widgets/auth_wave_background.dart` | [ ] | [ ] |
| `AppTextField` | `lib/core/widgets/app_text_field.dart` | [ ] | [ ] |
| `PrimaryButton` | `lib/core/widgets/primary_button.dart` | [ ] | [ ] |
| `OutlinedPillButton` | `lib/core/widgets/outlined_pill_button.dart` | [ ] | [ ] |
| `AppCard` | `lib/core/widgets/app_card.dart` | [ ] | [ ] |
| `ProductCard` | `lib/core/widgets/product_card.dart` / `lib/widgets/product_card.dart` | [ ] | [ ] |
| `CategoryChip` | `lib/core/widgets/category_chip.dart` | [ ] | [ ] |
| `AppSearchBar` | `lib/core/widgets/app_search_bar.dart` | [ ] | [ ] |
| `SectionHeader` | `lib/core/widgets/section_header.dart` | [ ] | [ ] |
| `AppBottomNav` | `lib/core/widgets/app_bottom_nav.dart` / `lib/widgets/app_bottom_nav.dart` | [ ] | [ ] |
| `EmptyState` | `lib/core/widgets/empty_state.dart` | [ ] | [ ] |
| `LoadingIndicator` | `lib/core/widgets/loading_indicator.dart` | [ ] | [ ] |
| `AppSnackbar` | `lib/core/widgets/app_snackbar.dart` | [ ] | [ ] |
| `ConfirmDialog` | `lib/core/widgets/confirm_dialog.dart` | [ ] | [ ] |

---

## 3. Screens & Page-Level Widgets

| Screen / Page | File Path | Light OK | Dark OK | Status / Notes |
| :--- | :--- | :---: | :---: | :--- |
| **1. Splash Screen** | `lib/screens/splash_screen.dart` | [ ] | [ ] | Themed bg, centered logo, subtle wave bottom-right, ~1.5s animation |
| **2. Onboarding Screen** | N/A (Not present in project) | N/A | N/A | Verified non-existent |
| **3. Login Screen** | `lib/screens/auth/login_screen.dart` | [ ] | [ ] | Top-left & bottom-right waves, pill inputs, remember me, forgot pwd, login button, sign up link |
| **4. Sign Up Screen** | `lib/screens/auth/signup_screen.dart` | [ ] | [ ] | Matches login style, name/email/store/pwd pill inputs, sign in link |
| **5. Forgot Password Screen** | `lib/screens/auth/forgot_password_screen.dart` | [ ] | [ ] | Back arrow, email pill field, Send Reset Link, Back to Login |
| **6. Check Your Email Screen** | `lib/screens/auth/forgot_password_screen.dart` | [ ] | [ ] | Envelope circle + check badge, info box with spam advice, outlined Back to Login |
| **7. Reset Password Screen** | `lib/screens/auth/reset_password_screen.dart` | [ ] | [ ] | New & confirm password pill fields, eye toggles, 6+ char & match validation |
| **8. Main Shell** | `lib/screens/home/main_shell.dart` | [ ] | [ ] | Scaffold, tab switching, floating pill bottom nav container |
| **9. Home Screen** | `lib/screens/home/home_screen.dart` | [ ] | [ ] | Header avatar + cart/bell circles, pill search, category chips, products grid |
| **10. Product Detail Screen** | `lib/screens/home/product_detail_screen.dart` | [ ] | [ ] | Card styling, rounded white image backdrop, form inputs |
| **11. Cart Screen** | `lib/screens/cart/cart_screen.dart` | [ ] | [ ] | Themed list items, quantity adjusters, checkout pill button, clear cart |
| **12. Checkout Screen** | `lib/screens/cart/checkout_screen.dart` | [ ] | [ ] | Payment options, amount input, change calculation, success flow |
| **13. Scan Screen** | `lib/screens/scan/scan_screen.dart` | [ ] | [ ] | Barcode scanner, overlay, manual barcode input, quick add/lookup |
| **14. Notifications Screen** | `lib/screens/notifications/notifications_screen.dart` | [ ] | [ ] | Themed notification cards, unread badges, mark as read, clear |
| **15. Inventory Screen** | `lib/screens/inventory/inventory_screen.dart` | [ ] | [ ] | Product list, search/filter, stock level chips, add/edit/delete triggers |
| **16. Profile Screen** | `lib/screens/profile/profile_screen.dart` | [ ] | [ ] | Store/user avatar, stats summary, menu tiles (Orders, Credit, Settings) |
| **17. Edit Profile Screen** | `lib/screens/profile/edit_profile_screen.dart` | [ ] | [ ] | Form fields, photo upload, save button |
| **18. Settings Screen** | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] | Appearance (Light/Dark/System), Currency, Tax, Notifications, Logout |
| **19. Orders Screen** | `lib/screens/orders/orders_screen.dart` | [ ] | [ ] | Order history cards, status badges, details modal |
| **20. Credit / Utang Screen** | `lib/screens/credit/credit_screen.dart` | [ ] | [ ] | Customer ledger, balance cards, add credit record |
| **21. Dashboard Screen & Section** | `lib/screens/dashboard/dashboard_screen.dart`, `dashboard_section.dart` | [ ] | [ ] | Metrics stat cards, sales charts |

---

## 4. Dialogs, Bottom Sheets & Modals

| Modal / Dialog | Trigger Location | Light OK | Dark OK |
| :--- | :--- | :---: | :---: |
| Clear Cart Confirmation Dialog | `lib/screens/cart/cart_screen.dart` | [ ] | [ ] |
| Delete Product Confirmation Dialog | `lib/screens/inventory/inventory_screen.dart` | [ ] | [ ] |
| Delete Store Confirmation Dialog | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Logout Confirmation Dialog | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Appearance Modal Bottom Sheet | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Language Modal Bottom Sheet | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Currency Modal Bottom Sheet | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Tax Rate Dialog | `lib/screens/settings/settings_screen.dart` | [ ] | [ ] |
| Scanned Product Bottom Sheet | `lib/screens/scan/scan_screen.dart` | [ ] | [ ] |
| Manual Barcode Search Sheet | `lib/screens/scan/scan_screen.dart` | [ ] | [ ] |
| Add / Edit Product Modal Sheet | `lib/screens/inventory/inventory_screen.dart` | [ ] | [ ] |
| Add Credit Record Sheet | `lib/screens/credit/credit_screen.dart` | [ ] | [ ] |
| Order Details Modal Sheet | `lib/screens/orders/orders_screen.dart` | [ ] | [ ] |

---

## 5. Snackbars, Empty & Error States

| State / Feedback | Scope | Light OK | Dark OK |
| :--- | :--- | :---: | :---: |
| App Snackbars (Success, Error, Info) | Global (`AppSnackbar` / ScaffoldMessenger) | [ ] | [ ] |
| Empty Cart State | `lib/screens/cart/cart_screen.dart` | [ ] | [ ] |
| Empty Notifications State | `lib/screens/notifications/notifications_screen.dart` | [ ] | [ ] |
| Empty Inventory / Search State | `lib/screens/inventory/inventory_screen.dart`, `home_screen.dart` | [ ] | [ ] |
| Empty Orders State | `lib/screens/orders/orders_screen.dart` | [ ] | [ ] |
| Empty Credit State | `lib/screens/credit/credit_screen.dart` | [ ] | [ ] |
| Loading Indicators | Global (`LoadingIndicator` / CircularProgressIndicator) | [ ] | [ ] |
| Error States & Firestore fallbacks | Global (Auth, scan, inventory, profile) | [ ] | [ ] |

---

## 6. Files with Hardcoded Colors to Eliminate

| File Path | Original Status | Replaced with Theme? |
| :--- | :--- | :---: |
| `lib/core/widgets/primary_button.dart` | Hardcoded Color(0xFF2D5E4A) | [ ] |
| `lib/screens/auth/auth_widgets.dart` | Hardcoded kAuth* colors | [ ] |
| `lib/screens/auth/forgot_password_screen.dart` | Hardcoded Color(0xFFE4EFE7), Color(0xFFEAEEDF), Colors.white | [ ] |
| `lib/screens/auth/reset_password_screen.dart` | Hardcoded kAuthCream | [ ] |
| `lib/screens/auth/signup_screen.dart` | Hardcoded Colors.white | [ ] |
| `lib/screens/cart/cart_screen.dart` | Hardcoded Divider color, Colors.black, icons | [ ] |
| `lib/screens/cart/checkout_screen.dart` | Hardcoded text styles, colors | [ ] |
| `lib/screens/credit/credit_screen.dart` | Hardcoded text styles, colors | [ ] |
| `lib/screens/dashboard/dashboard_screen.dart` | Hardcoded text styles | [ ] |
| `lib/screens/dashboard/dashboard_section.dart` | Hardcoded text styles | [ ] |
| `lib/screens/home/home_screen.dart` | Hardcoded text styles, Colors.transparent | [ ] |
| `lib/screens/home/product_detail_screen.dart` | Hardcoded text styles, borders, colors | [ ] |
| `lib/screens/inventory/inventory_screen.dart` | Hardcoded text styles, chip colors | [ ] |
| `lib/screens/notifications/notifications_screen.dart` | Hardcoded text styles | [ ] |
| `lib/screens/orders/orders_screen.dart` | Hardcoded text styles | [ ] |
| `lib/screens/profile/edit_profile_screen.dart` | Hardcoded text styles, colors | [ ] |
| `lib/screens/scan/scan_screen.dart` | Hardcoded Colors.black overlays, text styles | [ ] |
| `lib/screens/settings/settings_screen.dart` | Hardcoded text styles, sheet colors | [ ] |
| `lib/theme/app_theme.dart` | Legacy theme definitions | [ ] |

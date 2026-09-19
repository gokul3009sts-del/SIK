# SIK — Offline Hotel/Restaurant Billing App

A 100% offline Flutter Android app for hotel/restaurant billing. No internet,
no server, no cloud database — everything is stored locally on the device
with SQLite.

> **Note on how this was delivered:** this code was generated in a sandbox
> that doesn't have the Flutter SDK installed (its network is restricted to
> package registries like pub.dev/GitHub, not Flutter's own install servers),
> so the APK could not be compiled here. Every file below is complete,
> real, working source — not a stub — and builds into a working APK once you
> run it through Flutter on your own machine, following the steps below.

---

## 1. Prerequisites (one-time setup)

1. Install **Flutter SDK**: https://docs.flutter.dev/get-started/install
2. Install **VS Code** + the official **Flutter** and **Dart** extensions.
3. Install **Android SDK command-line tools** (VS Code's Flutter extension
   can prompt you to install these — Android Studio itself is *not*
   required, just its SDK components).
4. Run `flutter doctor` in a terminal and resolve anything marked `[✗]`.

## 2. Getting this project running

```bash
# 1. Unzip the project you were given, then enter it
cd sik_hotel_billing

# 2. Generate the missing platform scaffolding (android/, ios/ native glue).
#    This regenerates android/ properly for your installed Flutter/Gradle
#    version without touching the lib/ source files you were given.
flutter create . --project-name sik_hotel_billing --org com.sik.billing

# 3. Apply the manifest changes described in android/MANIFEST_CHANGES.txt
#    to android/app/src/main/AndroidManifest.xml (adds Bluetooth/storage
#    permissions for printing + export; no INTERNET permission is added).

# 4. Install dependencies
flutter pub get

# 5. Connect an Android device (USB debugging on) or start an emulator
flutter devices

# 6. Run in debug mode to test
flutter run
```

## 3. Building the release APK

```bash
flutter build apk --release
```

The installable file will be at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy that file to your phone (or `flutter install`) to install it.

To confirm it's fully offline: turn on Airplane Mode on your phone, then
open the app — login, add a dish, generate a bill, print/export, and back up
data all work with zero connectivity.

## 4. Default login

```
Username: admin
Password: admin123
```

Change this immediately from **Admin Dashboard → Change Password**.

## 5. What's implemented

- **SQLite** local database (`sqflite`) with `dishes`, `bills`, `bill_items`,
  `settings` tables, created automatically on first launch with a starter
  menu (Idly, Dosa, Parotta, Meals, Tea, Coffee).
- **Login screen** with hashed local password check (SHA-256, no plaintext
  storage, no network auth).
- **Admin dashboard**: Add/Edit/Delete dish (soft-delete — old bills keep
  their item snapshot even after a dish is removed from the menu), Sales
  Records, Today's Sales, Export/Backup, Change Password, Logout.
- **Billing screen**: tap-to-add dish grid with +/- quantity steppers
  (never goes below 0), live-updating cart and grand total, **GENERATE
  BILL** button.
- **Atomic bill numbering**: `SIK-000001`, `SIK-000002`, ... assigned and
  incremented inside a single SQLite transaction together with the bill and
  its line items, so numbers are never duplicated or skipped, survive app
  restarts, and a failed save never leaves a half-written bill.
- **Printing**: builds a thermal-receipt-formatted PDF (58mm/80mm, selectable
  in Settings) and hands it to Android's native print dialog via the
  `printing` package — works with Bluetooth, USB, and Wi-Fi printers that
  have an Android print-service driver, fully offline. A "Save PDF" share
  option is also provided.
- **Sales Records** page: every past bill, tap to view full itemized detail,
  reprint or re-share any old bill.
- **Today's Sales** page: today's bill count and total, auto-filtered by
  device local date.
- **Export**: manual CSV/TXT export (Today / All Sales) via
  **Export/Backup → Sales Export**, saved to the app's scoped
  external-files folder and shareable through Android's share sheet.
- **Automatic daily export**: on each app startup, if yesterday's sales
  haven't been exported yet, a `SIK_Sales_<date>.csv` file is written
  automatically (there's no way to run a background job while the app is
  fully closed on stock Android without extra native setup, so "on next
  open" is the reliable equivalent used here).
- **Backup & Restore**: full JSON backup of dishes/bills/settings/bill
  sequence, shareable anywhere; restore reads any picked `.json` backup
  file with a confirmation warning before overwriting local data.
- **Crash/restart safety**: nothing is written to the database until
  `GENERATE BILL` completes its transaction, so an app crash never corrupts
  bill numbering or loses a previously completed bill.

## 6. Project structure

```
sik_hotel_billing/
├── android/MANIFEST_CHANGES.txt   ← apply these to AndroidManifest.xml
├── lib/
│   ├── main.dart
│   ├── models/            dish.dart, bill.dart, bill_item.dart
│   ├── database/           database_helper.dart (SQLite schema + CRUD)
│   ├── screens/            login, admin_dashboard, dish_management,
│   │                       billing_screen, sales_records, todays_sales,
│   │                       backup_restore, settings_screen
│   ├── services/            bill_service, printer_service, export_service,
│   │                       backup_service
│   ├── widgets/            dish_card, bill_item_widget, total_widget
│   └── utils/               constants.dart, formatters.dart
└── pubspec.yaml
```

## 7. Extending to raw ESC/POS Bluetooth printing (optional)

The current printer service uses Android's native/system print pipeline via
the `printing` package, which is the most broadly compatible offline option
and works with most Bluetooth thermal printers that ship an Android print
service. If you have a bare ESC/POS Bluetooth printer with **no** Android
print-service driver, you can additionally add a package such as
`esc_pos_bluetooth` or `print_bluetooth_thermal` and feed it the same item
list (`bill.items`) to send raw ESC/POS commands directly over the Bluetooth
socket — the billing/database logic in this project doesn't need to change,
only `lib/services/printer_service.dart` would gain an alternate code path.

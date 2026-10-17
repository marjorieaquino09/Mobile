// Migrates legacy top-level `inventory/{id}` and user-owned `products/{id}`
// documents into `users/{uid}/inventory/{productId}`.
//
// Usage (dry run — default):
//   dart run tool/migrate_inventory_to_user.dart --dry-run
//
// Apply changes (requires Firebase Admin credentials — run from trusted env):
//   dart run tool/migrate_inventory_to_user.dart --apply
//
// This script uses the Flutter app's Firebase options only when run inside
// the project with `flutter pub get`. For production migration, prefer the
// Firebase Admin SDK or Firestore export/import with a one-off Cloud Function.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:sari_app/firebase_options.dart';

Future<void> main(List<String> args) async {
  final dryRun = !args.contains('--apply');
  if (dryRun) {
    stdout.writeln('DRY RUN — no documents will be written.\n');
  } else {
    stdout.writeln(
        'APPLY mode — documents will be copied to users/{uid}/inventory.\n');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;
  final inventorySnap = await db.collection('inventory').get();
  final productsSnap = await db.collection('products').get();

  var wouldWrite = 0;
  var skippedNoUser = 0;
  var skippedEmptyName = 0;

  Future<void> considerDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String source,
  }) async {
    final data = doc.data();
    final uid = (data['userId'] ?? '').toString().trim();
    if (uid.isEmpty) {
      skippedNoUser++;
      stdout.writeln('[skip no userId] $source/${doc.id}');
      return;
    }

    final name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      skippedEmptyName++;
      return;
    }

    final barcode = (data['barcode'] ?? doc.id).toString().trim();
    final targetId = barcode.isNotEmpty
        ? barcode.replaceAll('/', '_')
        : doc.id.replaceAll('/', '_');

    final targetPath = 'users/$uid/inventory/$targetId';
    wouldWrite++;
    stdout.writeln(
      dryRun
          ? '[would copy] $source/${doc.id} → $targetPath'
          : '[copy] $source/${doc.id} → $targetPath',
    );

    if (!dryRun) {
      final payload = Map<String, dynamic>.from(data)
        ..['barcode'] = barcode.isNotEmpty ? barcode : targetId
        ..['migratedFrom'] = source
        ..['migratedAt'] = FieldValue.serverTimestamp();
      await db.doc(targetPath).set(payload, SetOptions(merge: true));
    }
  }

  for (final doc in inventorySnap.docs) {
    await considerDoc(doc, source: 'inventory');
  }

  for (final doc in productsSnap.docs) {
    final data = doc.data();
    final uid = (data['userId'] ?? '').toString().trim();
    // Catalog entries without userId stay in products (read-only catalog).
    if (uid.isEmpty) continue;
    await considerDoc(doc, source: 'products');
  }

  stdout.writeln('\nSummary:');
  stdout.writeln('  would write / wrote: $wouldWrite');
  stdout.writeln('  skipped (no userId): $skippedNoUser');
  stdout.writeln('  skipped (empty name): $skippedEmptyName');
  if (dryRun) {
    stdout.writeln('\nRe-run with --apply to perform the migration.');
  }
}

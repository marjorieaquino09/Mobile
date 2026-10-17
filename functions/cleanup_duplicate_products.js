// One-time products catalog cleanup. Dry-run is the default.
//
//   node functions/cleanup_duplicate_products.js
//   node functions/cleanup_duplicate_products.js --apply --confirm-project=sari-89290 --confirm-deletes=1672 --confirm-reference-updates=24
//
// Uses Application Default Credentials. Before deleting, it scans every
// Firestore collection/subcollection, repoints recognized product references,
// and refuses to apply if a possible reference is ambiguous.

const fs = require('node:fs');
const path = require('node:path');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const apply = process.argv.includes('--apply');
const confirmArg = process.argv.find((arg) =>
  arg.startsWith('--confirm-project='),
);
const confirmedProject = confirmArg?.split('=')[1];
const confirmedDeletes = Number(
  process.argv
    .find((arg) => arg.startsWith('--confirm-deletes='))
    ?.split('=')[1],
);
const confirmedReferenceUpdates = Number(
  process.argv
    .find((arg) => arg.startsWith('--confirm-reference-updates='))
    ?.split('=')[1],
);
const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '.firebaserc'), 'utf8'),
);
const projectId = process.env.FIREBASE_PROJECT_ID || config.projects?.default;

if (!projectId) {
  throw new Error('Set FIREBASE_PROJECT_ID or configure .firebaserc first.');
}
if (apply && confirmedProject !== projectId) {
  throw new Error(
    `Apply refused. Confirm the target explicitly with --confirm-project=${projectId}.`,
  );
}

const app = initializeApp({
  credential: applicationDefault(),
  projectId,
});
const db = getFirestore(app);

function productGroupKey(doc) {
  const data = doc.data();
  const barcode = String(data.barcode ?? '').trim().toLowerCase();
  if (barcode) return `barcode:${barcode}`;

  const name = String(data.name ?? '').trim().toLowerCase();
  if (!name) return `unidentified:${doc.id}`;
  return [
    'fallback',
    name,
    String(data.size ?? '').trim().toLowerCase(),
    String(data.category ?? '').trim().toLowerCase(),
  ].join('|');
}

function completeness(doc) {
  const data = doc.data();
  return [
    'name',
    'size',
    'category',
    'barcode',
    'price',
    'stock',
    'imageUrl',
  ].filter((field) => {
    const value = data[field];
    return value !== null && value !== undefined && String(value).trim() !== '';
  }).length;
}

function chooseKeeper(docs) {
  return [...docs].sort((a, b) => {
    const completenessDifference = completeness(b) - completeness(a);
    if (completenessDifference !== 0) return completenessDifference;
    const createdDifference =
      a.createTime.toMillis() - b.createTime.toMillis();
    return createdDifference || a.id.localeCompare(b.id);
  })[0];
}

const referenceFields = new Set([
  'productId',
  'product_id',
  'productRefId',
  'productDocId',
  'catalogProductId',
]);
const productArrayFields = new Set(['productIds', 'product_ids']);
const itemArrayFields = new Set(['items', 'cartItems', 'cart_items']);
const ambiguousReferences = [];

function rewriteReferences(value, docPath, fieldPath, productContext = false) {
  if (Array.isArray(value)) {
    let changed = false;
    const next = value.map((entry, index) => {
      const result = rewriteReferences(
        entry,
        docPath,
        `${fieldPath}[${index}]`,
        productContext,
      );
      changed ||= result.changed;
      return result.value;
    });
    return { value: changed ? next : value, changed };
  }
  if (
    value === null ||
    typeof value !== 'object' ||
    (Object.getPrototypeOf(value) !== Object.prototype &&
      Object.getPrototypeOf(value) !== null)
  ) {
    return { value, changed: false };
  }

  let changed = false;
  const next = { ...value };
  for (const [key, child] of Object.entries(value)) {
    const childPath = fieldPath ? `${fieldPath}.${key}` : key;
    const isReference =
      referenceFields.has(key) ||
      (productContext && (key === 'id' || key === 'barcode'));
    if (typeof child === 'string' && obsoleteIds.has(child)) {
      if (isReference) {
        next[key] = obsoleteIds.get(child);
        changed = true;
      } else {
        ambiguousReferences.push(`${docPath}:${childPath}=${child}`);
      }
      continue;
    }
    if (Array.isArray(child) && productArrayFields.has(key)) {
      const rewritten = child.map((id) => {
        if (typeof id !== 'string' || !obsoleteIds.has(id)) return id;
        changed = true;
        return obsoleteIds.get(id);
      });
      next[key] = rewritten;
      continue;
    }
    const nestedProductContext =
      productContext || itemArrayFields.has(key) || productArrayFields.has(key);
    const result = rewriteReferences(
      child,
      docPath,
      childPath,
      nestedProductContext,
    );
    if (result.changed) {
      next[key] = result.value;
      changed = true;
    }
  }
  return { value: changed ? next : value, changed };
}

const obsoleteIds = new Map();

async function scanCollection(collection, onDocument) {
  const snapshot = await collection.get();
  for (const doc of snapshot.docs) {
    await onDocument(doc);
    const subcollections = await doc.ref.listCollections();
    for (const subcollection of subcollections) {
      await scanCollection(subcollection, onDocument);
    }
  }
}

async function commitBatches(entries, commitEntry, label) {
  for (let start = 0; start < entries.length; start += 500) {
    const batch = db.batch();
    for (const entry of entries.slice(start, start + 500)) {
      commitEntry(batch, entry);
    }
    await batch.commit();
    console.log(`Committed ${Math.min(start + 500, entries.length)} ${label}.`);
  }
}

async function main() {
  console.log(
    `${apply ? 'APPLY' : 'DRY RUN'} — project=${projectId}; ` +
      `${apply ? 'Firestore will be modified only after the reference scan.' : 'no writes or deletes will occur.'}`,
  );

  const productSnapshot = await db.collection('products').get();
  const groups = new Map();
  for (const doc of productSnapshot.docs) {
    const key = productGroupKey(doc);
    const group = groups.get(key) || [];
    group.push(doc);
    groups.set(key, group);
  }

  const deletions = [];
  let duplicateGroups = 0;
  for (const [key, docs] of groups) {
    if (docs.length < 2) continue;
    duplicateGroups++;
    const keeper = chooseKeeper(docs);
    console.log(
      `Group ${key}: keep products/${keeper.id}; delete ` +
        docs
          .filter((doc) => doc.id !== keeper.id)
          .map((doc) => `products/${doc.id}`)
          .join(', '),
    );
    for (const doc of docs) {
      if (doc.id === keeper.id) continue;
      deletions.push(doc.ref);
      obsoleteIds.set(doc.id, keeper.id);
    }
  }

  const referenceUpdates = [];
  if (obsoleteIds.size > 0) {
    const rootCollections = await db.listCollections();
    for (const collection of rootCollections) {
      if (collection.id === 'products') continue;
      await scanCollection(collection, async (doc) => {
        const isInventoryDocument =
          collection.id === 'inventory' ||
          doc.ref.path.includes('/inventory/');
        const result = rewriteReferences(
          doc.data(),
          doc.ref.path,
          '',
          isInventoryDocument,
        );
        if (result.changed) {
          const protectedProfile =
            ['users', 'stores', 'profiles'].includes(doc.ref.parent.path);
          if (protectedProfile) {
            ambiguousReferences.push(
              `${doc.ref.path}: product reference is in protected profile data`,
            );
          } else {
            referenceUpdates.push({ ref: doc.ref, data: result.value });
          }
        }
      });
    }
  }

  console.log('\nSummary:');
  console.log(`  product documents read: ${productSnapshot.size}`);
  console.log(`  identity groups found: ${groups.size}`);
  console.log(`  duplicate groups found: ${duplicateGroups}`);
  console.log(`  documents to keep: ${groups.size}`);
  console.log(`  duplicate documents to delete: ${deletions.length}`);
  console.log(`  recognized references to repoint: ${referenceUpdates.length}`);
  console.log(`  ambiguous possible references: ${ambiguousReferences.length}`);

  for (const update of referenceUpdates) {
    console.log(`  [would repoint product references] ${update.ref.path}`);
  }
  for (const reference of ambiguousReferences) {
    console.log(`  [manual review required] ${reference}`);
  }

  if (!apply) {
    console.log('\nDry run only. No Firestore documents were changed.');
    console.log(
      `After reviewing this output, apply with --apply --confirm-project=${projectId}.`,
    );
    return;
  }

  if (ambiguousReferences.length > 0) {
    throw new Error(
      'Refusing to delete products while possible unrecognized references remain.',
    );
  }
  if (
    confirmedDeletes !== deletions.length ||
    confirmedReferenceUpdates !== referenceUpdates.length
  ) {
    throw new Error(
      'Refusing to apply: live delete/reference counts differ from the reviewed dry run.',
    );
  }

  await commitBatches(
    referenceUpdates,
    (batch, entry) => batch.set(entry.ref, entry.data),
    'reference updates',
  );
  await commitBatches(
    deletions,
    (batch, ref) => batch.delete(ref),
    'product deletions',
  );
  console.log(
    `Cleanup complete: kept ${groups.size} documents and deleted ${deletions.length}.`,
  );
}

main().catch((error) => {
  console.error('Product cleanup failed:', error);
  process.exitCode = 1;
});

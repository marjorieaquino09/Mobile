import 'package:flutter_test/flutter_test.dart';
import 'package:sari_app/models/product.dart';
import 'package:sari_app/services/product_repository.dart';

Product product({
  required String id,
  required String name,
  String barcode = '',
  String size = '',
  String category = 'Snacks',
  String catalogProductId = '',
  double price = 0,
  int stock = 0,
  bool hidden = false,
}) {
  return Product(
    id: id,
    name: name,
    size: size,
    category: category,
    sku: barcode,
    price: price,
    stock: stock,
    imageUrl: '',
    barcode: barcode,
    catalogProductId: catalogProductId,
    hidden: hidden,
  );
}

void main() {
  test("catalog values are overlaid by the user's product fields", () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(
          id: 'catalog-1',
          name: 'Catalog Name',
          barcode: '1001',
          price: 10,
          stock: 40,
        ),
      ],
      inventory: [
        product(
          id: 'catalog-1',
          name: 'My Name',
          barcode: '1001',
          catalogProductId: 'catalog-1',
          price: 12,
          stock: 3,
        ),
      ],
    );

    expect(merged, hasLength(1));
    expect(merged.single.name, 'My Name');
    expect(merged.single.price, 12);
    expect(merged.single.stock, 3);
    expect(merged.single.isCatalogOnly, isFalse);
  });

  test('hidden catalog overlay is omitted without leaking duplicate docs', () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(
          id: 'catalog-1',
          name: 'Catalog Name',
          barcode: '1001',
          price: 10,
          stock: 40,
        ),
      ],
      inventory: [
        product(
          id: 'catalog-1',
          name: 'Catalog Name',
          barcode: '1001',
          catalogProductId: 'catalog-1',
          hidden: true,
        ),
        product(
          id: '1001',
          name: 'Legacy duplicate',
          barcode: '1001',
        ),
      ],
    );

    expect(merged, isEmpty);
  });

  test('user-only products remain custom and catalog IDs are canonical', () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(id: 'catalog-1', name: 'Catalog Name', barcode: '1001'),
      ],
      inventory: [
        product(id: 'custom-1', name: 'Custom Name', barcode: '2002'),
      ],
    );

    expect(merged.map((entry) => entry.id), ['catalog-1', 'custom-1']);
    expect(merged.last.isCustom, isTrue);
    expect(
      ProductRepository.inventoryDocId(
        barcode: '1001',
        catalogProductId: 'catalog-1',
      ),
      '1001',
    );
  });

  test(
      'duplicate inventory rows with the same barcode do not create a second product',
      () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(
          id: 'catalog-1',
          name: 'Catalog Name',
          barcode: '1001',
          price: 10,
          stock: 40,
        ),
      ],
      inventory: [
        product(
          id: 'legacy-duplicate',
          name: 'Legacy Duplicate',
          barcode: '1001',
          price: 13,
          stock: 2,
        ),
        product(
          id: 'catalog-1',
          name: 'Updated Product',
          barcode: '1001',
          catalogProductId: 'catalog-1',
          price: 12,
          stock: 3,
        ),
      ],
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, 'catalog-1');
    expect(merged.single.name, 'Updated Product');
    expect(merged.single.stock, 3);
  });

  test('same name with distinct barcodes remains distinct', () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(
          id: 'catalog-2',
          name: '  Same Product! ',
          barcode: '2002',
        ),
        product(
          id: 'catalog-1',
          name: 'same product',
          barcode: '1001',
        ),
      ],
      inventory: [
        product(
          id: 'catalog-1',
          name: 'Same Product',
          barcode: '1001',
          catalogProductId: 'catalog-1',
          stock: 8,
        ),
      ],
    );

    expect(merged, hasLength(2));
    expect(
      merged.map((entry) => entry.id),
      unorderedEquals(['catalog-1', 'catalog-2']),
    );
  });

  test('fallback identity includes size', () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: [
        product(
          id: 'plain-1',
          name: 'Ajinomoto Umami Seasoning',
          size: '50g',
        ),
        product(
          id: 'plain-2',
          name: ' ajinomoto umami seasoning ',
          size: '100g',
        ),
        product(
          id: 'plain-3',
          name: 'Ajinomoto Umami Seasoning',
          size: '50g',
          category: 'Spices',
        ),
        product(
          id: 'plain-4',
          name: 'AJINOMOTO UMAMI SEASONING',
          size: '50g',
        ),
      ],
      inventory: const [],
    );

    expect(
      merged.map((entry) => entry.id),
      unorderedEquals(['plain-1', 'plain-2']),
    );
  });

  test('barcode document id takes precedence and fallback id is a slug', () {
    expect(
      ProductRepository.inventoryDocId(
        barcode: ' 12/34 ',
        catalogProductId: 'catalog-id',
        name: 'Product Name',
      ),
      '12_34',
    );
    expect(
      ProductRepository.inventoryDocId(
        barcode: '',
        name: ' Ajinomoto Seasoning ',
        size: '50g',
      ),
      'ajinomoto-seasoning-50g',
    );
  });

  test('products without barcode use normalized name and size', () {
    final merged = ProductRepository.mergeCatalogAndInventory(
      catalog: const [],
      inventory: [
        product(
          id: 'legacy-a',
          name: 'Product Name',
          size: '50g',
          category: 'Condiments',
        ),
        product(
          id: 'legacy-b',
          name: ' product   name ',
          size: '50g',
          category: 'condiments',
        ),
        product(
          id: 'legacy-c',
          name: 'Product Name',
          size: '100g',
          category: 'Condiments',
        ),
      ],
    );

    expect(merged, hasLength(2));
    expect(
      merged.map((entry) => ProductRepository.productKey(entry)).toSet(),
      {
        'name:product name|size:50g',
        'name:product name|size:100g',
      },
    );
  });

  test('missing barcode stays empty so fallback identity is used', () {
    final product = Product.fromFirestore('legacy-id', {
      'name': 'Product Name',
      'size': '50g',
    });

    expect(product.barcode, isEmpty);
    expect(ProductRepository.productKey(product), 'name:product name|size:50g');
  });
}

import '../../models/pos_models.dart';
import 'api_client.dart';

/// Read access to the store catalog (`GET /products`). The POS only needs to
/// list active products to sell; the admin web owns create/update/delete.
class ProductsApi {
  ProductsApi(this._client);

  final ApiClient _client;

  Future<List<Product>> list() async {
    final data = await _client.get('/products', query: {'limit': '200'});
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map(_toProduct).toList();
  }

  Product _toProduct(Map<String, dynamic> json) => Product(
    id: (json['id'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    sku: (json['sku'] ?? '') as String,
    category: (json['category'] ?? '') as String,
    price: (json['price'] as num?)?.toInt() ?? 0,
    cost: (json['cost'] as num?)?.toInt() ?? 0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    status: (json['status'] == 'inactive')
        ? ProductStatus.inactive
        : ProductStatus.active,
    description: '',
    imageUrl: (json['imageUrl'] ?? '') as String,
  );
}

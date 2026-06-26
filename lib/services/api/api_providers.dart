import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'api_client.dart';
import 'auth_api.dart';
import 'cash_movements_api.dart';
import 'config_api.dart';
import 'products_api.dart';
import 'self_orders_api.dart';
import 'shifts_api.dart';
import 'tables_api.dart';
import 'token_store.dart';
import 'transactions_api.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Shared HTTP client. Tests override this provider with a fake transport.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokens: ref.read(tokenStoreProvider),
  ),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(apiClientProvider), ref.read(tokenStoreProvider)),
);

final productsApiProvider = Provider<ProductsApi>(
  (ref) => ProductsApi(ref.read(apiClientProvider)),
);

final tablesApiProvider = Provider<TablesApi>(
  (ref) => TablesApi(ref.read(apiClientProvider)),
);

final shiftsApiProvider = Provider<ShiftsApi>(
  (ref) => ShiftsApi(ref.read(apiClientProvider)),
);

final transactionsApiProvider = Provider<TransactionsApi>(
  (ref) => TransactionsApi(ref.read(apiClientProvider)),
);

final configApiProvider = Provider<ConfigApi>(
  (ref) => ConfigApi(ref.read(apiClientProvider)),
);

final cashMovementsApiProvider = Provider<CashMovementsApi>(
  (ref) => CashMovementsApi(ref.read(apiClientProvider)),
);

final selfOrdersApiProvider = Provider<SelfOrdersApi>(
  (ref) => SelfOrdersApi(ref.read(apiClientProvider)),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/supervisor_approval_dialog.dart';
import '../app_controller.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _ProductToolbar(
                  categories: state.categories,
                  selectedCategory: state.selectedCategory,
                  search: state.productSearch,
                  onCategoryChanged: controller.setCategory,
                  onSearchChanged: controller.setProductSearch,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _ProductGrid(
                    products: state.visibleProducts,
                    onAdd: controller.addProduct,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 390,
            child: _CartPanel(
              cart: state.cart,
              tables: state.tables,
              selectedOrderType: state.selectedOrderType,
              customerName: state.customerName,
              tableLabel: state.tableLabel,
              subtotal: state.subtotal,
              discount: state.discount,
              tax: state.tax,
              serviceLine: state.serviceLine,
              total: state.total,
              totalItems: state.totalItems,
              onOrderTypeChanged: controller.setOrderType,
              onCustomerNameChanged: controller.setCustomerName,
              onTableChanged: controller.setTableLabel,
              onIncrement: (item) =>
                  controller.updateQuantity(item.product.id, item.quantity + 1),
              onDecrement: (item) =>
                  controller.updateQuantity(item.product.id, item.quantity - 1),
              onRemove: (item) => controller.removeItem(item.product.id),
              onNote: (item) => _showNoteDialog(context, ref, item),
              onDiscount: () => _showDiscountDialog(
                context,
                ref,
                state.discount,
                state.subtotal,
              ),
              onClear: controller.clearCart,
              onCheckout: state.cart.isEmpty
                  ? null
                  : () => controller.navigate(AppScreen.checkout),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoteDialog(
    BuildContext context,
    WidgetRef ref,
    CartItem item,
  ) async {
    final noteController = TextEditingController(text: item.note);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Catatan item: ${item.product.name}'),
          content: TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Catatan',
              hintText: 'mis. kurangi gula, tanpa es',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(appControllerProvider.notifier)
                    .setItemNote(item.product.id, noteController.text);
                Navigator.pop(context);
              },
              child: const Text('Simpan catatan'),
            ),
          ],
        );
      },
    );
    // Not disposed: avoids racing the dialog's exit animation (GC'd instead).
  }

  Future<void> _showDiscountDialog(
    BuildContext context,
    WidgetRef ref,
    int discount,
    int subtotal,
  ) async {
    final discountController = TextEditingController(text: discount.toString());
    final cap = (subtotal * maxDiscountPercentWithoutApproval / 100).floor();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Terapkan diskon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: discountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nominal diskon',
                  prefixIcon: Icon(Icons.sell_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Diskon di atas $maxDiscountPercentWithoutApproval% '
                '(${formatIDR(cap)}) butuh persetujuan supervisor.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final value = int.tryParse(discountController.text) ?? 0;
                final controller = ref.read(appControllerProvider.notifier);
                if (value > cap) {
                  final approver = await showSupervisorApprovalDialog(
                    context,
                    title: 'Persetujuan Supervisor',
                    message:
                        'Diskon ${formatIDR(value)} melebihi plafon '
                        '${formatIDR(cap)} ($maxDiscountPercentWithoutApproval%). '
                        'Diperlukan persetujuan supervisor.',
                  );
                  if (approver == null) {
                    return;
                  }
                  controller.setDiscount(
                    value,
                    supervisorApproved: true,
                    approvedBy: approver,
                  );
                } else {
                  controller.setDiscount(value);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Terapkan'),
            ),
          ],
        );
      },
    );
    // Not disposed: avoids racing the dialog's exit animation (GC'd instead).
  }
}

class _ProductToolbar extends StatelessWidget {
  const _ProductToolbar({
    required this.categories,
    required this.selectedCategory,
    required this.search,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  final List<String> categories;
  final String selectedCategory;
  final String search;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Cari menu atau SKU',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Filter'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                final selected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(category),
                    onSelected: (_) => onCategoryChanged(category),
                    selectedColor: AppColors.primarySoft,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.onAdd});

  final List<Product> products;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SectionCard(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Menu tidak ditemukan',
          message: 'Coba kategori atau kata kunci lain.',
        ),
      );
    }

    return GridView.builder(
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 270,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(product: product, onAdd: () => onAdd(product));
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final initials = product.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1))
        .join();
    final lowStock = product.stock < 10;

    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _categorySoftColor(product.category),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(
                      product.imageUrl.isEmpty
                          ? defaultProductImageUrl
                          : product.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      // Offline/gagal muat → tampilkan inisial sebagai fallback.
                      errorBuilder: (_, __, ___) => _InitialsAvatar(
                        initials: initials,
                        category: product.category,
                      ),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : _InitialsAvatar(
                              initials: initials,
                              category: product.category,
                            ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                product.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatIDR(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'sisa ${product.stock}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: lowStock
                          ? AppColors.warning
                          : AppColors.mutedForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fallback avatar (inisial nama di kotak warna kategori) saat gambar produk
/// belum/gagal dimuat.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.category});

  final String initials;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      color: _categorySoftColor(category),
      child: Text(
        initials,
        style: TextStyle(
          color: _categoryColor(category),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case 'Rice Bowls':
    case 'Main Dishes':
    case 'Noodles':
      return AppColors.accentWarm;
    case 'Desserts':
    case 'Bakery':
      return AppColors.warning;
    case 'Beverages':
      return AppColors.info;
    default:
      return AppColors.primary;
  }
}

Color _categorySoftColor(String category) {
  switch (category) {
    case 'Rice Bowls':
    case 'Main Dishes':
    case 'Noodles':
      return AppColors.accentWarmSoft;
    case 'Desserts':
    case 'Bakery':
      return AppColors.warningSoft;
    case 'Beverages':
      return AppColors.infoSoft;
    default:
      return AppColors.primarySoft;
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.tables,
    required this.selectedOrderType,
    required this.customerName,
    required this.tableLabel,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.serviceLine,
    required this.total,
    required this.totalItems,
    required this.onOrderTypeChanged,
    required this.onCustomerNameChanged,
    required this.onTableChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onNote,
    required this.onDiscount,
    required this.onClear,
    required this.onCheckout,
  });

  final List<CartItem> cart;
  final List<DiningTable> tables;
  final OrderType selectedOrderType;
  final String customerName;
  final String tableLabel;
  final int subtotal;
  final int discount;
  final int tax;
  final int serviceLine;
  final int total;
  final int totalItems;
  final ValueChanged<OrderType> onOrderTypeChanged;
  final ValueChanged<String> onCustomerNameChanged;
  final ValueChanged<String> onTableChanged;
  final ValueChanged<CartItem> onIncrement;
  final ValueChanged<CartItem> onDecrement;
  final ValueChanged<CartItem> onRemove;
  final ValueChanged<CartItem> onNote;
  final VoidCallback onDiscount;
  final VoidCallback onClear;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Pesanan Saat Ini',
      subtitle: '${selectedOrderType.label} - $totalItems item',
      actions: TextButton(
        onPressed: cart.isEmpty ? null : onClear,
        child: const Text('Kosongkan'),
      ),
      padding: EdgeInsets.zero,
      expandChild: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _OrderContextPanel(
              tables: tables,
              selectedOrderType: selectedOrderType,
              customerName: customerName,
              tableLabel: tableLabel,
              onOrderTypeChanged: onOrderTypeChanged,
              onCustomerNameChanged: onCustomerNameChanged,
              onTableChanged: onTableChanged,
            ),
          ),
          const Divider(height: 18),
          Expanded(
            child: cart.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Pesanan kosong',
                    message: 'Ketuk kartu menu untuk menambah item.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return _CartItemRow(
                        item: item,
                        onIncrement: () => onIncrement(item),
                        onDecrement: () => onDecrement(item),
                        onRemove: () => onRemove(item),
                        onNote: () => onNote(item),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemCount: cart.length,
                  ),
          ),
          if (cart.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  KeyValueRow(label: 'Subtotal', value: formatIDR(subtotal)),
                  KeyValueRow(
                    label: 'Diskon',
                    value: discount == 0
                        ? formatIDR(0)
                        : '-${formatIDR(discount)}',
                    valueColor: discount == 0 ? null : AppColors.success,
                  ),
                  if (serviceLine > 0)
                    KeyValueRow(label: 'Layanan', value: formatIDR(serviceLine)),
                  if (tax > 0)
                    KeyValueRow(label: 'PPN', value: formatIDR(tax)),
                  const Divider(),
                  KeyValueRow(
                    label: 'Total',
                    value: formatIDR(total),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDiscount,
                          icon: const Icon(Icons.sell_rounded),
                          label: const Text('Diskon'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onCheckout,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Bayar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderContextPanel extends StatelessWidget {
  const _OrderContextPanel({
    required this.tables,
    required this.selectedOrderType,
    required this.customerName,
    required this.tableLabel,
    required this.onOrderTypeChanged,
    required this.onCustomerNameChanged,
    required this.onTableChanged,
  });

  final List<DiningTable> tables;
  final OrderType selectedOrderType;
  final String customerName;
  final String tableLabel;
  final ValueChanged<OrderType> onOrderTypeChanged;
  final ValueChanged<String> onCustomerNameChanged;
  final ValueChanged<String> onTableChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OrderType.values.map((type) {
            final selected = selectedOrderType == type;
            return ChoiceChip(
              selected: selected,
              label: Text(type.label),
              onSelected: (_) => onOrderTypeChanged(type),
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.foreground,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        if (selectedOrderType == OrderType.dineIn)
          (tables.isEmpty
              ? TextFormField(
                  initialValue: tableLabel,
                  onChanged: onTableChanged,
                  decoration: const InputDecoration(
                    labelText: 'Meja',
                    prefixIcon: Icon(Icons.table_restaurant_rounded),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: tables.any((t) => t.name == tableLabel)
                      ? tableLabel
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Meja',
                    prefixIcon: Icon(Icons.table_restaurant_rounded),
                  ),
                  items: tables
                      .map(
                        (table) => DropdownMenuItem(
                          value: table.name,
                          child: Text('${table.area} - ${table.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onTableChanged(value);
                    }
                  },
                ))
        else
          TextFormField(
            initialValue: customerName,
            onChanged: onCustomerNameChanged,
            decoration: InputDecoration(
              labelText: selectedOrderType == OrderType.delivery
                  ? 'Ref antar / pelanggan'
                  : 'Nama pelanggan (opsional)',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onNote,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.quantity} x ${formatIDR(item.product.price)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (item.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accentWarm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatIDR(item.lineTotal),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TouchIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Kurangi jumlah',
              onPressed: onDecrement,
            ),
            SizedBox(
              width: 42,
              child: Center(
                child: Text(
                  '${item.quantity}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            TouchIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Tambah jumlah',
              onPressed: onIncrement,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onNote,
              icon: const Icon(Icons.sticky_note_2_rounded),
              label: const Text('Catatan'),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.destructive,
              tooltip: 'Hapus item',
            ),
          ],
        ),
      ],
    );
  }
}

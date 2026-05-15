// lib/features/products/presentation/pages/products_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/products_bloc.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductsBloc()..add(const ProductsLoadRequested()),
      child: const _ProductsView(),
    );
  }
}

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<ProductsBloc>().add(const ProductsLoadMore());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductsBloc, ProductsState>(
      listenWhen: (p, c) => p.actionStatus != c.actionStatus,
      listener: (ctx, state) {
        if (state.actionStatus == ProductsActionStatus.success) {
          _showSnack(ctx, 'Thành công!', AppColors.success);
        } else if (state.actionStatus == ProductsActionStatus.failure) {
          _showSnack(
            ctx,
            state.actionError ?? 'Có lỗi xảy ra',
            AppColors.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _TopBar(searchCtrl: _searchCtrl),
            Expanded(
              child: BlocBuilder<ProductsBloc, ProductsState>(
                builder: (ctx, state) {
                  if (state.status == ProductsStatus.initial ||
                      state.status == ProductsStatus.loading) {
                    return const _LoadingBody();
                  }
                  if (state.status == ProductsStatus.failure) {
                    return _ErrorBody(
                      message: state.errorMessage,
                      onRetry: () => ctx.read<ProductsBloc>().add(
                        const ProductsLoadRequested(refresh: true),
                      ),
                    );
                  }
                  if (state.products.isEmpty) {
                    return _EmptyBody(query: state.query);
                  }
                  return _ProductList(
                    products: state.products,
                    hasMore: state.hasMore,
                    isLoadingMore: state.status == ProductsStatus.loadingMore,
                    scrollCtrl: _scrollCtrl,
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _AddFab(),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.searchCtrl});
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sản phẩm',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    BlocBuilder<ProductsBloc, ProductsState>(
                      buildWhen: (p, c) => p.total != c.total,
                      builder: (_, state) => Text(
                        '${state.total} sản phẩm',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              BlocBuilder<ProductsBloc, ProductsState>(
                buildWhen: (p, c) => p.status != c.status,
                builder: (ctx, state) => IconButton(
                  onPressed: state.status == ProductsStatus.loading
                      ? null
                      : () => ctx.read<ProductsBloc>().add(
                          const ProductsLoadRequested(refresh: true),
                        ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Tải lại',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search field
          BlocBuilder<ProductsBloc, ProductsState>(
            buildWhen: (p, c) => p.query != c.query,
            builder: (ctx, state) {
              return TextField(
                controller: searchCtrl,
                onChanged: (v) =>
                    ctx.read<ProductsBloc>().add(ProductsSearchChanged(v)),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên sản phẩm...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: state.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            searchCtrl.clear();
                            ctx.read<ProductsBloc>().add(
                              const ProductsSearchChanged(''),
                            );
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Product List ─────────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.hasMore,
    required this.isLoadingMore,
    required this.scrollCtrl,
  });

  final List<ProductEntity> products;
  final bool hasMore;
  final bool isLoadingMore;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => context.read<ProductsBloc>().add(
        const ProductsLoadRequested(refresh: true),
      ),
      child: isWide ? _gridView(context) : _listView(context),
    );
  }

  Widget _listView(BuildContext context) {
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: products.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == products.length) {
          return const _LoadMoreIndicator();
        }
        return _ProductListTile(product: products[i]);
      },
    );
  }

  Widget _gridView(BuildContext context) {
    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: products.length + (hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == products.length) {
          return const _LoadMoreIndicator();
        }
        return _ProductGridCard(product: products[i]);
      },
    );
  }
}

// ─── List tile (mobile) ───────────────────────────────────────────────────────

class _ProductListTile extends StatelessWidget {
  const _ProductListTile({required this.product});
  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openEdit(context, product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Ảnh
              _ProductThumbnail(imageUrl: product.image, size: 52),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(product.price),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (product.unit != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.unit!,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconActionBtn(
                    icon: Icons.edit_rounded,
                    color: AppColors.primary,
                    onTap: () => _openEdit(context, product),
                  ),
                  const SizedBox(width: 8),
                  _IconActionBtn(
                    icon: Icons.delete_rounded,
                    color: AppColors.error,
                    onTap: () => _confirmDelete(context, product),
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

// ─── Grid card (tablet/desktop) ───────────────────────────────────────────────

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({required this.product});
  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEdit(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: _ProductThumbnail(
                  imageUrl: product.image,
                  size: double.infinity,
                  isSquare: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CardBtn(
                          icon: Icons.edit_rounded,
                          label: 'Sửa',
                          color: AppColors.primary,
                          onTap: () => _openEdit(context, product),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _CardBtn(
                        icon: Icons.delete_rounded,
                        label: '',
                        color: AppColors.error,
                        onTap: () => _confirmDelete(context, product),
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product thumbnail ────────────────────────────────────────────────────────

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({
    this.imageUrl,
    required this.size,
    this.isSquare = false,
  });
  final String? imageUrl;
  final double size;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final fullUrl = imageUrl!.startsWith('http')
          ? imageUrl!
          : '${ApiConstants.baseUrl.replaceAll('/api', '')}$imageUrl';

      return Image.network(
        fullUrl,
        width: isSquare ? double.infinity : size,
        height: isSquare ? double.infinity : size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _Placeholder(size: size, isSquare: isSquare),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : _Placeholder(size: size, isSquare: isSquare),
      );
    }
    return _Placeholder(size: size, isSquare: isSquare);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, this.isSquare = false});
  final double size;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isSquare ? double.infinity : size,
      height: isSquare ? double.infinity : size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: isSquare ? null : BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.textHint,
        size: 28,
      ),
    );
  }
}

// ─── Empty / Error / Loading bodies ──────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Không thể tải sản phẩm',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
                ? 'Không tìm thấy "$query"'
                : 'Chưa có sản phẩm nào',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          if (query.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm sản phẩm đầu tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// ─── FAB ──────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openCreate(context),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Thêm sản phẩm',
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      ),
      elevation: 2,
    );
  }
}

// ─── Helpers to open dialogs ──────────────────────────────────────────────────

void _openCreate(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: const _ProductFormDialog(),
    ),
  );
}

void _openEdit(BuildContext context, ProductEntity product) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: _ProductFormDialog(product: product),
    ),
  );
}

void _confirmDelete(BuildContext context, ProductEntity product) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: _DeleteConfirmDialog(product: product),
    ),
  );
}

// ─── Product Form Dialog ──────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});
  final ProductEntity? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  File? _pickedImage;
  bool _clearImage = false;
  String? _existingImageUrl;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toInt().toString();
      _unitCtrl.text = p.unit ?? '';
      _existingImageUrl = p.image;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _clearImage = false;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final price = double.parse(_priceCtrl.text.replaceAll('.', ''));
    final unit = _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim();

    final bloc = context.read<ProductsBloc>();

    if (isEdit) {
      bloc.add(
        ProductUpdateRequested(
          id: widget.product!.id,
          name: name,
          price: price,
          unit: unit,
          imagePath: _pickedImage?.path,
          clearImage: _clearImage,
        ),
      );
    } else {
      bloc.add(
        ProductCreateRequested(
          name: name,
          price: price,
          unit: unit,
          imagePath: _pickedImage?.path,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm',
                        style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Image picker
                  _ImagePicker(
                    pickedImage: _pickedImage,
                    existingUrl: _clearImage ? null : _existingImageUrl,
                    onPick: _pickImage,
                    onClear: () => setState(() {
                      _pickedImage = null;
                      _clearImage = true;
                    }),
                  ),

                  const SizedBox(height: 20),

                  // Tên
                  _FieldLabel('Tên sản phẩm *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'VD: Mắm cá linh',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập tên sản phẩm';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Giá
                  _FieldLabel('Giá bán (₫) *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandSeparatorFormatter(),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'VD: 120.000',
                      prefixText: '₫ ',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập giá';
                      final parsed =
                          double.tryParse(v.replaceAll('.', '')) ?? -1;
                      if (parsed < 0) return 'Giá không hợp lệ';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Đơn vị
                  _FieldLabel('Đơn vị (tùy chọn)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                      hintText: 'VD: hộp, chai, kg...',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Text(
                            'Hủy',
                            style: GoogleFonts.dmSans(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: BlocBuilder<ProductsBloc, ProductsState>(
                          buildWhen: (p, c) => p.actionStatus != c.actionStatus,
                          builder: (_, state) => ElevatedButton(
                            onPressed:
                                state.actionStatus ==
                                    ProductsActionStatus.loading
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                state.actionStatus ==
                                    ProductsActionStatus.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Image Picker widget ──────────────────────────────────────────────────────

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({
    required this.pickedImage,
    required this.existingUrl,
    required this.onPick,
    required this.onClear,
  });

  final File? pickedImage;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        pickedImage != null || (existingUrl != null && existingUrl!.isNotEmpty);

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Image preview
            if (pickedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.file(
                  pickedImage!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (existingUrl != null && existingUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.network(
                  existingUrl!.startsWith('http')
                      ? existingUrl!
                      : '${ApiConstants.baseUrl.replaceAll('/api', '')}$existingUrl',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _pickerPlaceholder(),
                ),
              )
            else
              _pickerPlaceholder(),

            // Overlay
            if (!hasImage)
              const SizedBox.shrink()
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: Colors.black.withValues(alpha: 0.25),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đổi ảnh',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Clear button
            if (hasImage)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pickerPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.add_photo_alternate_rounded,
            size: 36,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn ảnh sản phẩm',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'JPG, PNG, WebP • Tối đa 2MB',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─── Delete Confirm Dialog ────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.product});
  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_rounded,
                size: 30,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Xóa sản phẩm?',
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn sắp xóa "${product.name}". Hành động này không thể hoàn tác.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Text(
                      'Hủy',
                      style: GoogleFonts.dmSans(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlocBuilder<ProductsBloc, ProductsState>(
                    buildWhen: (p, c) => p.actionStatus != c.actionStatus,
                    builder: (ctx, state) => ElevatedButton(
                      onPressed:
                          state.actionStatus == ProductsActionStatus.loading
                          ? null
                          : () {
                              ctx.read<ProductsBloc>().add(
                                ProductDeleteRequested(product.id),
                              );
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Xóa',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  const _IconActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _CardBtn extends StatelessWidget {
  const _CardBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Thousand separator formatter ─────────────────────────────────────────────

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatPrice(double price) {
  final n = price.toInt();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$bufđ';
}

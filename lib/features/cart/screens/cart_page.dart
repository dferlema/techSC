import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/cart/services/cart_service.dart';
import 'package:techsc/features/cart/screens/payment_webview_page.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/l10n/app_localizations.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  String _view = 'cart'; // 'cart' o 'payment'
  String _selectedPaymentMethod = 'efectivo';
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: Text(
          _view == 'cart' ? l10n.cartTitle : 'Seleccionar Pago',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_view == 'payment') {
              setState(() => _view = 'cart');
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          _view == 'cart'
              ? _buildCartView(cart, l10n)
              : _buildPaymentView(cart, l10n),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Procesando pedido...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartView(CartService cart, AppLocalizations l10n) {
    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.divider,
            ),
            const SizedBox(height: 16),
            Text(
              'Tu carrito está vacío', // Usando fallback directo para evitar error de l10n
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.image != null && item.image!.isNotEmpty
                            ? Image.network(
                                item.image!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image,
                                  size: 40,
                                  color: AppColors.divider,
                                ),
                              )
                            : Icon(
                                Icons.image,
                                size: 40,
                                color: AppColors.divider,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => cart.decreaseQuantity(item.id),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: AppColors.success,
                            ),
                            onPressed: () => cart.increaseQuantity(item.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Estimado:',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '\$${cart.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => setState(() => _view = 'payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'GENERAR PEDIDO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentView(CartService cart, AppLocalizations l10n) {
    final double subtotal = cart.total;
    final double discount =
        (_selectedPaymentMethod == 'efectivo' ||
            _selectedPaymentMethod == 'transferencia')
        ? subtotal * 0.05
        : 0.0;
    final double finalTotal = subtotal - discount;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '¿Cómo deseas pagar?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los pagos en efectivo o transferencia tienen un 5% de descuento especial.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _buildPaymentOption(
                id: 'payphone',
                title: 'Tarjeta (Payphone)',
                subtitle: 'Visa, Mastercard, American Express',
                icon: Icons.credit_card,
                color: AppColors.primaryBlue,
              ),
              _buildPaymentOption(
                id: 'transferencia',
                title: 'Transferencia Bancaria',
                subtitle: 'Ahorra 5% en tu compra',
                icon: Icons.account_balance,
                color: AppColors.roleTechnician,
                isDiscount: true,
              ),
              _buildPaymentOption(
                id: 'efectivo',
                title: 'Efectivo',
                subtitle: 'Pago contra entrega - Ahorra 5%',
                icon: Icons.payments,
                color: AppColors.success,
                isDiscount: true,
              ),
            ],
          ),
        ),
        _buildPaymentSummary(subtotal, discount, finalTotal, cart),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isDiscount = false,
  }) {
    final bool isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isDiscount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '-5%',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(
    double subtotal,
    double discount,
    double total,
    CartService cart,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _summaryRow('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
          if (discount > 0)
            _summaryRow(
              'Descuento (5%):',
              '-\$${discount.toStringAsFixed(2)}',
              isDiscount: true,
            ),
          const Divider(height: 24),
          _summaryRow(
            'Total a Pagar:',
            '\$${total.toStringAsFixed(2)}',
            isTotal: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _processOrder(cart),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selectedPaymentMethod == 'payphone'
                    ? 'IR A PAGAR'
                    : 'CONFIRMAR PEDIDO',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? AppColors.success : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 22 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? AppColors.primaryBlue
                  : (isDiscount ? AppColors.success : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processOrder(CartService cart) async {
    if (cart.total <= 0) {
      _showError('El total del pedido debe ser mayor a 0');
      return;
    }

    try {
      final double amountToPay = cart.total;
      setState(() => _isLoading = true);

      final orderId = await cart.createOrder(
        paymentMethod: _selectedPaymentMethod,
      );

      if (_selectedPaymentMethod == 'payphone') {
        final payphone = ref.read(payphoneServiceProvider);
        if (payphone == null) throw Exception('Payphone no configurado');

        final checkoutUrl = await payphone.createPaymentRequest(
          amount: amountToPay,
          clientTransactionId: orderId.length > 15
              ? orderId.substring(orderId.length - 15)
              : orderId,
          reference: 'Pedido #$orderId',
          responseUrl: 'https://pay.payphonetodoesposible.com/confirm',
          cancellationUrl: 'https://pay.payphonetodoesposible.com/cancel',
        );

        if (checkoutUrl == null)
          throw Exception('No se generó el link de pago');

        setState(() => _isLoading = false);
        if (!mounted) return;
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewPage(
              url: checkoutUrl,
              successUrl: 'https://pay.payphonetodoesposible.com/confirm',
              cancelUrl: 'https://pay.payphonetodoesposible.com/cancel',
            ),
          ),
        );

        if (result == 'success') {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({'paymentStatus': 'paid', 'isPaid': true});
          if (!mounted) return;
          _showFinalSuccess(orderId);
        } else {
          _showError('Pago no completado. Tu pedido quedó como PENDIENTE.');
          Navigator.pushReplacementNamed(context, '/my-orders');
        }
      } else {
        setState(() => _isLoading = false);
        _showFinalSuccess(orderId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error: $e');
      }
    }
  }

  void _showFinalSuccess(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 60),
            const SizedBox(height: 16),
            const Text('¡Pedido Exitoso!', textAlign: TextAlign.center),
          ],
        ),
        content: Text(
          'Su pedido #$orderId ha sido registrado correctamente.\n\n${_selectedPaymentMethod == 'payphone' ? 'El pago se procesó exitosamente.' : 'Por favor, siga las instrucciones de pago enviadas.'}',
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/my-orders');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'VER MIS PEDIDOS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

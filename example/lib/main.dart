import 'package:flutter/material.dart';

void main() => runApp(const CheckoutApp());

class CheckoutApp extends StatelessWidget {
  const CheckoutApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Checkout',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const CheckoutScreen(),
      );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _items = {'Notebook': 12, 'Pen set': 8};
  final _promo = TextEditingController();
  bool _paid = false;

  int get _total =>
      _items.values.fold(0, (a, b) => a + b) - (_promo.text == 'SAVE5' ? 5 : 0);

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in _items.entries) Text('${e.key}: \$${e.value}'),
              const SizedBox(height: 16),
              TextField(
                controller: _promo,
                decoration: const InputDecoration(labelText: 'Promo code'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Total: \$$_total'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() => _paid = true),
                child: const Text('Pay'),
              ),
              if (_paid) const Text('Order confirmed'),
            ],
          ),
        ),
      );
}

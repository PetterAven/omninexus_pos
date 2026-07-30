import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../domain/entities/product.dart';
import '../../providers/product_controller.dart';
import '../../screens/barcode_scanner_screen.dart';

/// Punto de entrada usado por inventory_screen.dart
/// (`showAddProductDialog(context, ref)` / `showAddProductDialog(context, ref, productToEdit: product)`).
/// Es solo un envoltorio delgado sobre showDialog(): todo el guardado
/// (validación, llamada a ProductController, SnackBar de resultado)
/// vive dentro de AddProductDialog, que es autosuficiente.
Future<void> showAddProductDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? productToEdit,
}) {
  return showDialog(
    context: context,
    builder: (_) => AddProductDialog(productToEdit: productToEdit),
  );
}

/// Diálogo para crear o editar un producto.
/// Soporta productos por pieza y productos a granel (isWeighted) con unidad de medida.
/// Al escanear o teclear el código de barras, intenta autocompletar el
/// nombre consultando Open Food Facts (base internacional de códigos
/// de barras de productos, gratuita y sin API key).
class AddProductDialog extends ConsumerStatefulWidget {
  final Product? productToEdit;

  const AddProductDialog({super.key, this.productToEdit});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;

  bool _isWeighted = false;
  String _unit = 'kg';
  bool _isSaving = false;
  bool _isLookingUp = false;

  final List<String> _availableUnits = ['kg', 'g', 'l', 'ml', 'm', 'pza'];

  bool get isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _codeController = TextEditingController(text: p?.code ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stock.toString() : '0',
    );

    if (p != null) {
      _isWeighted = p.isWeighted;
      _unit = _availableUnits.contains(p.unit) ? p.unit : 'kg';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty) return;
    if (!mounted) return;
    setState(() => _codeController.text = scanned);
    await _lookupProductInfo(scanned);
  }

  /// Consulta Open Food Facts con el código de barras para intentar
  /// autocompletar el nombre. No bloquea el flujo si falla o no hay
  /// internet: el usuario siempre puede capturar el producto a mano.
  Future<void> _lookupProductInfo(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    setState(() => _isLookingUp = true);
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,brands',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final product = data['product'] as Map<String, dynamic>?;

        if (data['status'] == 1 && product != null) {
          final name = (product['product_name'] as String?)?.trim();
          final brand = (product['brands'] as String?)?.split(',').first.trim();

          if (name != null && name.isNotEmpty) {
            final autoName = (brand != null &&
                    brand.isNotEmpty &&
                    !name.toLowerCase().contains(brand.toLowerCase()))
                ? '$brand $name'
                : name;
            setState(() => _nameController.text = autoName);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Producto encontrado en la base internacional.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró este código en la base internacional. Captúralo a mano.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (_) {
      // Sin internet o falló la consulta: no interrumpe el alta manual.
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final stock = double.tryParse(_stockController.text) ?? 0.0;
    final finalUnit = _isWeighted ? _unit : 'pza';

    final product = Product(
      code: code,
      name: name,
      price: price,
      stock: stock,
      isWeighted: _isWeighted,
      unit: finalUnit,
    );

    final controller = ref.read(productControllerProvider.notifier);

    try {
      if (isEditing) {
        await controller.updateProduct(product);
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado.'), backgroundColor: Colors.green),
        );
      } else {
        final result = await controller.addProduct(product);
        if (!mounted) return;

        switch (result) {
          case ProductSaveResult.duplicateCode:
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Ese código ya existe. Usa "Editar" en el producto o elige otro código.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          case ProductSaveResult.success:
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto creado con éxito.'), backgroundColor: Colors.green),
            );
            break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing ? 'Editar Producto' : 'Nuevo Producto',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  // Deshabilitado en edición para no alterar la clave primaria.
                  enabled: !isEditing,
                  decoration: InputDecoration(
                    labelText: 'Código de Barras / SKU',
                    prefixIcon: const Icon(Icons.qr_code),
                    border: const OutlineInputBorder(),
                    suffixIcon: isEditing
                        ? null
                        : _isLookingUp
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    tooltip: 'Buscar info del producto',
                                    onPressed: () => _lookupProductInfo(_codeController.text),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    tooltip: 'Escanear código',
                                    onPressed: _scanBarcode,
                                  ),
                                ],
                              ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un código válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre del producto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Precio (\$)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final p = double.tryParse(value ?? '');
                          if (p == null || p <= 0) {
                            return 'Precio inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _isWeighted ? 'Stock ($_unit)' : 'Stock (piezas)',
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final s = double.tryParse(value ?? '');
                          if (s == null || s < 0) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: SwitchListTile(
                    title: const Text(
                      'Se vende a granel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _isWeighted
                          ? 'Se solicitará peso/volumen al vender'
                          : 'Se vende por piezas unitarias',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isWeighted,
                    onChanged: (bool value) {
                      setState(() => _isWeighted = value);
                    },
                  ),
                ),
                if (_isWeighted) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de Medida',
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                    ),
                    items: _availableUnits.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _unit = newValue);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProduct,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Guardar Cambios' : 'Crear Producto'),
        ),
      ],
    );
  }
}
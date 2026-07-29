import 'package:flutter/material.dart';
import '../../../domain/entities/product.dart';

/// Para cada unidad "grande" configurada en un producto a granel, qué
/// sub-unidad se puede capturar directo de una báscula/medidor y el
/// factor para convertirla de vuelta a la unidad grande.
///
/// Ej.: un producto configurado en "kg" también acepta captura en "g"
/// (factor 1000): el cajero teclea literal lo que marca la báscula
/// (548) sin tener que dividir a mano.
const Map<String, ({String smallUnit, double factor})> _subUnitConversions = {
  'kg': (smallUnit: 'g', factor: 1000),
  'l': (smallUnit: 'ml', factor: 1000),
};

/// v1.1.0: se muestra cuando el cajero toca un producto con
/// `isWeighted == true` en la Terminal de Ventas, ANTES de llamar a
/// `CartController.addProduct(product, weight: ...)`.
///
/// Devuelve el peso/cantidad SIEMPRE en la unidad configurada del
/// producto (`product.unit`), sin importar en qué sub-unidad haya
/// capturado el cajero -- así CartController y el cálculo de subtotales
/// nunca necesitan saber nada de conversiones. Devuelve `null` si el
/// cajero cancela.
Future<double?> showWeightInputDialog(BuildContext context, Product product) async {
  final weightController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final conversion = _subUnitConversions[product.unit];
  String captureUnit = product.unit;

  return showDialog<double>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Venta a granel: ${product.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Precio por ${product.unit}: \$${product.price.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),

                  // Selector de sub-unidad, solo si el producto tiene una
                  // conversión conocida (kg↔g, l↔ml). Para 'pza', 'm', etc.
                  // no aplica y se captura directo en esa unidad.
                  if (conversion != null) ...[
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: product.unit,
                          label: Text(product.unit.toUpperCase()),
                        ),
                        ButtonSegment(
                          value: conversion.smallUnit,
                          label: Text(conversion.smallUnit.toUpperCase()),
                        ),
                      ],
                      selected: {captureUnit},
                      onSelectionChanged: (selection) {
                        setState(() => captureUnit = selection.first);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Cantidad / peso ($captureUnit)',
                      hintText: captureUnit == product.unit ? 'Ej. 1.450' : 'Ej. 548',
                      border: const OutlineInputBorder(),
                      suffixText: captureUnit,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Ingresa un peso válido mayor a 0';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final rawValue = double.parse(weightController.text);

                    // Si el cajero capturó en la sub-unidad (ej. gramos),
                    // se convierte a la unidad configurada del producto
                    // (ej. kg) antes de regresarlo.
                    final finalValue = captureUnit == product.unit
                        ? rawValue
                        : rawValue / conversion!.factor;

                    Navigator.pop(context, finalValue);
                  }
                },
                child: const Text('Agregar al Carrito'),
              ),
            ],
          );
        },
      );
    },
  );
}
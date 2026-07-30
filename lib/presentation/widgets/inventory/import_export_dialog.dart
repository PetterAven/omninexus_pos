import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../../../domain/entities/product.dart';
import '../../providers/product_controller.dart';

/// Diálogo interactivo para importar y exportar productos en formato Excel y CSV
void showImportExportDialog(
  BuildContext context,
  WidgetRef ref,
  List<Product> currentProducts,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.import_export, color: Color(0xFF2C3E50)),
          SizedBox(width: 10),
          Text('Gestión de Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.file_download, color: Colors.green),
            ),
            title: const Text('Exportar Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Guardar catálogo actual en formato Excel (.xlsx)'),
            onTap: () async {
              Navigator.pop(dialogContext);
              await _handleExport(context, currentProducts);
            },
          ),
          const Divider(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.file_upload, color: Colors.blue),
            ),
            title: const Text('Importar Productos', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Cargar catálogo masivo desde un archivo .xlsx o .csv'),
            onTap: () async {
              Navigator.pop(dialogContext);
              await _handleImport(context, ref);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Selector de archivos e importador masivo a la base de datos
Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true, // Requerido para leer bytes directamente en móviles
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    List<Product> newProducts = [];

    // Obtener bytes directamente o leer desde el path si existe
    Uint8List? bytes = pickedFile.bytes;
    if (bytes == null && pickedFile.path != null) {
      bytes = await File(pickedFile.path!).readAsBytes();
    }

    if (bytes == null) {
      throw Exception('No se pudieron obtener los datos del archivo.');
    }

    final extension = pickedFile.extension?.toLowerCase() ?? '';

    if (extension == 'csv') {
      final input = String.fromCharCodes(bytes);
      List<List<dynamic>> rows = const CsvToListConverter().convert(input);

      int startIndex = (rows.isNotEmpty && double.tryParse(rows[0][2].toString()) == null) ? 1 : 0;

      for (var i = startIndex; i < rows.length; i++) {
        var row = rows[i];
        if (row.length >= 4) {
          final isWeightedVal = row.length >= 5 &&
              (row[4].toString() == '1' || row[4].toString().toLowerCase() == 'true' || row[4].toString() == 'Sí');
          final unitVal = (row.length >= 6 && row[5].toString().trim().isNotEmpty)
              ? row[5].toString().trim()
              : 'pza';

          newProducts.add(Product(
            code: row[0].toString().trim(),
            name: row[1].toString().trim(),
            price: double.tryParse(row[2].toString()) ?? 0.0,
            stock: double.tryParse(row[3].toString()) ?? 0.0,
            isWeighted: isWeightedVal,
            unit: unitVal,
          ));
        }
      }
    } else if (extension == 'xlsx') {
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        for (var i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.length >= 4 && row[0]?.value != null && row[1]?.value != null) {
            final isWeightedVal = row.length >= 5 &&
                (row[4]?.value.toString() == '1' ||
                    row[4]?.value.toString().toLowerCase() == 'true' ||
                    row[4]?.value.toString() == 'Sí');
            final unitVal = (row.length >= 6 && (row[5]?.value?.toString().trim().isNotEmpty ?? false))
                ? row[5]!.value.toString().trim()
                : 'pza';

            newProducts.add(Product(
              code: row[0]!.value.toString().trim(),
              name: row[1]!.value.toString().trim(),
              price: double.tryParse(row[2]?.value.toString() ?? '0') ?? 0.0,
              stock: double.tryParse(row[3]?.value.toString() ?? '0') ?? 0.0,
              isWeighted: isWeightedVal,
              unit: unitVal,
            ));
          }
        }
      }
    }

    if (newProducts.isNotEmpty) {
      await ref.read(productControllerProvider.notifier).bulkImportProducts(newProducts);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Se importaron ${newProducts.length} productos correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se encontraron filas válidas en el archivo.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error al importar: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Genera un .xlsx real con soporte multiplataforma
Future<void> _handleExport(BuildContext context, List<Product> products) async {
  try {
    final excelFile = Excel.createExcel();
    final sheet = excelFile['Inventario'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#232D37'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    const headers = ['Código', 'Nombre', 'Precio', 'Stock', 'EsGranel', 'Unidad'];
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      final row = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(p.code);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(p.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(p.price);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(p.stock);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(p.isWeighted ? 'Sí' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(p.unit ?? '');
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 32);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 10);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);

    if (excelFile.sheets.containsKey('Sheet1')) {
      excelFile.delete('Sheet1');
    }
    excelFile.setDefaultSheet('Inventario');

    final List<int>? encodedBytes = excelFile.encode();
    if (encodedBytes == null) throw Exception('No se pudo generar el archivo Excel.');
    final Uint8List bytes = Uint8List.fromList(encodedBytes);

    final fileName = 'Inventario_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    if (Platform.isAndroid || Platform.isIOS) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo de inventario',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );
      if (outputPath == null) return;
    } else {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo de inventario',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (outputFile == null) return;
      await File(outputFile).writeAsBytes(bytes);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Inventario exportado correctamente.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error al exportar: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
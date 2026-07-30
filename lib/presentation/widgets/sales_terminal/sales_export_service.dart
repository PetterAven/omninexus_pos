import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import '../../../data/repositories/sales_repository.dart';
import '../../../domain/entities/sale.dart';

/// Exporta el corte de caja a un .xlsx con dos hojas organizadas y celdas con diseño profesional.
Future<void> exportSalesReport(BuildContext context, List<Sale> sales) async {
  if (sales.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay ventas que exportar todavía.'), backgroundColor: Colors.orange),
    );
    return;
  }

  try {
    final Map<String, _ProductSummary> summary = {};
    final List<_TicketRow> ticketRows = [];

    for (final sale in sales) {
      final details = await SalesRepository.instance.getSaleDetails(sale.id);
      for (final item in details) {
        final entry = summary.putIfAbsent(item.productCode, () => _ProductSummary(name: item.productName));
        entry.quantity += item.quantity.toDouble();
        entry.total += item.price * item.quantity.toDouble();

        ticketRows.add(_TicketRow(
          ticketId: sale.id,
          hora: sale.date.length >= 19 ? sale.date.substring(11, 19) : sale.date,
          productName: item.productName,
          quantity: item.quantity.toDouble(),
          price: item.price,
          subtotal: item.price * item.quantity.toDouble(),
        ));
      }
    }

    final excelFile = excel.Excel.createExcel();

    // Estilo de Encabezado: Azul Marino (#1F4E78) con texto blanco centrado
    final headerStyle = excel.CellStyle(
      bold: true,
      backgroundColorHex: excel.ExcelColor.fromHexString('#1F4E78'),
      fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    // Estilo de datos estándar
    final cellStyleData = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Left,
      verticalAlign: excel.VerticalAlign.Center,
    );

    // Estilo de datos numéricos
    final cellStyleNumeric = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Right,
      verticalAlign: excel.VerticalAlign.Center,
    );

    // --- Hoja "Resumen" ---
    final resumen = excelFile['Resumen'];
    const resumenHeaders = ['Producto', 'Cantidad Vendida', 'Total (\$)'];
    for (var col = 0; col < resumenHeaders.length; col++) {
      final cell = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = excel.TextCellValue(resumenHeaders[col]);
      cell.cellStyle = headerStyle;
    }

    var row = 1;
    double granTotal = 0;
    final sortedSummary = summary.values.toList()..sort((a, b) => b.quantity.compareTo(a.quantity));

    for (final item in sortedSummary) {
      final cellName = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cellName.value = excel.TextCellValue(item.name);
      cellName.cellStyle = cellStyleData;

      final cellQty = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      cellQty.value = excel.DoubleCellValue(item.quantity);
      cellQty.cellStyle = cellStyleNumeric;

      final cellTotal = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      cellTotal.value = excel.DoubleCellValue(item.total);
      cellTotal.cellStyle = cellStyleNumeric;

      granTotal += item.total;
      row++;
    }

    // Fila del Gran Total resaltada
    final totalHeaderStyle = excel.CellStyle(
      bold: true,
      backgroundColorHex: excel.ExcelColor.fromHexString('#E2EFDA'),
      fontColorHex: excel.ExcelColor.fromHexString('#276A3C'),
      horizontalAlign: excel.HorizontalAlign.Left,
    );
    final totalValueStyle = excel.CellStyle(
      bold: true,
      backgroundColorHex: excel.ExcelColor.fromHexString('#E2EFDA'),
      fontColorHex: excel.ExcelColor.fromHexString('#276A3C'),
      horizontalAlign: excel.HorizontalAlign.Right,
    );

    final totalCellLabel = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1));
    totalCellLabel.value = excel.TextCellValue('VENTAS ACUMULADAS');
    totalCellLabel.cellStyle = totalHeaderStyle;

    final totalCellVal = resumen.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1));
    totalCellVal.value = excel.DoubleCellValue(granTotal);
    totalCellVal.cellStyle = totalValueStyle;

    resumen.setColumnWidth(0, 35);
    resumen.setColumnWidth(1, 20);
    resumen.setColumnWidth(2, 18);

    // --- Hoja "Detalle por Ticket" ---
    final detalle = excelFile['Detalle por Ticket'];
    const detalleHeaders = ['Ticket', 'Hora', 'Producto', 'Cantidad', 'Precio Unitario', 'Subtotal'];
    for (var col = 0; col < detalleHeaders.length; col++) {
      final cell = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = excel.TextCellValue(detalleHeaders[col]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < ticketRows.length; i++) {
      final t = ticketRows[i];
      final r = i + 1;

      final c0 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
      c0.value = excel.TextCellValue('#${t.ticketId}');
      c0.cellStyle = cellStyleData;

      final c1 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r));
      c1.value = excel.TextCellValue(t.hora);
      c1.cellStyle = cellStyleData;

      final c2 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r));
      c2.value = excel.TextCellValue(t.productName);
      c2.cellStyle = cellStyleData;

      final c3 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
      c3.value = excel.DoubleCellValue(t.quantity);
      c3.cellStyle = cellStyleNumeric;

      final c4 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r));
      c4.value = excel.DoubleCellValue(t.price);
      c4.cellStyle = cellStyleNumeric;

      final c5 = detalle.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r));
      c5.value = excel.DoubleCellValue(t.subtotal);
      c5.cellStyle = cellStyleNumeric;
    }

    detalle.setColumnWidth(0, 12);
    detalle.setColumnWidth(1, 14);
    detalle.setColumnWidth(2, 35);
    detalle.setColumnWidth(3, 14);
    detalle.setColumnWidth(4, 18);
    detalle.setColumnWidth(5, 18);

    if (excelFile.sheets.containsKey('Sheet1')) {
      excelFile.delete('Sheet1');
    }
    excelFile.setDefaultSheet('Resumen');

    final List<int>? encodedBytes = excelFile.encode();
    if (encodedBytes == null) throw Exception('No se pudo generar el archivo Excel.');
    final Uint8List bytes = Uint8List.fromList(encodedBytes);

    final fileName = 'CorteDeCaja_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    if (Platform.isAndroid || Platform.isIOS) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar corte de caja',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );
      if (outputPath == null) return;
    } else {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar corte de caja',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (outputFile == null) return;
      await File(outputFile).writeAsBytes(bytes);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Corte de caja exportado correctamente.'), backgroundColor: Colors.green),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error al exportar: $e'), backgroundColor: Colors.red),
    );
  }
}

class _ProductSummary {
  final String name;
  double quantity = 0;
  double total = 0;
  _ProductSummary({required this.name});
}

class _TicketRow {
  final int ticketId;
  final String hora;
  final String productName;
  final double quantity;
  final double price;
  final double subtotal;
  _TicketRow({
    required this.ticketId,
    required this.hora,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });
}
/// Convierte un monto en pesos mexicanos a su representación en letras,
/// como se usa en tickets/comprobantes (ej. 142.50 -> "CIENTO CUARENTA
/// Y DOS PESOS 00/100 M.N."). Extraído de SalesTerminalScreen porque es
/// lógica pura, sin dependencia de UI, y antes vivía duplicada en tres
/// lugares del widget (ticket en pantalla, PDF térmico y mensaje de
/// Telegram) todos llamando al mismo método privado.
String totalEnLetras(double cantidad) {
  int entero = cantidad.floor();
  if (entero == 0) return "CERO PESOS 00/100 M.N.";

  const unidades = ["", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE"];
  const decenas = ["", "DIEZ", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA"];
  const especiales = ["ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE"];

  String letras = "";
  if (entero >= 100) {
    if (entero == 100) {
      letras += "CIEN ";
    } else if (entero < 200) {
      letras += "CIENTO ";
    }
    entero %= 100;
  }

  if (entero >= 11 && entero <= 19) {
    letras += "${especiales[entero - 11]} ";
  } else {
    int dec = (entero / 10).floor();
    int uni = entero % 10;
    if (dec > 0) {
      letras += decenas[dec];
      letras += uni > 0 ? " Y " : " ";
    }
    if (uni > 0) {
      letras += "${unidades[uni]} ";
    }
  }

  return "${letras.trim()} PESOS 00/100 M.N.";
}
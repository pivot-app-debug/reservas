/// Fuera del navegador (app Android) no hay nada que instalar.
enum PlataformaWeb { escritorio, android, ios }

PlataformaWeb plataformaWeb() => PlataformaWeb.escritorio;
bool esAppInstalada() => true;
bool navegadorCompatible() => true;
bool puedeInstalarDirecto() => false;
Future<bool> instalarDirecto() async => false;
bool recienInstalada() => false;
String direccionActual() => '';
void limpiarEnlace() {}

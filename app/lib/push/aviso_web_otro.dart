void mostrarAvisoWeb(String titulo, String cuerpo) {}

String permisoAvisosWeb() => 'granted';
Future<String> pedirPermisoAvisosWeb() async => 'granted';
bool esIosWeb() => false;
String navegadorWeb() => 'app';
bool esNavegadorInterno() => false;

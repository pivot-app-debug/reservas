import 'package:firebase_core/firebase_core.dart';

/// App web de Firebase (proyecto pivot-d65f4, Victor 2026-11-15). Estos
/// datos son públicos por diseño en cualquier web; no son secretos.
const firebaseWeb = FirebaseOptions(
  apiKey: 'AIzaSyB2k9hPFPmAMLVHvOnz13j5P9X6YJx0sQ4',
  authDomain: 'pivot-d65f4.firebaseapp.com',
  projectId: 'pivot-d65f4',
  storageBucket: 'pivot-d65f4.firebasestorage.app',
  messagingSenderId: '167871376984',
  appId: '1:167871376984:web:565066c2084cf2adeae42d',
  measurementId: 'G-HV92KBCHWL',
);

/// Clave pública de notificaciones web (Cloud Messaging → certificados push web).
const vapidWeb = 'BEQ0_z8TZ_KMdxrBQJquOEubmHF_R-yn-Uw-1vo0rUyMZqHa0iv_O4X-SetfCxef4NEBpG_Md0nLYpvT0ddzmTs';

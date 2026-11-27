// Configuración de Serevix.
// Rellena los dos valores con los de tu proyecto de Supabase (Project Settings › API).
// La "anon public key" es pública por diseño: lo que protege los datos de cada
// persona son las reglas de la base de datos (supabase/schema.sql).
// Si los dejas vacíos, la app funciona en "modo sin cuenta" y guarda todo en el móvil.
window.SEREVIX_CONFIG = {
  supabaseUrl: 'https://iwjeefkkomyrvlvmqrse.supabase.co',
  supabaseAnonKey: 'sb_publishable_bvqXrr0eF1FsYd5xqnQy9w_VDaWHGdd',
  stravaClientId: '', // opcional: el Client ID de tu app de Strava (es público)
  aiFunction: ''      // opcional: nombre de la función para calcular macros con IA (más adelante)
};

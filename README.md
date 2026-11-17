# MAKIPURA Box

Aplicación táctil infantil en Godot 4.7.2. Este repositorio es autocontenido: contiene `project.godot`, escenas, scripts, recursos y un instalador para Linux x86_64. La demo local funciona sin servidor, Docker ni navegador. El diseño parte de las [pantallas favoritas del proyecto Stitch](https://stitch.google.com/projects/10336029112284046600).

## Abrir

Lee [install.md](install.md) para instalar desde cero. Si ya tienes Godot 4.7.2:

```bash
godot --path .
```

La pantalla de entrada muestra emociones y permite abrir **Respirar**, **Baile**, **Moverme** con la ranita, **Juego**, **Mi rutina**, **Quiero decir**, **Pausa** y **Ayuda**. En modo demo, las elecciones se quedan en este equipo. Con `MAKIPURA_BOX_URL` se conecta al servidor local del piloto: recibe el inicio y control de sesión desde el panel del terapeuta y le envía las elecciones del niño.

Los eventos enviados tienen `schema_version: 1`, `session_id`, `event_id`, `timestamp_ms` y una acción. El Box conserva los eventos sin confirmar en `user://pending-events.json`, los reenvía tras reconectar o reiniciar y los borra al recibir `EVENT_ACK`. El servidor debe deduplicarlos por `event_id`. Las preferencias sensoriales de la sesión permiten apagar sonido, reducir animaciones y elegir dos ritmos de respiración.

## Pruebas del proyecto

```bash
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/outbox_smoke.gd
```

El proyecto es un piloto con contenido de demostración. El uso con personas requiere revisión clínica, pruebas en pantalla táctil real, modo kiosk del sistema y un entorno seguro para los datos. Las ilustraciones de ranita, koala y zorro provienen del proyecto Stitch; Lexend se distribuye bajo la licencia incluida en `assets/OFL-Lexend.txt`.

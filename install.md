# Instalar MAKIPURA Box

## Requisitos

Linux x86_64 con escritorio gráfico y pantalla táctil o mouse. El instalador necesita `bash`, `curl`, `unzip` y `sha256sum`, además de conexión a Internet para descargar Godot 4.7.2. También puedes proporcionar un ejecutable local con `GODOT_BIN=/ruta/a/Godot_v4.7.2-stable_linux.x86_64` para instalar sin descarga. No requiere Node, Docker ni privilegios de administrador.

## Instalación

```bash
git clone https://github.com/jpruizAntonIA/makipura-box-godot.git
cd makipura-box-godot
./installer.sh
~/.local/bin/makipura-box
```

El instalador copia el proyecto y el binario de Godot verificado en `~/.local/share/makipura-box`, crea `~/.local/bin/makipura-box` y una entrada de menú. La primera apertura inicia una sesión **demo local**. Tras instalar, puede funcionar sin Internet. La cola de eventos pendientes permanece en los datos de usuario de Godot.

Para cambiar las rutas, define `MAKIPURA_INSTALL_DIR`, `MAKIPURA_BIN_DIR` y `MAKIPURA_DESKTOP_DIR` al ejecutar el instalador. Ejecutarlo de nuevo actualiza la instalación. El repositorio original se puede borrar después de instalar.

## Conectar con el panel del terapeuta

Arranca el servidor local del piloto y abre el Box así:

```bash
MAKIPURA_BOX_URL='ws://IP_DEL_SERVIDOR:8765/ws/box?token=TOKEN_DEL_BOX' ~/.local/bin/makipura-box
```

La variable desactiva la demo y deja el Box esperando una sesión iniciada por el terapeuta. `IP_DEL_SERVIDOR` debe ser accesible desde el equipo del Box. El puerto 8765 del Compose de simulación escucha solo en localhost; para otro equipo hay que vincularlo a la LAN. No publiques ese puerto en Internet. Guarda el token con permisos de lectura solo para el usuario del Box.

## Comprobar y desinstalar

Desde el repositorio:

```bash
./installer.sh
~/.local/bin/makipura-box --headless --quit-after 2
```

Para desinstalar, borra `~/.local/share/makipura-box`, `~/.local/bin/makipura-box` y `~/.local/share/applications/makipura-box.desktop`. Los datos de usuario de Godot se guardan por separado; bórralos solo si ya no necesitas los eventos pendientes.

Este instalador cubre la app de escritorio. El arranque automático, el bloqueo kiosk, la configuración del monitor táctil y TLS/WSS requieren preparación en el mini-PC del Box antes de usarlo con personas.

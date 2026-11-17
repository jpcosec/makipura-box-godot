#!/usr/bin/env bash
set -euo pipefail

godot_version="4.7.2"
godot_name="Godot_v${godot_version}-stable_linux.x86_64"
archive_sha256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
archive_url="https://github.com/godotengine/godot-builds/releases/download/${godot_version}-stable/${godot_name}.zip"
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
install_dir="${MAKIPURA_INSTALL_DIR:-$data_home/makipura-box}"
bin_dir="${MAKIPURA_BIN_DIR:-$HOME/.local/bin}"
desktop_dir="${MAKIPURA_DESKTOP_DIR:-$data_home/applications}"

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "Este instalador admite Linux x86_64. Para otro sistema, abre project.godot en Godot ${godot_version}." >&2
  exit 1
fi
if [[ ! -f "$source_dir/project.godot" || ! -f "$source_dir/scenes/main.tscn" ]]; then
  echo "Faltan archivos del proyecto Godot. Ejecuta el instalador desde el repositorio completo." >&2
  exit 1
fi
if [[ "$(realpath -m "$install_dir")" == "$(realpath "$source_dir")" ]]; then
  echo "MAKIPURA_INSTALL_DIR debe ser distinto de la carpeta del repositorio." >&2
  exit 1
fi

mkdir -p "$(dirname "$install_dir")" "$bin_dir" "$desktop_dir"
stage_dir="$(mktemp -d "$(dirname "$install_dir")/.makipura-box.XXXXXX")"
archive_path=""
cleanup() {
  [[ -z "$archive_path" ]] || rm -f "$archive_path"
  [[ ! -d "$stage_dir" ]] || rm -rf "$stage_dir"
}
trap cleanup EXIT
mkdir -p "$stage_dir/project" "$stage_dir/godot"
cp "$source_dir/project.godot" "$stage_dir/project/"
cp -R "$source_dir/assets" "$source_dir/scenes" "$source_dir/scripts" "$stage_dir/project/"

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_source="$(command -v "$GODOT_BIN" || true)"
  if [[ -z "$godot_source" ]]; then
    echo "No encuentro GODOT_BIN=$GODOT_BIN" >&2
    exit 1
  fi
  if [[ "$("$godot_source" --version)" != ${godot_version}.* ]]; then
    echo "GODOT_BIN debe ser Godot ${godot_version}." >&2
    exit 1
  fi
  cp "$godot_source" "$stage_dir/godot/$godot_name"
else
  for program in curl unzip sha256sum; do
    if ! command -v "$program" >/dev/null 2>&1; then
      echo "Falta $program. Instálalo o define GODOT_BIN con Godot ${godot_version}." >&2
      exit 1
    fi
  done
  archive_path="$(mktemp "$stage_dir/godot.XXXXXX.zip")"
  echo "Descargando Godot ${godot_version} y verificando SHA-256..."
  curl -fL --silent --show-error "$archive_url" -o "$archive_path"
  printf '%s  %s\n' "$archive_sha256" "$archive_path" | sha256sum -c --status
  unzip -q "$archive_path" "$godot_name" -d "$stage_dir/godot"
  rm -f "$archive_path"
  archive_path=""
fi
chmod 755 "$stage_dir/godot/$godot_name"
cat > "$stage_dir/launch.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
app_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
exec "$app_dir/godot/Godot_v4.7.2-stable_linux.x86_64" --path "$app_dir/project" "$@"
EOF
chmod 755 "$stage_dir/launch.sh"
"$stage_dir/godot/$godot_name" --headless --editor --path "$stage_dir/project" --import

if [[ -e "$install_dir" ]]; then
  backup_dir="${install_dir}.previous"
  rm -rf "$backup_dir"
  mv "$install_dir" "$backup_dir"
fi
mv "$stage_dir" "$install_dir"
if [[ -n "${backup_dir:-}" ]]; then rm -rf "$backup_dir"; fi
ln -sfn "$install_dir/launch.sh" "$bin_dir/makipura-box"
cat > "$desktop_dir/makipura-box.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MAKIPURA Box
Comment=Experiencia táctil MAKIPURA
Exec="$bin_dir/makipura-box"
Icon=$install_dir/project/assets/icon-rabbit.svg
Terminal=false
Categories=Education;Game;
EOF
chmod 644 "$desktop_dir/makipura-box.desktop"
echo "MAKIPURA Box instalado en $install_dir"
echo "Ábrelo desde el menú de aplicaciones o ejecuta: $bin_dir/makipura-box"

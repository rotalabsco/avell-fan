#!/bin/bash
# Gera dist/avell-fan_<versão>_all.deb sem precisar de root.
# Uso: ./packaging/build-deb.sh     Instalar: sudo apt install ./dist/avell-fan_<versão>_all.deb
set -euo pipefail
umask 022
cd "$(dirname "$(readlink -f "$0")")/.."
VER=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' avell-fan)
[ -n "$VER" ] || { echo "VERSION não encontrada em avell-fan"; exit 1; }
R=$(mktemp -d)
trap 'rm -rf "$R"' EXIT

install -D -m 755 avell-fan "$R/usr/bin/avell-fan"
install -D -m 755 avell-fan-gui "$R/usr/bin/avell-fan-gui"
install -d "$R/usr/share/avell-fan/fonts" "$R/usr/share/avell-fan/temas"
install -m 644 fonts/* "$R/usr/share/avell-fan/fonts/"
install -m 644 temas/*.json "$R/usr/share/avell-fan/temas/"
install -m 644 avell-fan.svg "$R/usr/share/avell-fan/avell-fan.svg"
install -D -m 644 avell-fan.svg "$R/usr/share/icons/hicolor/scalable/apps/avell-fan.svg"
install -D -m 644 desktop/avell-fan.desktop "$R/usr/share/applications/avell-fan.desktop"
install -D -m 644 desktop/avell-fan-tray.desktop "$R/etc/xdg/autostart/avell-fan-tray.desktop"
install -d "$R/lib/systemd/system"
sed 's#/usr/local/bin/#/usr/bin/#g' avell-fan.service > "$R/lib/systemd/system/avell-fan.service"
install -d "$R/usr/lib/modules-load.d"
printf 'tuxedo_keyboard\nuniwill_wmi\ntuxedo_io\n' > "$R/usr/lib/modules-load.d/avell-fan.conf"

SRC="$R/usr/src/avell-fan-drivers-$VER"
mkdir -p "$SRC"
cp -r vendor/tuxedo-drivers/. "$SRC/"
sed "s/@VER@/$VER/g" packaging/dkms.conf.in > "$SRC/dkms.conf"

install -d "$R/usr/share/doc/avell-fan"
cp README.md docs/TECNICO.md docs/TEMA.md "$R/usr/share/doc/avell-fan/"
{ echo "Avell Fan $VER - https://github.com/rotalabsco/avell-fan"
  echo "Código: GPL-3.0-or-later. vendor/tuxedo-drivers: (c) TUXEDO Computers GmbH, GPL-2.0-or-later."
  echo "Fontes Bricolage Grotesque, Geist e Geist Mono: SIL Open Font License."
  echo; cat LICENSE; } > "$R/usr/share/doc/avell-fan/copyright"
find "$R" -name '*.orig' -o -name '__pycache__' | xargs rm -rf

install -d "$R/DEBIAN"
SIZE=$(du -sk "$R" | cut -f1)
sed -e "s/@VER@/$VER/g" -e "s/@SIZE@/$SIZE/" packaging/debian/control.in > "$R/DEBIAN/control"
for s in preinst postinst prerm postrm; do
  sed "s/@VER@/$VER/g" "packaging/debian/$s" > "$R/DEBIAN/$s"
  chmod 755 "$R/DEBIAN/$s"
done
echo /etc/xdg/autostart/avell-fan-tray.desktop > "$R/DEBIAN/conffiles"
find "$R" -type d -exec chmod 755 {} +
find "$R" -type f -exec chmod go-w {} +

mkdir -p dist
dpkg-deb --root-owner-group -Zxz --build "$R" "dist/avell-fan_${VER}_all.deb" >/dev/null
echo "dist/avell-fan_${VER}_all.deb"

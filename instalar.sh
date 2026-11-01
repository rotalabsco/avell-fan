#!/bin/bash
# Instala drivers (DKMS), serviço, interface gráfica e ícone da bandeja.
# Uso: sudo ./instalar.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Rode com sudo: sudo ./instalar.sh"; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"

PKG=avell-fan-drivers
VER=1.0
SRC=/usr/src/$PKG-$VER
SHARE=/usr/local/share/avell-fan

echo "==> Dependências"
apt-get install -y --no-install-recommends dkms "linux-headers-$(uname -r)" python3-gi gir1.2-gtk-3.0 >/dev/null
apt-get install -y --no-install-recommends gir1.2-xapp-1.0 >/dev/null 2>&1 \
  || apt-get install -y --no-install-recommends gir1.2-ayatanaappindicator3-0.1 >/dev/null 2>&1 \
  || echo "   (sem biblioteca de bandeja: a interface abre só como janela)"

echo "==> Drivers (DKMS: recompila sozinho a cada kernel novo)"
dkms remove -m $PKG -v $VER --all >/dev/null 2>&1 || true
rm -rf "$SRC"
cp -r vendor/tuxedo-drivers "$SRC"
cat > "$SRC/dkms.conf" <<CONF
PACKAGE_NAME="$PKG"
PACKAGE_VERSION="$VER"
AUTOINSTALL="yes"
MAKE[0]="make -C \${kernel_source_dir} M=\${dkms_tree}/$PKG/$VER/build modules"
CLEAN="make -C \${kernel_source_dir} M=\${dkms_tree}/$PKG/$VER/build clean"
BUILT_MODULE_NAME[0]="tuxedo_compatibility_check"; BUILT_MODULE_LOCATION[0]="src/tuxedo_compatibility_check/"; DEST_MODULE_LOCATION[0]="/updates/dkms"
BUILT_MODULE_NAME[1]="tuxedo_keyboard";            BUILT_MODULE_LOCATION[1]="src/";                             DEST_MODULE_LOCATION[1]="/updates/dkms"
BUILT_MODULE_NAME[2]="uniwill_wmi";                BUILT_MODULE_LOCATION[2]="src/";                             DEST_MODULE_LOCATION[2]="/updates/dkms"
BUILT_MODULE_NAME[3]="tuxedo_io";                  BUILT_MODULE_LOCATION[3]="src/tuxedo_io/";                   DEST_MODULE_LOCATION[3]="/updates/dkms"
CONF
dkms install -m $PKG -v $VER

echo "==> Carregar no boot"
printf 'tuxedo_keyboard\nuniwill_wmi\ntuxedo_io\n' > /etc/modules-load.d/avell-fan.conf
rmmod tuxedo_io uniwill_wmi tuxedo_keyboard tuxedo_compatibility_check 2>/dev/null || true
modprobe tuxedo_keyboard && modprobe uniwill_wmi && modprobe tuxedo_io

echo "==> Serviço"
install -m 755 avell-fan /usr/local/bin/avell-fan
install -m 644 avell-fan.service /etc/systemd/system/avell-fan.service
[ -f /etc/avell-fan.json ] || echo '{}' > /etc/avell-fan.json
systemctl daemon-reload
systemctl enable avell-fan
systemctl restart avell-fan

echo "==> Interface"
install -m 755 avell-fan-gui /usr/local/bin/avell-fan-gui
install -d "$SHARE/fonts"
install -m 644 fonts/* "$SHARE/fonts/"
install -m 644 avell-fan.svg "$SHARE/avell-fan.svg"
install -d "$SHARE/temas"
install -m 644 temas/*.json "$SHARE/temas/"
install -D -m 644 avell-fan.svg /usr/local/share/icons/hicolor/scalable/apps/avell-fan.svg
install -D -m 644 desktop/avell-fan.desktop /usr/local/share/applications/avell-fan.desktop
install -D -m 644 desktop/avell-fan-tray.desktop /etc/xdg/autostart/avell-fan-tray.desktop
gtk-update-icon-cache -q /usr/local/share/icons/hicolor 2>/dev/null || true
update-desktop-database -q /usr/local/share/applications 2>/dev/null || true

sleep 3
/usr/local/bin/avell-fan status
echo
echo "Pronto. Abra \"Avell Fan\" no menu, ou rode: avell-fan-gui"
echo "O ícone da bandeja inicia sozinho no próximo login."

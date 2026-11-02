#!/bin/bash
# Instala drivers (DKMS), serviço, interface gráfica e ícone da bandeja.
# Uso: sudo ./instalar.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Rode com sudo: sudo ./instalar.sh"; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"
if dpkg -s avell-fan >/dev/null 2>&1; then
  echo "O pacote .deb do avell-fan já está instalado. Atualize por ele (sudo apt install ./avell-fan_*.deb)"
  echo "ou remova antes (sudo apt remove avell-fan)."
  exit 1
fi

PKG=avell-fan-drivers
VER=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' avell-fan)
SRC=/usr/src/$PKG-$VER
SHARE=/usr/local/share/avell-fan

echo "==> Dependências"
apt-get install -y --no-install-recommends dkms "linux-headers-$(uname -r)" python3-gi gir1.2-gtk-3.0 libnotify-bin >/dev/null
apt-get install -y --no-install-recommends gir1.2-xapp-1.0 >/dev/null 2>&1 \
  || apt-get install -y --no-install-recommends gir1.2-ayatanaappindicator3-0.1 >/dev/null 2>&1 \
  || echo "   (sem biblioteca de bandeja: a interface abre só como janela)"

echo "==> Drivers (DKMS: recompila sozinho a cada kernel novo)"
# remove todas as versões anteriores (ex.: 1.0 ao instalar a 1.1)
for v in $(dkms status -m $PKG 2>/dev/null | sed -n "s#^$PKG/\([^,:]*\).*#\1#p" | sort -u); do
  dkms remove -m $PKG -v "$v" --all >/dev/null 2>&1 || true
  rm -rf "/usr/src/$PKG-$v"
done
rm -rf "$SRC"
cp -r vendor/tuxedo-drivers "$SRC"
sed "s/@VER@/$VER/g" packaging/dkms.conf.in > "$SRC/dkms.conf"
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

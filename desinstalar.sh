#!/bin/bash
# Remove tudo que o instalar.sh colocou no sistema. Uso: sudo ./desinstalar.sh
[ "$(id -u)" = 0 ] || { echo "Rode com sudo"; exit 1; }
systemctl disable --now avell-fan 2>/dev/null
rm -f /etc/systemd/system/avell-fan.service /usr/local/bin/avell-fan /usr/local/bin/avell-fan-gui \
      /etc/modules-load.d/avell-fan.conf /usr/local/share/applications/avell-fan.desktop \
      /etc/xdg/autostart/avell-fan-tray.desktop /usr/local/share/icons/hicolor/scalable/apps/avell-fan.svg
rm -rf /usr/local/share/avell-fan /var/lib/avell-fan
systemctl daemon-reload
rmmod tuxedo_io uniwill_wmi tuxedo_keyboard tuxedo_compatibility_check 2>/dev/null
dkms remove -m avell-fan-drivers -v 1.0 --all 2>/dev/null
rm -rf /usr/src/avell-fan-drivers-1.0
echo "Removido (o /etc/avell-fan.json foi mantido)."

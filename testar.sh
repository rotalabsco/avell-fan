#!/bin/bash
# Diagnóstico sem instalar nada: compila os drivers, carrega temporariamente (somem no reboot)
# e roda uma leitura somente-leitura do EC.
# Uso: sudo ./testar.sh        Para descarregar: sudo ./testar.sh --remover
set -e
cd "$(dirname "$(readlink -f "$0")")"
if [ "$1" = "--remover" ]; then
  rmmod tuxedo_io uniwill_wmi tuxedo_keyboard tuxedo_compatibility_check 2>/dev/null || true
  echo "Drivers removidos."; exit 0
fi
[ "$(id -u)" = 0 ] || { echo "Rode com sudo"; exit 1; }
if lsmod | grep -q '^uniwill_laptop'; then echo "Remova o uniwill-laptop antes (rmmod uniwill_laptop)"; exit 1; fi
B=vendor/tuxedo-drivers
make -s -C "$B" >/dev/null
modprobe sparse-keymap
modprobe led-class-multicolor
for m in src/tuxedo_compatibility_check/tuxedo_compatibility_check src/tuxedo_keyboard src/uniwill_wmi src/tuxedo_io/tuxedo_io; do
  n=$(basename $m)
  lsmod | grep -q "^$n " || insmod "$B/$m.ko"
done
make -s -C "$B" clean >/dev/null
[ -x probe/probe ] || gcc -O2 -I probe -o probe/probe probe/probe.c
sleep 1
echo "=== dmesg ==="; dmesg | grep -iE 'tuxedo|uniwill' | tail -20
echo "=== /dev/tuxedo_io ==="; ls -l /dev/tuxedo_io
echo "=== leitura do EC ==="; ./probe/probe
echo "=== coretemp (comparação) ==="; sensors coretemp-isa-0000 2>/dev/null | grep -E 'Package' || true

# Detalhes técnicos

Como o avell-fan conversa com o hardware, as proteções e como estender. Para instalar e usar, veja o [README](../README.md).

## Como funciona

```
avell-fan (Python, daemon root)  ──ioctl──▶  /dev/tuxedo_io  ──WMI──▶  EC Uniwill  ──▶  fans
                                              (tuxedo_io + uniwill_wmi + tuxedo_keyboard)
```

- **Drivers:** `vendor/tuxedo-drivers` é uma cópia do [tuxedo-drivers](https://github.com/tuxedocomputers/tuxedo-drivers) (GPLv2, commit `a929f9c`). O Avell passa no `tuxedo_compatibility_check` porque a CPU é Comet Lake, que está na lista de exceções do driver.
- **Registradores do EC usados pelo driver:**
  - velocidade dos fans: `0x1804` e `0x1809`, escala 0–200;
  - temperaturas: `0x043e` (CPU) e `0x044f` (GPU);
  - modo: `0x0751`;
  - tabela de fan customizada: `0x0f00` a `0x0f5f`.
- **Segurança:**
  - acima de `temp_failsafe` (90 °C) o fan vai para 100 %, qualquer que seja o perfil;
  - ao sair, cair ou ser morto, o daemon devolve o controle à BIOS (`W_UW_FANAUTO`, também via `ExecStopPost`);
  - systemd `WatchdogSec=15`: se o loop travar sem morrer, o systemd mata o daemon e devolve o controle à BIOS;
  - nunca manda menos de `pct_minimo` (25 %) no modo manual.
- **Caminho do driver no Avell (testado em 2026-11-01):** "full fan mode", com o bit `0x40` do `0x0751` ligado durante o controle manual, e não a tabela universal. Consequências:
  - não existe a proteção do EC a 115 °C, então o failsafe do daemon é a proteção (a CPU ainda reduz a velocidade sozinha a ~100 °C);
  - se o bit cair (botão, suspend), o daemon detecta e reaplica;
  - o driver reinicia o controle a cada 50 min, o que pode dar um pico curto de rotação.
- **Não instale junto** o `tuxedo-drivers` do apt nem o TUXEDO Control Center: os módulos têm os mesmos nomes e vão brigar.
- O DKMS compila só os 4 módulos necessários (`vendor/tuxedo-drivers/src/Kbuild`; o original está em `Kbuild.orig`).

## Uso

```bash
sudo ./testar.sh                 # carrega os drivers temporariamente + sonda só-leitura
sudo ./avell-fan testar 100 10   # 1º teste de escrita: 100% por 10s e volta pro auto
sudo ./instalar.sh               # DKMS + serviço systemd

avell-fan status
avell-fan perfil silencioso      # auto | silencioso | equilibrado | maximo
avell-fan proximo
avell-fan carga                  # mostra o limite de carga da bateria
sudo avell-fan carga stationary  # high_capacity (~100%) | balanced (~90%) | stationary (~80%)
```

As curvas, o ciclo do botão e os limites ficam em `/etc/avell-fan.json`. Ele sobrescreve só as chaves que você puser lá. Exemplo:

```json
{ "perfis": { "silencioso": [[55, 0], [62, 25], [75, 45], [85, 100]] }, "temp_failsafe": 88 }
```

Os dois fans seguem a **maior** das duas temperaturas (CPU/GPU), porque eles dividem os heatpipes.

## Bateria e energia

- **Limite de carga:** o `tuxedo_keyboard` expõe `/sys/devices/platform/tuxedo_keyboard/charging_profile/charging_profile`, que grava os bits 4–5 de um registrador do EC: `high_capacity` (0, carga completa), `balanced` (1, ~90 %) e `stationary` (2, ~80 %). Os percentuais são aproximados: quem decide é o firmware.
- O daemon aplica a chave `carga` do `/etc/avell-fan.json` ao iniciar e sempre que a config muda. O `aplicar-config` (usado pela interface) e o `avell-fan carga <modo>` também aplicam na hora, então o limite vale mesmo com o serviço parado. Sem a chave `carga`, ninguém mexe no que está no EC.
- **Perfil por fonte de energia:** o daemon lê `/sys/class/power_supply/*/online` (tipo `Mains`) a cada ciclo. Ao iniciar e a cada mudança de tomada↔bateria, aplica `perfil_tomada` ou `perfil_bateria`, se definidos. Entre uma mudança e outra, a escolha manual continua valendo.

```json
{ "carga": "stationary", "perfil_tomada": "equilibrado", "perfil_bateria": "silencioso" }
```

## Botão de fan (a mapear)

O `uniwill_wmi` ignora o código do botão e só o registra com o debug ligado. Para descobrir:

```bash
echo 'module tuxedo_keyboard +p; module uniwill_wmi +p' | sudo tee /sys/kernel/debug/dynamic_debug/control
# aperte o botão de fan algumas vezes
sudo dmesg | grep -iE 'unknown code|uniwill' | tail
```

Com o código em mãos:

1. Adicionar `{ KE_KEY, <código>, { KEY_PROG4 } }` no keymap em `vendor/tuxedo-drivers/src/uniwill_keyboard.h`.
2. Rodar `sudo ./instalar.sh` de novo.
3. Pôr `"botao_keycode": 203` (KEY_PROG4) no `/etc/avell-fan.json`.

Para conferir o keycode: `sudo avell-fan botao`. Ele também mostra se o botão muda o modo do EC (`0x0751`) direto, sem gerar evento de tecla.

## Arquivos

| Caminho | O quê |
|---|---|
| `avell-fan` | programa (CLI + daemon), só biblioteca padrão do Python |
| `avell-fan-gui` | interface GTK3 (janela + painel da bandeja), roda como usuário comum |
| `desktop/` | atalho do menu e autostart da bandeja |
| `fonts/` | Bricolage Grotesque, Geist e Geist Mono (OFL), carregadas só pelo app |
| `temas/` | tokens de cor, fonte e raio da interface + JSON Schema ([TEMA.md](TEMA.md)) |
| `avell-fan.service` | unit systemd |
| `instalar.sh` / `desinstalar.sh` | instalação via DKMS (`avell-fan-drivers/1.0`) |
| `testar.sh`, `probe/` | diagnóstico sem instalar: compila, carrega temporariamente e lê o EC |
| `vendor/tuxedo-drivers` | fonte dos drivers |

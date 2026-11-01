// Sonda SOMENTE LEITURA do EC Uniwill via /dev/tuxedo_io. Nenhuma escrita.
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include "tuxedo_io_ioctl.h"

static void rd(int fd, unsigned long cmd, const char *name) {
    int32_t v = -1;
    int r = ioctl(fd, cmd, &v);
    if (r < 0) perror(name); else printf("%-22s %d (0x%02x)\n", name, v, v & 0xff);
}

int main(void) {
    int fd = open("/dev/tuxedo_io", O_RDONLY);
    if (fd < 0) { perror("/dev/tuxedo_io"); return 1; }
    char s[64] = {0};
    if (ioctl(fd, R_UW_HW_IF_STR, s) == 0) printf("%-22s %s\n", "interface", s); else perror("R_UW_HW_IF_STR");
    rd(fd, R_UW_MODEL_ID, "model_id");
    rd(fd, R_UW_FANSPEED, "fan1_speed(0-200)");
    rd(fd, R_UW_FANSPEED2, "fan2_speed(0-200)");
    rd(fd, R_UW_FAN_TEMP, "fan1_temp(C)");
    rd(fd, R_UW_FAN_TEMP2, "fan2_temp(C)");
    rd(fd, R_UW_MODE, "mode(0x0751)");
    rd(fd, R_UW_MODE_ENABLE, "mode_enable(0x0741)");
    rd(fd, R_UW_FANS_MIN_SPEED, "fans_min_speed");
    rd(fd, R_UW_PROFS_AVAILABLE, "profiles_available");
    close(fd);
    return 0;
}

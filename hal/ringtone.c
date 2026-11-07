// ringtone — test writer: feeds a 440 Hz tone into the shared mic ring for N seconds.
#include "../Sources/CMicRing/include/micring.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <time.h>
int main(int argc, char **argv) {
    double secs = argc > 1 ? atof(argv[1]) : 5;
    micring_t *r = micring_open_writer();
    if (!r) { perror("micring_open_writer"); return 1; }
    micring_set_active(r, 1);
    float buf[480]; double ph = 0; long written = 0;
    struct timespec t0; clock_gettime(CLOCK_MONOTONIC, &t0);
    while (written < (long)(secs * 48000)) {               /* real-time paced by the wall clock */
        struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
        double el = (t.tv_sec - t0.tv_sec) + (t.tv_nsec - t0.tv_nsec) / 1e9;
        long owed = (long)(el * 48000) + 960 - written;    /* keep ~20 ms ahead */
        if (owed < 480) { usleep(2000); continue; }
        for (int k = 0; k < 480; k++) { buf[k] = 0.3f * (float)sin(ph); ph += 2 * M_PI * 440.0 / 48000.0; }
        micring_write(r, buf, 480); written += 480;
    }
    micring_set_active(r, 0);
    printf("wrote %ld frames (%.1fs)\n", written, written / 48000.0);
    micring_close(r);
    return 0;
}

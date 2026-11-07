// opus2wav — decode a .opuspkts file ([u32 len][packet]...) with libopus to 16 kHz mono WAV,
// and print amplitude statistics so silence is not mistaken for a recording.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <opus/opus.h>

static void wr32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }
static void wr16(FILE *f, uint16_t v) { fwrite(&v, 2, 1, f); }

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: opus2wav in.opuspkts out.wav [rate]\n"); return 2; }
    int rate = argc > 3 ? atoi(argv[3]) : 16000;
    FILE *in = fopen(argv[1], "rb"); if (!in) { perror("open in"); return 1; }
    int err = 0; OpusDecoder *dec = opus_decoder_create(rate, 1, &err);
    if (err != OPUS_OK) { fprintf(stderr, "opus_decoder_create: %s\n", opus_strerror(err)); return 1; }
    FILE *out = fopen(argv[2], "wb"); if (!out) { perror("open out"); return 1; }
    // WAV header placeholder
    fwrite("RIFF", 1, 4, out); wr32(out, 0); fwrite("WAVEfmt ", 1, 8, out); wr32(out, 16); wr16(out, 1); wr16(out, 1);
    wr32(out, rate); wr32(out, rate * 2); wr16(out, 2); wr16(out, 16); fwrite("data", 1, 4, out); wr32(out, 0);
    int16_t pcm[5760]; uint8_t pkt[4096];
    long npk = 0, ok = 0, bad = 0, samples = 0; double sumsq = 0; int peak = 0; int tocs[256] = {0};
    uint32_t len;
    while (fread(&len, 4, 1, in) == 1) {
        if (len == 0 || len > sizeof pkt) { bad++; fseek(in, len, SEEK_CUR); continue; }
        if (fread(pkt, 1, len, in) != len) break;
        npk++; tocs[pkt[0]]++;
        int n = opus_decode(dec, pkt, (opus_int32)len, pcm, 5760, 0);
        if (n < 0) { bad++; if (bad <= 5) fprintf(stderr, "packet %ld: %s (toc 0x%02x len %u)\n", npk, opus_strerror(n), pkt[0], len); continue; }
        ok++; samples += n;
        for (int i = 0; i < n; i++) { int v = pcm[i]; sumsq += (double)v * v; if (abs(v) > peak) peak = abs(v); }
        fwrite(pcm, 2, n, out);
    }
    long bytes = samples * 2;
    fseek(out, 4, SEEK_SET); wr32(out, 36 + bytes); fseek(out, 40, SEEK_SET); wr32(out, bytes); fclose(out);
    double rms = samples ? sqrt(sumsq / samples) : 0;
    printf("packets=%ld decoded=%ld bad=%ld samples=%ld duration=%.2fs rate=%d\n", npk, ok, bad, samples, (double)samples / rate, rate);
    printf("peak=%d (%.1f dBFS) rms=%.0f (%.1f dBFS)\n", peak, 20 * log10((peak ? peak : 1) / 32768.0), rms, 20 * log10((rms > 0 ? rms : 1) / 32768.0));
    printf("TOC bytes seen:"); for (int i = 0; i < 256; i++) if (tocs[i]) printf(" 0x%02x(%d)", i, tocs[i]); printf("\n");
    printf("frame samples per packet: %ld (expect 320 = 20ms@16k)\n", ok ? samples / ok : 0);
    opus_decoder_destroy(dec);
    return 0;
}

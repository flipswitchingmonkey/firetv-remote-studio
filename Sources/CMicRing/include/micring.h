// Shared-memory ring buffer between Fire TV Remote Studio (writer) and the HAL plug-in (reader).
// Lock-free single-writer / single-reader. Lives in a world-readable mmap'ed file.
#ifndef MICRING_H
#define MICRING_H
#include <stdint.h>
#include <stdatomic.h>

#define MICRING_MAGIC      0x4D494352u   /* 'MICR' */
#define MICRING_VERSION    1u
#define MICRING_RATE       48000u
#define MICRING_CHANNELS   1u
#define MICRING_CAPACITY   (48000u * 2u) /* frames: 2 s of audio */
#define MICRING_DIR        "/Users/Shared/FireTVRemoteStudio"
#define MICRING_PATH       MICRING_DIR "/mic.ring"

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t sampleRate;
    uint32_t channels;
    uint32_t capacity;          /* frames */
    uint32_t reserved0;
    _Atomic uint64_t writePos;  /* total frames ever written (monotonic) */
    _Atomic uint32_t active;    /* 1 while the mic button is held and audio flows */
    uint32_t reserved1;
    _Atomic uint64_t writerHeartbeat; /* mach_absolute_time of the last write; reader treats stale as silence */
    uint8_t  pad[64 - 48];
    float    samples[];         /* capacity * channels interleaved float32 */
} micring_t;

#define MICRING_FILE_SIZE (sizeof(micring_t) + (size_t)MICRING_CAPACITY * MICRING_CHANNELS * sizeof(float))

#ifdef __cplusplus
extern "C" {
#endif
/* Writer side (app). Returns NULL on failure (errno set). Creates/truncates the file with mode 0644. */
micring_t *micring_open_writer(void);
void micring_close(micring_t *r);
/* Append interleaved float frames. Overwrites oldest data if the reader is too slow. */
void micring_write(micring_t *r, const float *frames, uint32_t frameCount);
void micring_set_active(micring_t *r, int active);
const char *MICRING_PATH_C(void);
#ifdef __cplusplus
}
#endif
#endif

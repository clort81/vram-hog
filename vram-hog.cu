#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <cuda_runtime.h>

static void usage(void) {
    fprintf(stderr,
        "usage: vram-hog GiB [device] [seconds]\n"
        "  GiB      VRAM to hold, required (fractional ok)\n"
        "  device   CUDA device index (default 0)\n"
        "  seconds  auto-release after N seconds (default: wait for signal)\n"
        "Blocks until SIGINT/SIGTERM (or timeout), then frees all VRAM.\n");
}

int main(int argc, char *argv[]) {
    double gb;
    long dev = 0, secs = 0;
    char *end;
    size_t want;
    int rc;
    sigset_t blockset;
    cudaError_t err;
    void *buf = NULL;

    if (argc < 2 || argc > 4) { usage(); return 2; }
    gb = strtod(argv[1], &end);
    if (gb <= 0.0 || *end != '\0') { usage(); return 2; }
    if (argc > 2 && argv[2][0] != '\0') {
        dev = strtol(argv[2], &end, 10);
        if (dev < 0 || *end != '\0') { usage(); return 2; }
    }
    if (argc > 3 && argv[3][0] != '\0') {
        secs = strtol(argv[3], &end, 10);
        if (secs < 0 || *end != '\0') { usage(); return 2; }
    }

    setbuf(stdout, NULL);                    /* readiness line must land even when piped */

    /* block kill signals BEFORE touching CUDA: early Ctrl+C queues
       instead of killing mid-allocation, handled at sigtimedwait;
       SIGALRM joins the set so the countdown timeout can't race it */
    sigemptyset(&blockset);
    sigaddset(&blockset, SIGINT);
    sigaddset(&blockset, SIGTERM);
    sigaddset(&blockset, SIGALRM);
    sigprocmask(SIG_BLOCK, &blockset, NULL);

    err = cudaSetDevice((int)dev);
    if (err != cudaSuccess) {
        fprintf(stderr, "cudaSetDevice(%ld): %s\n", dev, cudaGetErrorString(err));
        return 1;
    }

    want = (size_t)(gb * 1024.0 * 1024.0 * 1024.0);
    if (want == 0) { fprintf(stderr, "GB value rounds to zero bytes\n"); return 2; }

    err = cudaMalloc(&buf, want);            /* all-or-nothing: exact request */
    if (err != cudaSuccess) {
        fprintf(stderr, "Failed to reserve %zu MB on device %ld: %s\n",
                want / (1024 * 1024), dev, cudaGetErrorString(err));
        return 1;
    }
    //printf("Holding %zu MB on device %ld. Kill AFTER your app finishes loading.\n", want / (1024 * 1024), dev);

    /* sleeps here, zero CPU; with secs>0, wakes each second to show countdown */
    if (secs > 0) {
        struct timespec ts;
        long left = secs;
        while (left > 0) {
            //printf("\rAuto-release in %3ld s", left);
            ts.tv_sec = 1;
            ts.tv_nsec = 0;
            rc = sigtimedwait(&blockset, NULL, &ts);
            if (rc == SIGINT || rc == SIGTERM) break;  /* real signal */
            if (rc == -1 && errno != EAGAIN) break;    /* unexpected error */
            left -= 1;                                 /* tick expired */
        }
        //printf("\rAuto-release in   0 s\n");
    } else {
        sigwait(&blockset, &rc);
    }

    cudaFree(buf);
    //printf("Released %zu MB.\n", want / (1024 * 1024));
    return 0;
}


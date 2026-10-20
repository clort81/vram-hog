#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

static volatile sig_atomic_t running = 1;

void handler(int sig) { running = 0; }

int main(int argc, char *argv[]) {
    size_t gb = (argc > 1) ? atoi(argv[1]) : 14;
    size_t bytes = gb * 1024ULL * 1024ULL * 1024ULL;

    void *ptr = NULL;
    cudaError_t err = cudaMalloc(&ptr, bytes);
    if (err != cudaSuccess) {
        fprintf(stderr, "Failed to allocate %zu GB: %s\n", gb, cudaGetErrorString(err));
        return 1;
    }
    printf("Holding %zu GB. Kill me (Ctrl+C) to release.\n", gb);

    signal(SIGINT, handler);
    signal(SIGTERM, handler);

    while (running) {
        // keep the process alive; memory stays allocated
        cudaDeviceSynchronize();
    }

    cudaFree(ptr);
    printf("Released %zu GB.\n", gb);
    return 0;
}   

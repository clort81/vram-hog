### VRAM-Hog
```
        _
        |\_,,____
        ( o__o \/
        /(..)  \   - "I'll prevent that MoE llama-server from
       (_ )--( _)     crashing when it tries to reserve 2 much!"
       / ""--"" \
,===,=| |-,,,,-| |==,==
|d  |  WW   |  WW   |
|s  |   |   |   |   |
```

# CUDA/LINUX: temporarily reserve some vram before launching a greedy vram program.

# Usage

vram-hog GiB Cuda_Device [Seconds]

e.g.

vram_hog 0.47 1 45&

MIT License: Copyright (c) 2026 Clort81

# air
we need it daily
# depends on
- curl
- gunzip
- sed
- awk
- grep
- sort
- uniq
- base64
- [ip-dedup](https://github.com/dywisor/ip-dedup)
    - `make clean ; make STANDALONE=1 CC='zig cc -flto -O3 -s -static -target aarch64-linux-musl -pie' HARDEN=0 NO_WERROR=1 -j`
    - `make clean ; make STANDALONE=1 CC='zig cc -flto -O3 -s -static -target x86_64-linux-musl -pie' HARDEN=0 NO_WERROR=1 -j`

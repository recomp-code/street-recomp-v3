// Smoke test of the POSIX live ring without the game: plays the producer side (what
// gs_dump_writer.cpp does in the runtime), starts the GS host with -live and streams a GS dump
// header plus empty frames (registers + VSync) at 60 Hz for a few seconds. Checks that the host
// attaches (consumerAlive), consumes the stream (readPos) and keeps up.
//
//   clang++ -std=c++20 -O2 -I <PS2Recomp>/ps2xRuntime/src/lib/gs live_ring_smoke.cpp -o live_ring_smoke
//   ./live_ring_smoke <gshost dir> [seconds]
// PS2X_SHOT_TIMES / PS2X_SHOT_DIR (host) can save frames meanwhile.

#include "ps2_live_ring.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <string>
#include <sys/mman.h>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>
#include <vector>

extern char **environ;

namespace
{
#pragma pack(push, 4)
    struct DumpHeader
    {
        uint32_t state_version, state_size, serial_offset, serial_size, crc;
        uint32_t screenshot_width, screenshot_height, screenshot_offset, screenshot_size;
    };
#pragma pack(pop)

    ps2live::RingHeader *g_header = nullptr;
    ps2live::RingEvents *g_events = nullptr;
    uint8_t *g_data = nullptr;
    pid_t g_host = 0;
    uint64_t g_waits = 0;

    bool hostGone()
    {
        int status = 0;
        return g_header->consumerQuit || waitpid(g_host, &status, WNOHANG) == g_host;
    }

    bool write(const void *src, size_t size)
    {
        const uint8_t *p = static_cast<const uint8_t *>(src);
        const uint64_t capacity = g_header->capacity;
        while (size)
        {
            const int64_t w = g_header->writePos, r = g_header->readPos;
            const uint64_t freeBytes = capacity - static_cast<uint64_t>(w - r);
            if (!freeBytes)
            {
                if (hostGone())
                    return false;
                ps2live::eventSet(&g_events->data);
                g_header->producerWaiting = 1;
                __atomic_thread_fence(__ATOMIC_SEQ_CST);
                if (g_header->readPos == r)
                    ps2live::eventWait(&g_events->space, 20);
                g_header->producerWaiting = 0;
                g_waits++;
                continue;
            }
            const uint64_t offset = static_cast<uint64_t>(w) % capacity;
            const size_t chunk = static_cast<size_t>(std::min<uint64_t>({size, freeBytes, capacity - offset}));
            std::memcpy(g_data + offset, p, chunk);
            __atomic_thread_fence(__ATOMIC_RELEASE);
            g_header->writePos = w + static_cast<int64_t>(chunk);
            p += chunk;
            size -= chunk;
        }
        return true;
    }

    void signal()
    {
        __atomic_thread_fence(__ATOMIC_SEQ_CST);
        if (!g_header->consumerFlags || g_header->consumerWaiting)
            ps2live::eventSet(&g_events->data);
    }
} // namespace

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        std::fprintf(stderr, "usage: %s <gshost dir> [seconds]\n", argv[0]);
        return 2;
    }
    const std::string gshost = argv[1];
    const double seconds = argc > 2 ? std::atof(argv[2]) : 5.0;

    const std::string suffix = std::to_string(getpid());
    const std::string name = ps2live::objectName(ps2live::kPosixMappingName, suffix);
    const uint64_t capacity = 16ull << 20;
    const uint64_t total = ps2live::mappingSize(capacity);
    shm_unlink(name.c_str());
    const int fd = shm_open(name.c_str(), O_RDWR | O_CREAT | O_EXCL, 0600);
    if (fd < 0 || ftruncate(fd, static_cast<off_t>(total)) != 0)
    {
        std::perror("shm");
        return 1;
    }
    void *view = mmap(nullptr, total, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (view == MAP_FAILED)
    {
        std::perror("mmap");
        return 1;
    }
    g_header = static_cast<ps2live::RingHeader *>(view);
    std::memset(g_header, 0, sizeof(*g_header));
    g_header->capacity = capacity;
    g_header->padAxes = 0x80808080u;
    g_header->version = ps2live::kVersion;
    g_header->producerAlive = 1;
    g_header->producerFlags = 1;
    g_data = ps2live::ringData(g_header);
    g_events = ps2live::ringEvents(g_header);
    std::memset(g_events, 0, sizeof(*g_events));
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
    g_header->magic = ps2live::kMagic;

    std::string exe = gshost + "/pcsx2-gsrunner";
    std::vector<std::string> args{exe, "-live", "-window", "-livering", suffix, "-ini", "nba_street.ini"};
    std::vector<char *> argv2;
    for (std::string &a : args)
        argv2.push_back(a.data());
    argv2.push_back(nullptr);
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addchdir_np(&actions, gshost.c_str());
    if (const int error = posix_spawn(&g_host, exe.c_str(), &actions, nullptr, argv2.data(), environ))
    {
        std::fprintf(stderr, "spawn %s: %s\n", exe.c_str(), std::strerror(error));
        return 1;
    }

    // GS dump header, as ensureHeader() writes it.
    static const char kSerial[] = "SLUS-21126";
    const uint32_t serialSize = sizeof(kSerial) - 1;
    const uint32_t magic = 0xFFFFFFFFu, headerSize = sizeof(DumpHeader) + serialSize;
    DumpHeader header{};
    header.state_version = 9;
    header.serial_offset = sizeof(DumpHeader);
    header.serial_size = serialSize;
    header.screenshot_offset = header.serial_offset + serialSize;
    std::vector<uint8_t> regs(8192, 0);
    write(&magic, 4);
    write(&headerSize, 4);
    write(&header, sizeof(header));
    write(kSerial, serialSize);
    write(regs.data(), regs.size());

    const auto start = std::chrono::steady_clock::now();
    bool attached = false;
    int frames = 0;
    for (;;)
    {
        const double t = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
        if (t >= seconds)
            break;
        if (!attached && g_header->consumerAlive)
        {
            attached = true;
            std::printf("host attached after %.2f s\n", t);
        }
        const uint8_t typeRegs = 3, typeVsync = 1;
        const uint8_t field = static_cast<uint8_t>(frames & 1);
        if (!write(&typeRegs, 1) || !write(regs.data(), regs.size()) || !write(&typeVsync, 1) || !write(&field, 1))
        {
            std::printf("host closed after %d frames\n", frames);
            break;
        }
        signal();
        frames++;
        std::this_thread::sleep_until(start + std::chrono::microseconds(static_cast<int64_t>(frames * 1e6 / 60.0)));
    }
    // Let the host drain what is left before comparing.
    for (int i = 0; i < 100 && g_header->readPos != g_header->writePos && !hostGone(); i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    const int64_t written = g_header->writePos, read = g_header->readPos;
    std::printf("frames %d, bytes written %lld, read %lld, producer waits %llu, consumerAlive %u, consumerFlags %u\n",
                frames, static_cast<long long>(written), static_cast<long long>(read),
                static_cast<unsigned long long>(g_waits), g_header->consumerAlive, g_header->consumerFlags);

    // The game exits: the host must notice and close.
    g_header->producerAlive = 0;
    ps2live::eventSet(&g_events->data);
    int status = 0;
    for (int i = 0; i < 50 && waitpid(g_host, &status, WNOHANG) == 0; i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    const bool exited = kill(g_host, 0) != 0;
    if (!exited)
    {
        kill(g_host, SIGTERM);
        waitpid(g_host, &status, 0);
    }
    std::printf("host %s after the producer left\n", exited ? "exited" : "did NOT exit (killed)");
    shm_unlink(name.c_str());
    return attached && read == written && exited ? 0 : 1;
}

// Game override: NBA Street V3 (NTSC-U, SLUS_211.26, entry 0x00100008)
//
// Address bindings for SDK functions that Ghidra/ps2_analyzer did not name in this stripped ELF.
// Each of them spins forever in an SDK "bind RPC until cd->server != 0" loop, because the
// runtime IOP has no server for its SID. Identification evidence:
//
//   0x00544490 sceSifStopModule          LOADFILE (0x80000006) RPC fn 7
//   0x00544728 sceSifSearchModuleByName  LOADFILE RPC fn 9, strlen(name); boot asks for "hdd"
//   0x004C7178 sceCdSearchFile           28-byte wrapper of 0x004C6E60
//   0x004C6E60 _sceCdSearchFile          binds 0x80000597, "Libcdvd bind err CdSearchFile"
//   0x004C8018 sceCdReadDvdDualInfo      S-command 0x27, two int outputs, used at disc setup
//   0x004C8480 sceMtapInit               binds 0x80000901..905, "libmtap: bind failed"
//   0x004C86C0 sceMtapPortOpen           RPC on client 0x80000901
//   0x004C8730 sceMtapPortClose          RPC on client 0x80000902
//   0x004C87A0 sceMtapGetConnection      RPC on client 0x80000903
//   0x004C9B38 sceUsbKbInit              binds 0x80000211, "libusbkb : bind errr"
//
// Multitap answers mimic a PS2 with no multitap plugged in (init/open succeed, no connection),
// and the USB keyboard reports "not available", so the game falls back to normal pads.

#include "game_overrides.h"
#include "ps2_runtime.h"
#include "ps2_runtime_macros.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <string>

namespace
{
    // 0x003F3508 just calls the callback stored at 0x005B6250. Nothing in the ELF writes that
    // slot statically (it is 0 in .data), and the game calls 0x003F3508 unconditionally from
    // 0x003E18B8/0x003E1C98, so on hardware it must be registered at runtime -- most likely by
    // EA's sound driver once its IOP RPC (SID 0x00534E44) is up. Until that path works here,
    // treat an unset callback as a no-op instead of jumping to address 0.
    constexpr uint32_t kCallbackDispatch = 0x003F3508u;
    constexpr uint32_t kCallbackSlot = 0x005B6250u;
    PS2Runtime::RecompiledFunction g_originalCallbackDispatch = nullptr;

    void nullSafeCallbackDispatch(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        uint32_t callback = 0;
        std::memcpy(&callback, rdram + kCallbackSlot, sizeof(callback));
        if (callback == 0u || !g_originalCallbackDispatch)
        {
            static bool s_logged = false;
            if (!s_logged)
            {
                s_logged = true;
                std::cerr << "[NBA Street V3] callback at 0x5B6250 not registered; skipping call" << std::endl;
            }
            SET_GPR_U32(ctx, 2, 0u);
            ctx->pc = GPR_U32(ctx, 31);
            return;
        }
        g_originalCallbackDispatch(rdram, ctx, runtime);
    }

    bool envFlagSet(const char *name)
    {
        char *env = nullptr;
        size_t envLength = 0;
        bool set = false;
        if (_dupenv_s(&env, &envLength, name) == 0 && env)
        {
            set = env[0] != '\0' && env[0] != '0';
            std::free(env);
        }
        return set;
    }

    // The game's EA file system parses the disc itself (reads LBN 16 = ISO9660 volume
    // descriptor), so it needs raw sector access: point the runtime at the original image.
    // PS2X_CD_IMAGE overrides; default is <elf dir>/../NBAStreetV3.iso.
    void configureCdImage()
    {
        PS2Runtime::IoPaths paths = PS2Runtime::getIoPaths();
        std::filesystem::path image;
        char *env = nullptr;
        size_t envLength = 0;
        if (_dupenv_s(&env, &envLength, "PS2X_CD_IMAGE") == 0 && env)
        {
            image = env;
            std::free(env);
        }
        if (image.empty() && !paths.elfDirectory.empty())
        {
            image = paths.elfDirectory.parent_path() / "NBAStreetV3.iso";
        }
        std::error_code ec;
        if (!image.empty() && std::filesystem::exists(image, ec))
        {
            paths.cdImage = image;
            PS2Runtime::setIoPaths(paths);
            std::cerr << "[NBA Street V3] CD image: " << image.string() << std::endl;
        }
        else
        {
            std::cerr << "[NBA Street V3] CD image not found (" << image.string()
                      << "); raw sector reads will fail. Set PS2X_CD_IMAGE." << std::endl;
        }
    }

    // EA SND9 keeps a linked list of per-tick callbacks at 0x00683968 (node: next, ?, func,
    // arg), walked by 0x00515F18 from the audio thread. Sound banks (SFX\*.BIG) carry small
    // relocatable MIPS plugins that the game links into the heap at run time and registers
    // here; static recompilation has no code for them, so the runtime's fallback interpreter
    // runs them. PS2X_NBA_DISABLE_AUDIO_PLUGINS=1 instead points those nodes at an existing
    // "return 0" function (the workaround used before the interpreter existed).
    constexpr uint32_t kAudioCallbackWalker = 0x00515F18u;
    constexpr uint32_t kAudioCallbackListHead = 0x00683968u;
    constexpr uint32_t kGuestReturnZero = 0x00107E30u; // jr ra / daddu v0, zero, zero
    PS2Runtime::RecompiledFunction g_originalAudioCallbackWalker = nullptr;

    void safeAudioCallbackWalker(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        uint32_t node = 0;
        std::memcpy(&node, rdram + kAudioCallbackListHead, sizeof(node));
        for (int guard = 0; node != 0u && node + 16u <= PS2_RAM_SIZE && guard < 256; ++guard)
        {
            uint32_t function = 0;
            std::memcpy(&function, rdram + node + 8u, sizeof(function));
            if (function != 0u && function != kGuestReturnZero && !runtime->hasFunction(function))
            {
                static uint32_t s_logged = 0;
                if (s_logged < 16u)
                {
                    ++s_logged;
                    std::cerr << "[NBA Street V3] disabling runtime-loaded audio plugin callback 0x" << std::hex
                              << function << " (node 0x" << node << ")" << std::dec << std::endl;
                }
                std::memcpy(rdram + node + 8u, &kGuestReturnZero, sizeof(kGuestReturnZero));
            }
            std::memcpy(&node, rdram + node, sizeof(node));
        }
        g_originalAudioCallbackWalker(rdram, ctx, runtime);
    }

    // Online: the EA Online config string "NBASTREET PS2,*ps2nbastreet05.ea.com,21000,false,prod"
    // (two copies in .data) has a leading '*' that makes DirtySock connect with SSLv2 (RC4-MD5) to
    // port 21001. Without it the game talks plain TCP to port 21000, which our server speaks
    // (same idea as the community "SSL bypass" patches). PS2X_NBA_KEEP_SSL=1 keeps the original.
    // The rewrite happens when the boot module loader (0x00103FB0) first runs, after the ELF is in RAM.
    constexpr uint32_t kBootModuleLoader = 0x00103FB0u;
    constexpr uint32_t kOnlineConfigStrings[] = {0x006027C8u, 0x00602810u};
    PS2Runtime::RecompiledFunction g_originalBootModuleLoader = nullptr;

    void patchOnlineConfigStrings(uint8_t *rdram)
    {
        static constexpr char kOriginal[] = "NBASTREET PS2,*ps2nbastreet05.ea.com,21000,false,prod";
        static constexpr char kPlain[] = "NBASTREET PS2,ps2nbastreet05.ea.com,21000,false,prod";
        for (const uint32_t address : kOnlineConfigStrings)
        {
            if (std::memcmp(rdram + address, kOriginal, sizeof(kOriginal)) != 0)
                continue;
            std::memset(rdram + address, 0, sizeof(kOriginal));
            std::memcpy(rdram + address, kPlain, sizeof(kPlain));
            std::cerr << "[NBA Street V3] online: plain TCP lobby (SSL '*' removed at 0x" << std::hex << address
                      << std::dec << ")" << std::endl;
        }
    }

    void bootModuleLoaderWithOnlinePatch(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        static bool s_patched = false;
        if (!s_patched)
        {
            s_patched = true;
            if (!envFlagSet("PS2X_NBA_KEEP_SSL"))
                patchOnlineConfigStrings(rdram);
        }
        g_originalBootModuleLoader(rdram, ctx, runtime);
    }

    // PS2X_NBA_ASSET_TRACE=1: logs the asset manager's requests (0x003945E8), deferred fetches
    // (0x00394AE8) and the head-texture layer loads (0x00392788), for streaming bugs.
    PS2Runtime::RecompiledFunction g_originalAssetRequest = nullptr;
    PS2Runtime::RecompiledFunction g_originalAssetFetch = nullptr;
    PS2Runtime::RecompiledFunction g_originalLayerLoad = nullptr;

    uint32_t gpr32(const R5900Context *ctx, int reg)
    {
        return static_cast<uint32_t>(_mm_cvtsi128_si32(ctx->r[reg]));
    }

    uint32_t guest32(const uint8_t *rdram, uint32_t address)
    {
        uint32_t value;
        std::memcpy(&value, rdram + (address & 0x01FFFFFCu), sizeof(value));
        return value;
    }

    std::string guestString(const uint8_t *rdram, uint32_t address)
    {
        std::string text;
        for (uint32_t i = 0; i < 96u && address; ++i)
        {
            const char c = static_cast<char>(rdram[(address + i) & 0x01FFFFFFu]);
            if (!c)
                break;
            text.push_back(c);
        }
        return text;
    }

    void tracedAssetRequest(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t mgr = gpr32(ctx, 4), name = gpr32(ctx, 7), heap = gpr32(ctx, 5), type = gpr32(ctx, 8),
                       req = gpr32(ctx, 9);
        {
            // Same scan as the manager's lookup (0x003951F0): pooled entries whose name matches.
            const std::string wanted = guestString(rdram, name);
            const uint32_t lists = guest32(rdram, mgr + 0x1006Cu), classes = guest32(rdram, mgr + 0x100A8u);
            const uint32_t classCount = guest32(rdram, mgr + 0x100ACu);
            for (uint32_t c = 0; lists && c < classCount && c < 32u; ++c)
            {
                const uint32_t list = guest32(rdram, lists + c * 4u), count = guest32(rdram, classes + c * 8u + 4u);
                for (uint32_t i = 0; i < count && i < 512u; ++i)
                {
                    const uint32_t entry = guest32(rdram, list + i * 4u);
                    const uint32_t entryName = guest32(rdram, entry + 0x14u);
                    if (_stricmp(guestString(rdram, entryName).c_str(), wanted.c_str()) == 0)
                        std::fprintf(stderr, "[asset]   match class=%u #%u entry=0x%X state=%u data=0x%X name@0x%X ref=%d vt=0x%X w0=%08X\n",
                                     c, i, entry, guest32(rdram, entry + 8u), guest32(rdram, entry + 0xCu), entryName,
                                     static_cast<int>(guest32(rdram, entryName - 0xCu)), guest32(rdram, entry + 0x28u),
                                     guest32(rdram, entry));
                }
            }
        }
        const uint32_t ra = gpr32(ctx, 31);
        g_originalAssetRequest(rdram, ctx, runtime);
        if (ctx->pc != ra)
            return; // preempted mid-function (resumed later by the dispatcher)
        const uint32_t result = gpr32(ctx, 2);
        std::fprintf(stderr, "[asset] request '%s' heap=%u type=%u -> data=0x%X req=[%d,%d] magic=%08X\n",
                     guestString(rdram, name).c_str(), heap, type, result,
                     static_cast<int>(guest32(rdram, req)), static_cast<int>(guest32(rdram, req + 4)),
                     result ? guest32(rdram, result) : 0u);
    }

    void tracedAssetFetch(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t req = gpr32(ctx, 5);
        const int slot = static_cast<int>(guest32(rdram, req)), serial = static_cast<int>(guest32(rdram, req + 4));
        const uint32_t ra = gpr32(ctx, 31);
        g_originalAssetFetch(rdram, ctx, runtime);
        if (ctx->pc != ra)
            return;
        const uint32_t result = gpr32(ctx, 2);
        if (result)
            std::fprintf(stderr, "[asset] fetch req=[%d,%d] -> data=0x%X magic=%08X\n", slot, serial, result,
                         guest32(rdram, result));
    }

    void tracedLayerLoad(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t layer = gpr32(ctx, 4);
        const uint32_t before = guest32(rdram, layer + 0x40);
        const uint32_t ra = gpr32(ctx, 31);
        g_originalLayerLoad(rdram, ctx, runtime);
        if (!before && ctx->pc == ra)
        {
            const uint32_t data = guest32(rdram, layer + 0x20), image = guest32(rdram, layer + 0x24);
            std::fprintf(stderr, "[asset] layer '%s' loaded=%u data=0x%X magic=%08X image=0x%X wh=%08X\n",
                         guestString(rdram, guest32(rdram, layer + 0x18)).c_str(), guest32(rdram, layer + 0x40),
                         data, data ? guest32(rdram, data) : 0u, image, image ? guest32(rdram, image + 4) : 0u);
        }
    }

    // The game's debug print (an empty function in this build) used by CFILEBIG ("%s HEADER REQUEST",
    // "%s OK/FAIL"): shown with the asset trace. Only %s arguments in a1..a3 are expanded.
    void tracedDebugPrint(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        (void)runtime;
        const std::string format = guestString(rdram, gpr32(ctx, 4));
        std::string text;
        int arg = 5;
        for (size_t i = 0; i < format.size(); ++i)
        {
            if (format[i] == '%' && i + 1 < format.size() && format[i + 1] == 's' && arg <= 7)
            {
                text += guestString(rdram, gpr32(ctx, arg++));
                ++i;
            }
            else if (format[i] != '\n')
                text.push_back(format[i]);
        }
        std::fprintf(stderr, "[game] %s\n", text.c_str());
        ctx->pc = gpr32(ctx, 31);
    }

    // Hashed VIV index (.bh) loader and the game's malloc: logs index sizes and failed allocations.
    PS2Runtime::RecompiledFunction g_originalBhLoad = nullptr;
    PS2Runtime::RecompiledFunction g_originalMalloc = nullptr;

    void tracedBhLoad(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t object = gpr32(ctx, 4), name = gpr32(ctx, 5), ra = gpr32(ctx, 31);
        const std::string path = guestString(rdram, name);
        g_originalBhLoad(rdram, ctx, runtime);
        if (ctx->pc == ra)
            std::fprintf(stderr, "[asset] index '%s' data=0x%X size=%u\n", path.c_str(), guest32(rdram, object),
                         guest32(rdram, object + 4));
    }

    PS2Runtime::RecompiledFunction g_originalHeapAlloc = nullptr;

    // 0x00100828: alloc(size, heap, flags) from one of the game's heaps (FUN_00549e28 handles).
    void tracedHeapAlloc(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t size = gpr32(ctx, 4), heap = gpr32(ctx, 5), ra = gpr32(ctx, 31);
        g_originalHeapAlloc(rdram, ctx, runtime);
        if (ctx->pc == ra && gpr32(ctx, 2) == 0)
            std::fprintf(stderr, "[asset] heap alloc(%u, heap=0x%X) FAILED (caller 0x%X)\n", size, heap, ra);
    }
    void tracedMalloc(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t size = gpr32(ctx, 4), flags = gpr32(ctx, 5), ra = gpr32(ctx, 31);
        g_originalMalloc(rdram, ctx, runtime);
        if (ctx->pc == ra && gpr32(ctx, 2) == 0)
            std::fprintf(stderr, "[asset] malloc(%u, flags=0x%X) FAILED (caller 0x%X)\n", size, flags, ra);
    }

    void applyNbaStreetV3(PS2Runtime &runtime)
    {
        configureCdImage();
        if (envFlagSet("PS2X_NBA_ASSET_TRACE"))
        {
            g_originalBhLoad = runtime.lookupFunction(0x003C1AC8u);
            g_originalMalloc = runtime.lookupFunction(0x001008C0u);
            g_originalHeapAlloc = runtime.lookupFunction(0x00100828u);
            if (g_originalHeapAlloc)
                runtime.replaceFunction(0x00100828u, tracedHeapAlloc);
            if (g_originalBhLoad)
                runtime.replaceFunction(0x003C1AC8u, tracedBhLoad);
            if (g_originalMalloc)
                runtime.replaceFunction(0x001008C0u, tracedMalloc);
        }

        if (envFlagSet("PS2X_NBA_ASSET_TRACE"))
            runtime.replaceFunction(0x003C0A68u, tracedDebugPrint);
        if (envFlagSet("PS2X_NBA_ASSET_TRACE"))
        {
            g_originalAssetRequest = runtime.lookupFunction(0x003945E8u);
            g_originalAssetFetch = runtime.lookupFunction(0x00394AE8u);
            g_originalLayerLoad = runtime.lookupFunction(0x00392788u);
            if (g_originalAssetRequest)
                runtime.replaceFunction(0x003945E8u, tracedAssetRequest);
            if (g_originalAssetFetch)
                runtime.replaceFunction(0x00394AE8u, tracedAssetFetch);
            if (g_originalLayerLoad)
                runtime.replaceFunction(0x00392788u, tracedLayerLoad);
        }

        g_originalBootModuleLoader = runtime.lookupFunction(kBootModuleLoader);
        if (g_originalBootModuleLoader)
            runtime.replaceFunction(kBootModuleLoader, bootModuleLoaderWithOnlinePatch);

        g_originalAudioCallbackWalker = runtime.lookupFunction(kAudioCallbackWalker);
        if (g_originalAudioCallbackWalker && envFlagSet("PS2X_NBA_DISABLE_AUDIO_PLUGINS"))
        {
            runtime.replaceFunction(kAudioCallbackWalker, safeAudioCallbackWalker);
        }

        g_originalCallbackDispatch = runtime.lookupFunction(kCallbackDispatch);
        if (g_originalCallbackDispatch)
        {
            runtime.replaceFunction(kCallbackDispatch, nullSafeCallbackDispatch);
        }

        // The game runs its own malloc over the whole SetupHeap range. Without a private
        // runtime region, GS packets built by the runtime (sceGsPutDispEnv) landed on a game
        // mutex at 0x0069985C and deadlocked the main thread right after XLDSCRN.BIN loaded.
        ps2_game_overrides::setRuntimeHeapReserve(0x00100000u);

        struct Binding
        {
            uint32_t address;
            const char *handler;
        };
        static constexpr Binding kBindings[] = {
            {0x00544490u, "SifStopModule"},
            {0x00544728u, "sceSifSearchModuleByName"},
            {0x004C7178u, "sceCdSearchFile"},
            {0x004C6E60u, "sceCdSearchFile"},
            {0x004C8018u, "sceCdReadDvdDualInfo"},
            {0x004C8480u, "ret1"},  // sceMtapInit
            {0x004C86C0u, "ret1"},  // sceMtapPortOpen
            {0x004C8730u, "ret1"},  // sceMtapPortClose
            {0x004C87A0u, "ret0"},  // sceMtapGetConnection: no multitap
            {0x004C9B38u, "retm1"}, // sceUsbKbInit: no USB keyboard
            // sceSifGetSreg: the game's copy reads the EE kernel sreg array in guest RAM, but
            // IOP SET_SREG commands land in the runtime's SIF state.
            {0x00541680u, "sceSifGetSreg"},
            // sceSifFreeIopHeap: the game's copy only acts once its own sceSifInitIopHeap has
            // run (that one is runtime-HLE'd), so the 18 IRX images uploaded to IOP RAM were
            // never freed and EA's SND driver aborted with "COULDN'T ALLOCATE IOP MEMORY".
            {0x00544018u, "sceSifFreeIopHeap"},
        };

        for (const Binding &binding : kBindings)
        {
            if (!ps2_game_overrides::bindAddressHandler(runtime, binding.address, binding.handler))
            {
                std::cerr << "[NBA Street V3] could not bind 0x" << std::hex << binding.address << std::dec
                          << " to " << binding.handler << std::endl;
            }
        }
    }
}

PS2_REGISTER_GAME_OVERRIDE("NBA Street V3 (SLUS_211.26)", "SLUS_211.26", 0x00100008u, 0u, applyNbaStreetV3)

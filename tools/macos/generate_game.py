#!/usr/bin/env python3
"""
macOS/Linux version of tools/generate_game.ps1: generates the game's C++ code from YOUR copy of
NBA Street V3 (SLUS-21126) and leaves it ready to build. None of this goes into the repository: it
is a translation of the game's executable.

Prerequisites:
  - <root>/game/NBAStreetV3.iso  (your ISO)
  - <root>/game/iso/             (the extracted ISO; contains SLUS_211.26)
  - the recompiler built (tools/macos/build.sh recomp)

Steps: ps2_recomp (repository config with this machine's paths) -> game/output -> copy to
ps2xRuntime/src/runner and headers to ps2xRuntime/include -> fixes on the generated code (the
same as fix_sqrt_s / fix_branch64 / fix_cop0_count / fix_dnas_skip .ps1) -> game override.

Usage: generate_game.py [--root ~/NBAStreetRecomp]
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def configure(repo_config: Path, game: Path) -> Path:
    """Copies the recompiler config with the [general] paths pointing at this machine."""
    text = repo_config.read_text(encoding="utf-8")
    paths = {
        "input": game / "iso" / "SLUS_211.26",
        "output": game / "output",
        "ghidra_output": game / "config" / "functions.csv",
    }
    for key, value in paths.items():
        text, count = re.subn(rf'^{key} = ".*"$', f'{key} = "{value.as_posix()}"', text, count=1, flags=re.M)
        if count != 1:
            sys.exit(f"config.toml: no '{key} = ...' line")
    out = game / "config" / "config.toml"
    out.write_text(text, encoding="utf-8")
    return out


def cpp_files(directory: Path):
    return sorted(p for p in directory.iterdir() if p.suffix == ".cpp")


def fix_sqrt_s(directory: Path):
    """SQRT.S on the R5900 takes its operand from ft (bits 20..16), not fs."""
    comment = re.compile(r"^\s*// 0x[0-9a-fA-F]+: 0x([0-9a-fA-F]{1,8})\s")
    sqrt = re.compile(r"^(\s*)ctx->f\[(\d+)\] = FPU_SQRT_S\(ctx->f\[(\d+)\]\);\s*$")
    files = lines_fixed = 0
    for path in cpp_files(directory):
        text = path.read_text(encoding="utf-8", errors="surrogateescape")
        if "FPU_SQRT_S(" not in text:
            continue
        lines = text.split("\n")
        raw = None
        dirty = False
        for i, line in enumerate(lines):
            m = comment.match(line)
            if m:
                raw = int(m.group(1), 16)
                continue
            m = sqrt.match(line)
            if m and raw is not None:
                ft = (raw >> 16) & 31
                fd = (raw >> 6) & 31
                fixed = f"{m.group(1)}ctx->f[{fd}] = FPU_SQRT_S(ctx->f[{ft}]);"
                if fixed != line:
                    lines[i] = fixed
                    dirty = True
                    lines_fixed += 1
        if dirty:
            files += 1
            path.write_text("\n".join(lines), encoding="utf-8", errors="surrogateescape")
    print(f"  SQRT.S: {lines_fixed} lines in {files} files")


def fix_branch64(directory: Path):
    """BLEZ/BGTZ/BLTZ/BGEZ compare the whole 64-bit register on the R5900."""
    pattern = re.compile(r"(branch_taken_0x[0-9a-fA-F]+ = \()GPR_S32(\(ctx, \d+\) (?:<|>=|<=|>) 0\);)")
    files = branches = 0
    for path in cpp_files(directory):
        text = path.read_text(encoding="utf-8", errors="surrogateescape")
        if "GPR_S32(ctx, " not in text:
            continue
        text, count = pattern.subn(r"\1GPR_S64\2", text)
        if count:
            path.write_text(text, encoding="utf-8", errors="surrogateescape")
            files += 1
            branches += count
    print(f"  branch64: {branches} branches in {files} files")


def fix_cop0_count(directory: Path):
    """COP0 Count reads (mfc0 $9) update the clock right before reading it."""
    pattern = re.compile(r"^(\s*)SET_GPR_S32\(ctx, (\d+), \(int32_t\)ctx->cop0_count\);\s*$")
    files = reads = 0
    for path in cpp_files(directory):
        text = path.read_text(encoding="utf-8", errors="surrogateescape")
        if "(int32_t)ctx->cop0_count);" not in text:
            continue
        lines = text.split("\n")
        dirty = False
        for i, line in enumerate(lines):
            m = pattern.match(line)
            if m:
                lines[i] = (f"{m.group(1)}{{ extern void ps2UpdateCop0Count(R5900Context *); ps2UpdateCop0Count(ctx); "
                            f"SET_GPR_S32(ctx, {m.group(2)}, (int32_t)ctx->cop0_count); }}")
                dirty = True
                reads += 1
        if dirty:
            files += 1
            path.write_text("\n".join(lines), encoding="utf-8", errors="surrogateescape")
    print(f"  COP0 Count: {reads} reads in {files} files")


def fix_dnas_skip(directory: Path):
    """Skips DNAS authentication (Sony's servers are gone): DNASSKIP=0 -> 1 at 0x349968."""
    old = "SET_GPR_U64(ctx, 7, (uint64_t)GPR_U64(ctx, 0) + (uint64_t)GPR_U64(ctx, 0));"
    new = "SET_GPR_U64(ctx, 7, 1u); // ps2recomp: DNASSKIP=1 (was daddu $a3,$zero,$zero)"
    total = 0
    for path in cpp_files(directory):
        text = path.read_text(encoding="utf-8", errors="surrogateescape")
        if "0x349968: 0x382d" not in text:
            continue
        lines = text.split("\n")
        changed = 0
        for i in range(len(lines) - 1):
            if "0x349968: 0x382d" in lines[i] and lines[i + 1].strip() == old:
                lines[i + 1] = lines[i + 1].replace(old, new)
                changed += 1
        if changed:
            path.write_text("\n".join(lines), encoding="utf-8", errors="surrogateescape")
            total += changed
    print(f"  DNAS skip: {total}")
    if total == 0:
        print("  WARNING: the DNAS skip was not applied; online will stop at the DNAS check")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(Path.home() / "NBAStreetRecomp"))
    args = parser.parse_args()
    root = Path(args.root).expanduser()
    game = root / "game"

    elf = game / "iso" / "SLUS_211.26"
    if not elf.exists():
        sys.exit(f"Missing {elf}: extract your ISO into {game / 'iso'}")
    if not (game / "NBAStreetV3.iso").exists():
        print(f"WARNING: missing {game / 'NBAStreetV3.iso'} (the game reads disc sectors from it)")

    for sub in ("config", "output", "overrides"):
        (game / sub).mkdir(parents=True, exist_ok=True)
    for f in (REPO / "game" / "config").iterdir():
        shutil.copy2(f, game / "config" / f.name)
    for f in (REPO / "game" / "overrides").iterdir():
        shutil.copy2(f, game / "overrides" / f.name)
    config = configure(REPO / "game" / "config" / "config.toml", game)

    recomp = root / "PS2Recomp" / "out" / "build-mac" / "ps2xRecomp" / "ps2_recomp"
    if not recomp.exists():
        sys.exit(f"Missing {recomp}: build the recompiler (tools/macos/build.sh recomp)")
    print("Recompiling the ELF (takes a few minutes)...")
    subprocess.run([str(recomp), str(config)], check=True)

    runner = root / "PS2Recomp" / "ps2xRuntime" / "src" / "runner"
    include = root / "PS2Recomp" / "ps2xRuntime" / "include"
    print(f"Copying generated code to {runner}")
    runner.mkdir(parents=True, exist_ok=True)
    for f in (game / "output").iterdir():
        if f.suffix == ".cpp":
            shutil.copy2(f, runner / f.name)
        elif f.suffix == ".h":
            shutil.copy2(f, include / f.name)

    print("Fixes on the generated code:")
    fix_sqrt_s(runner)
    fix_branch64(runner)
    fix_cop0_count(runner)
    fix_dnas_skip(runner)

    shutil.copy2(REPO / "game" / "overrides" / "nba_street_v3_overrides.cpp", runner)
    print("Done. Now: tools/macos/build.sh game")


if __name__ == "__main__":
    main()

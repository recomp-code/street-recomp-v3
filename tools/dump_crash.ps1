<#
  Lee un minidump (.dmp) de Windows: excepcion, direccion que fallo, modulo, y las direcciones
  de retorno candidatas de la pila del hilo que fallo (resueltas con llvm-symbolizer + PDB).
  Uso: dump_crash.ps1 -Dump <archivo.dmp> [-Exe <exe con su .pdb>] [-StackWords 400]
#>
param([Parameter(Mandatory)][string]$Dump,
      [string]$Exe = "C:\NBAStreetRecomp\pcsx2\build\pcsx2-gsrunner\pcsx2-gsrunner.exe",
      [int]$StackWords = 400)
$ErrorActionPreference = "Stop"
Add-Type @"
using System; using System.IO; using System.Collections.Generic;
public static class MiniDump {
  public class Module { public ulong Base; public uint Size; public string Name; }
  public class Result { public uint Code; public ulong Address; public uint ThreadId; public ulong Rsp; public ulong Rip;
    public List<Module> Modules = new List<Module>(); public byte[] Stack; public ulong StackBase; }
  static uint U32(byte[] b, long o) { return BitConverter.ToUInt32(b, (int)o); }
  static ulong U64(byte[] b, long o) { return BitConverter.ToUInt64(b, (int)o); }
  public static Result Read(string path) {
    byte[] f = File.ReadAllBytes(path); var r = new Result();
    uint nStreams = U32(f, 8), dirRva = U32(f, 12);
    uint ctxRva = 0, ctxSize = 0; long threadList = -1;
    for (uint i = 0; i < nStreams; i++) {
      long d = dirRva + i * 12; uint type = U32(f, d), size = U32(f, d + 4), rva = U32(f, d + 8);
      if (type == 6) { // ExceptionStream
        r.ThreadId = U32(f, rva); r.Code = U32(f, rva + 8); r.Address = U64(f, rva + 8 + 16);
        ctxSize = U32(f, rva + 8 + 152); ctxRva = U32(f, rva + 8 + 156);
      } else if (type == 4) { // ModuleListStream
        uint n = U32(f, rva);
        for (uint m = 0; m < n; m++) {
          long e = rva + 4 + m * 108; var mod = new Module(); mod.Base = U64(f, e); mod.Size = U32(f, e + 8);
          uint nameRva = U32(f, e + 20); uint len = U32(f, nameRva);
          mod.Name = System.Text.Encoding.Unicode.GetString(f, (int)nameRva + 4, (int)len); r.Modules.Add(mod);
        }
      } else if (type == 3) threadList = rva;
    }
    if (ctxRva != 0 && ctxRva + 0x100 <= f.Length) { r.Rsp = U64(f, ctxRva + 0x98); r.Rip = U64(f, ctxRva + 0xF8); }
    if (threadList >= 0) {
      uint n = U32(f, threadList);
      for (uint t = 0; t < n; t++) {
        long e = threadList + 4 + t * 48;
        if (U32(f, e) != r.ThreadId) continue;
        ulong start = U64(f, e + 24); uint sz = U32(f, e + 32), rva = U32(f, e + 36);
        if (rva == 0 || (long)rva + sz > f.Length) continue;
        r.StackBase = start; r.Stack = new byte[sz]; Array.Copy(f, rva, r.Stack, 0, sz);
      }
    }
    return r;
  }
}
"@
$r = [MiniDump]::Read($Dump)
$sym = "C:\NBAStreetRecomp\tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin\llvm-symbolizer.exe"
$exeName = [IO.Path]::GetFileName($Exe)
$main = $r.Modules | Where-Object { $_.Name -like "*$exeName" } | Select-Object -First 1
function Resolve-Addr([uint64]$a) {
    $m = $r.Modules | Where-Object { $a -ge $_.Base -and $a -lt ($_.Base + $_.Size) } | Select-Object -First 1
    if (-not $m) { return "0x{0:X} (?)" -f $a }
    $off = $a - $m.Base
    if ($main -and $m.Base -eq $main.Base) {
        $line = (& $sym --obj=$Exe --relative-address --functions=linkage --demangle ("0x{0:X}" -f $off) | Select-Object -First 2) -join " @ "
        return "{0}+0x{1:X}  {2}" -f [IO.Path]::GetFileName($m.Name), $off, $line
    }
    return "{0}+0x{1:X}" -f [IO.Path]::GetFileName($m.Name), $off
}
"excepcion 0x{0:X8} en {1}" -f $r.Code, (Resolve-Addr $r.Address)
"hilo {0} rip {1}" -f $r.ThreadId, (Resolve-Addr $r.Rip)
if ($r.Stack -and $main) {
    "--- direcciones del exe en la pila (desde RSP) ---"
    $startOff = [int]($r.Rsp - $r.StackBase); if ($startOff -lt 0) { $startOff = 0 }
    $count = 0
    for ($o = $startOff; $o + 8 -le $r.Stack.Length -and $count -lt $StackWords; $o += 8) {
        $v = [BitConverter]::ToUInt64($r.Stack, $o); $count++
        if ($v -ge $main.Base -and $v -lt ($main.Base + $main.Size)) { "  [rsp+0x{0:X}] {1}" -f ($o - $startOff), (Resolve-Addr $v) }
    }
}

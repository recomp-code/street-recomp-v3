<#
  Pilas de todos los hilos de un proceso vivo (p.ej. un pcsx2-gsrunner colgado): suspende cada
  hilo, lee RIP/RSP y las direcciones del exe que hay en su pila, y las resuelve con
  llvm-symbolizer + PDB. No modifica nada (reanuda los hilos).
  Uso: stack_snapshot.ps1 -ProcessId <pid> [-Exe <exe con .pdb>] [-Words 256]
#>
param([Parameter(Mandatory)][int]$ProcessId,
      [string]$Exe = "C:\NBAStreetRecomp\pcsx2\build\pcsx2-gsrunner\pcsx2-gsrunner.exe",
      [int]$Words = 256)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Snap {
  [DllImport("kernel32")] public static extern IntPtr OpenProcess(uint a, bool i, int pid);
  [DllImport("kernel32")] public static extern IntPtr OpenThread(uint a, bool i, int tid);
  [DllImport("kernel32")] public static extern uint SuspendThread(IntPtr h);
  [DllImport("kernel32")] public static extern uint ResumeThread(IntPtr h);
  [DllImport("kernel32")] public static extern bool GetThreadContext(IntPtr h, IntPtr ctx);
  [DllImport("kernel32")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr r);
  [DllImport("kernel32")] public static extern bool CloseHandle(IntPtr h);
  public static ulong[] Regs(IntPtr thread) {
    IntPtr raw = Marshal.AllocHGlobal(1232 + 16);
    IntPtr ctx = new IntPtr((raw.ToInt64() + 15) & ~15L);
    for (int i = 0; i < 1232; i += 4) Marshal.WriteInt32(ctx, i, 0);
    Marshal.WriteInt32(ctx, 0x30, 0x100001); // CONTEXT_CONTROL (AMD64)
    ulong[] r = null;
    if (GetThreadContext(thread, ctx)) r = new ulong[] { (ulong)Marshal.ReadInt64(ctx, 0xF8), (ulong)Marshal.ReadInt64(ctx, 0x98) };
    Marshal.FreeHGlobal(raw); return r;
  }
}
"@
$proc = Get-Process -Id $ProcessId
$main = $proc.MainModule; $base = [uint64]$main.BaseAddress; $size = [uint64]$main.ModuleMemorySize
$hp = [Snap]::OpenProcess(0x0410, $false, $ProcessId)
$sym = "C:\NBAStreetRecomp\tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin\llvm-symbolizer.exe"
function Resolve([uint64]$a) {
    if ($a -lt $base -or $a -ge $base + $size) { return $null }
    $r = & $sym --obj=$Exe --relative-address --demangle --functions=short ("0x{0:X}" -f ($a - $base)) | Select-Object -First 1
    if ($r -eq '??') { return $null } else { return $r }
}
foreach ($t in $proc.Threads) {
    $ht = [Snap]::OpenThread(0x005A, $false, $t.Id)
    if ($ht -eq [IntPtr]::Zero) { continue }
    [void][Snap]::SuspendThread($ht)
    $regs = [Snap]::Regs($ht)
    $stack = New-Object byte[] ($Words * 8)
    $ok = $false
    if ($regs) { $read = [IntPtr]::Zero; $ok = [Snap]::ReadProcessMemory($hp, [IntPtr][int64]$regs[1], $stack, $stack.Length, [ref]$read) }
    [void][Snap]::ResumeThread($ht); [void][Snap]::CloseHandle($ht)
    if (-not $regs) { continue }
    $frames = New-Object System.Collections.Generic.List[string]
    $rip = Resolve $regs[0]; if ($rip) { $frames.Add("rip: $rip") }
    if ($ok) {
        for ($o = 0; $o -lt $stack.Length -and $frames.Count -lt 14; $o += 8) {
            $v = [BitConverter]::ToUInt64($stack, $o); $f = Resolve $v
            if ($f -and -not $frames.Contains($f)) { $frames.Add($f) }
        }
    }
    "== hilo $($t.Id) ($($t.ThreadState)/$($t.WaitReason))"
    $frames | ForEach-Object { "   $_" }
}
[void][Snap]::CloseHandle($hp)

<#
  Descomprime archivos EA RefPack (cabecera 10 FB, p.ej. los IRX de MODULES.VIV).
  Uso: refpack_unpack.ps1 -In <archivo> -Out <archivo>
#>
param([Parameter(Mandatory)][string]$In, [Parameter(Mandatory)][string]$Out)
Add-Type @"
public static class RefPack {
  public static byte[] Unpack(byte[] s) {
    int p = 0;
    int flags = (s[0] << 8) | s[1]; p = 2;
    if ((flags & 0xFF) != 0xFB) throw new System.Exception("not refpack");
    bool big = (flags & 0x8000) != 0; int sz = big ? 4 : 3;
    if ((flags & 0x0100) != 0) p += sz; // compressed size present
    int outLen = 0; for (int i = 0; i < sz; i++) outLen = (outLen << 8) | s[p++];
    byte[] d = new byte[outLen]; int o = 0;
    while (p < s.Length) {
      int b0 = s[p++]; int lit, copy, off;
      if ((b0 & 0x80) == 0) { int b1 = s[p++]; lit = b0 & 3; copy = ((b0 & 0x1C) >> 2) + 3; off = ((b0 & 0x60) << 3) + b1 + 1; }
      else if ((b0 & 0x40) == 0) { int b1 = s[p++], b2 = s[p++]; lit = b1 >> 6; copy = (b0 & 0x3F) + 4; off = ((b1 & 0x3F) << 8) + b2 + 1; }
      else if ((b0 & 0x20) == 0) { int b1 = s[p++], b2 = s[p++], b3 = s[p++]; lit = b0 & 3; copy = ((b0 & 0x0C) << 6) + b3 + 5; off = ((b0 & 0x10) << 12) + (b1 << 8) + b2 + 1; }
      else { lit = ((b0 & 0x1F) << 2) + 4; if (lit > 0x70) { lit = b0 & 3; for (int i = 0; i < lit; i++) d[o++] = s[p++]; break; } copy = 0; off = 0; }
      for (int i = 0; i < lit; i++) d[o++] = s[p++];
      for (int i = 0; i < copy; i++) { d[o] = d[o - off]; o++; }
    }
    return d;
  }
}
"@
[IO.File]::WriteAllBytes($Out, [RefPack]::Unpack([IO.File]::ReadAllBytes($In)))
"{0} -> {1} ({2} bytes)" -f $In, $Out, (Get-Item $Out).Length

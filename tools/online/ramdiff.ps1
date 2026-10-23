# Compares two EE RAM dumps (PS2X_DETDUMPDIR): per 64 KB block, how many bytes differ, and (-Detail) the differing
# words of the first blocks.
param([string]$A, [string]$B, [int]$Detail = 0)
if (-not ('RamDiff2' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text;
public static class RamDiff2 {
  public static string Run(string a, string b, int detail) {
    var x = File.ReadAllBytes(a); var y = File.ReadAllBytes(b); var sb = new StringBuilder(); int blocks = 0, shown = 0;
    for (int blk = 0; blk < x.Length / 65536; blk++) {
      int diff = 0, first = -1, last = -1;
      for (int i = blk * 65536; i < (blk + 1) * 65536; i++) if (x[i] != y[i]) { diff++; if (first < 0) first = i; last = i; }
      if (diff == 0) continue;
      blocks++;
      sb.AppendFormat("0x{0:X7}: {1,6} bytes differ, first 0x{2:X7} last 0x{3:X7}\n", blk * 65536, diff, first, last);
      for (int i = first & ~3; i <= last && shown < detail; i += 4) {
        uint u = BitConverter.ToUInt32(x, i), v = BitConverter.ToUInt32(y, i);
        if (u != v) { sb.AppendFormat("    0x{0:X7}: {1:X8} | {2:X8}\n", i, u, v); shown++; }
      }
    }
    sb.AppendFormat("{0} blocks of 64 KB differ\n", blocks);
    return sb.ToString();
  }
}
'@
}
[RamDiff2]::Run($A, $B, $Detail)

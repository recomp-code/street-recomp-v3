<#
  Copia las texturas volcadas por el juego (menu START largo -> Texturas HD -> "Activadas + volcar originales")
  a C:\NBAStreetRecomp\texturas_hd\originales, quitando:
   - los fotogramas de video (tiras de 16x512 que el MPEG sube cada frame),
   - las capturas dinamicas de memoria de video: texturas SIN paleta (nombre con 2 campos) cuyo
     contenido parece ruido. Son copias de pantalla/datos que el juego reescribe cada frame; si se
     reemplazan, el juego mezcla una imagen vieja y todo el menu sale con grano (caso real:
     e30f7fa96ac7861c-00001d80, 64x128). Van a texturas_hd\descartadas por si quieres revisarlas.
   - las invisibles (alfa maximo <= 3): datos volcados con una paleta que no es la suya (caso real:
     942 paginas con la paleta 334e9e57...); reemplazarlas estropeaba los iconos de botones.
   - las ya copiadas. Se puede ejecutar tantas veces como quieras: solo anade las nuevas.
  Uso: texturas_preparar.ps1 [-NoiseLimit 20]
#>
param([double]$NoiseLimit = 20)
$dumps = "$env:USERPROFILE\Documents\PCSX2\textures\SLUS-21126\dumps"
$out = "C:\NBAStreetRecomp\texturas_hd\originales"
$discard = "C:\NBAStreetRecomp\texturas_hd\descartadas"
New-Item -ItemType Directory -Force $out, $discard | Out-Null
Add-Type -AssemblyName System.Drawing
if (-not ('TexHf' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class TexHf {
  // Diferencia media entre pixeles vecinos (opacos) tras ampliar 4x: alta = parece ruido.
  public static double Measure(string f){
    using(var a=new Bitmap(f)) using(var up=new Bitmap(a.Width*4,a.Height*4,PixelFormat.Format32bppArgb)){
      using(var g=Graphics.FromImage(up)){ g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic; g.DrawImage(a,0,0,up.Width,up.Height); }
      var d=up.LockBits(new Rectangle(0,0,up.Width,up.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var p=new byte[d.Stride*up.Height]; Marshal.Copy(d.Scan0,p,0,p.Length); int s=d.Stride; up.UnlockBits(d);
      double t=0; long n=0; for(int y=0;y<up.Height;y++) for(int x=1;x<up.Width;x++){ int i=y*s+x*4; if(p[i+3]<8) continue; t+=Math.Abs(p[i]-p[i-4])+Math.Abs(p[i+1]-p[i-3])+Math.Abs(p[i+2]-p[i-2]); n++; }
      return n==0?0:t/n; } }
  public static int MaxAlpha(string f){
    using(var a=new Bitmap(f)){ var d=a.LockBits(new Rectangle(0,0,a.Width,a.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var p=new byte[d.Stride*a.Height]; Marshal.Copy(d.Scan0,p,0,p.Length); a.UnlockBits(d); int m=0; for(int i=3;i<p.Length;i+=4) if(p[i]>m) m=p[i]; return m; } } }
'@
}
$buf = New-Object byte[] 24
$copied = 0; $video = 0; $skipped = 0; $dynamic = 0; $invisible = 0
foreach ($f in [IO.Directory]::EnumerateFiles($dumps, '*.png')) {
    $name = [IO.Path]::GetFileName($f)
    $fs = [IO.File]::OpenRead($f); [void]$fs.Read($buf, 0, 24); $fs.Close()
    $w = ([int]$buf[16] -shl 24) -bor ([int]$buf[17] -shl 16) -bor ([int]$buf[18] -shl 8) -bor [int]$buf[19]
    $h = ([int]$buf[20] -shl 24) -bor ([int]$buf[21] -shl 16) -bor ([int]$buf[22] -shl 8) -bor [int]$buf[23]
    # Fotogramas de video: tiras de 16 px de ancho (CLUT/sufijo 00002500).
    if ($w -eq 16 -and $h -eq 512) { $video++; continue }
    $dest = Join-Path $out $name
    if ((Test-Path $dest) -or (Test-Path (Join-Path $discard $name))) { $skipped++; continue }
    $noPalette = ([IO.Path]::GetFileNameWithoutExtension($name).Split('-').Count -eq 2)
    if ($noPalette -and [TexHf]::Measure($f) -ge $NoiseLimit) { Copy-Item $f (Join-Path $discard $name); $dynamic++; continue }
    if ([TexHf]::MaxAlpha($f) -le 3) { Copy-Item $f (Join-Path $discard $name); $invisible++; continue }
    Copy-Item $f $dest
    $copied++
}
"copiadas: $copied   ya estaban: $skipped   video descartado: $video   capturas dinamicas descartadas: $dynamic   invisibles descartadas: $invisible"
"carpeta: $out"

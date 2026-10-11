# Mide el "grano" (diferencia media entre pixeles vecinos) en zonas fijas de una captura del menu
# principal (1280x960): fondo del panel y fondo de la foto. Uso: shot_noise.ps1 <png>
param([string]$Png, [string]$Ref = "C:\NBAStreetRecomp\logs\menu_clean.png")
Add-Type -AssemblyName System.Drawing
if (-not ('ShotNoise' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class ShotNoise {
  public static double Hf(string f, int x0, int y0, int w, int h){
    using(var b=new Bitmap(f)){ var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var p=new byte[d.Stride*b.Height]; Marshal.Copy(d.Scan0,p,0,p.Length); int s=d.Stride; b.UnlockBits(d);
      double t=0; long n=0; for(int y=y0;y<y0+h;y++) for(int x=x0+1;x<x0+w;x++){ int i=y*s+x*4; t+=Math.Abs(p[i]-p[i-4])+Math.Abs(p[i+1]-p[i-3])+Math.Abs(p[i+2]-p[i-2]); n++; }
      return t/n; } }
  public static double Diff(string f, string r, int x0, int y0, int w, int h){
    using(var a=new Bitmap(f)) using(var b=new Bitmap(r)){ var da=a.LockBits(new Rectangle(0,0,a.Width,a.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb); var db=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var pa=new byte[da.Stride*a.Height]; var pb=new byte[db.Stride*b.Height]; Marshal.Copy(da.Scan0,pa,0,pa.Length); Marshal.Copy(db.Scan0,pb,0,pb.Length); int s=da.Stride; a.UnlockBits(da); b.UnlockBits(db);
      double t=0; long n=0; for(int y=y0;y<y0+h;y++) for(int x=x0;x<x0+w;x++){ int i=y*s+x*4; t+=Math.Abs(pa[i]-pb[i])+Math.Abs(pa[i+1]-pb[i+1])+Math.Abs(pa[i+2]-pb[i+2]); n++; }
      return t/n/3; } } }
'@
}
$panel = [ShotNoise]::Hf($Png, 700, 640, 300, 200)
$photo = [ShotNoise]::Hf($Png, 60, 40, 300, 150)
$icons = [ShotNoise]::Diff($Png, $Ref, 100, 860, 1100, 60)
$ball = [ShotNoise]::Diff($Png, $Ref, 150, 360, 75, 80)
"{0:F1};{1:F1};{2:F1};{3:F1}" -f $panel, $photo, $icons, $ball

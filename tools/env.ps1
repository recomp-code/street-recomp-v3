$T = "C:\NBAStreetRecomp\tools"
$env:JAVA_HOME = "$T\jdk\jdk-21.0.12.1+1"
$env:Path = "$T\mingit\cmd;$T\cmake\cmake-4.4.4-windows-x86_64\bin;$env:JAVA_HOME\bin;C:\Program Files\7-Zip;" + $env:Path

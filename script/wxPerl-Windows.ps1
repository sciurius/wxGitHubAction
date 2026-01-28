# PowerShell script to install and verify wxWidgets.

################ Parameters ################

param (
  [ Parameter ( HelpMessage = "The desired wxWidgets version" ) ]
  [ string ] $wxv = "3.2.9",
  [ Parameter ( HelpMessage = "The target location for wxWidgets" ) ]
  [ string ] $wxdir = "C:\wxWidgets-$wxv",
  [ Parameter ( HelpMessage = "The desired Strawberry Perl version" ) ]
  [ string ] $spv = "5.42.0.1",
  [ Parameter ( HelpMessage = "The desired Strawberry Perl version" ) ]
  [ string ] $spsp = "SP_54201_64bit",
  [ Parameter ( HelpMessage = "The target location for Strawberry Perl" ) ]
  [ string ] $spdir = "C:\Strawberry-$spv",
  [ Parameter ( HelpMessage = "The desired Alien::wxWidgets version" ) ]
  [ string ] $awv = "0.73",
  [ Parameter ( HelpMessage = "The desired wxPerl version" ) ]
  [ string ] $wxperlv = "3.009"
)

################ Functions ################

Function msg {
    param ( [string]$msg )
    Write-Host $msg
}

Function Fetch-Kit {
    param ( [uri]$uri )
    $kit = $uri.Segments[-1];
    if ( Test-Path -path $kit ) {
	msg "Found $kit, skipping dowload"
    }
    else {
	msg "Downloading $uri..."
	Invoke-WebRequest -Uri $uri -OutFile $kit
    }
    $kit
}

Function Add-PathVariable {
    param ( [string]$addPath )
    if ( Test-Path $addPath ) {
        $regexAddPath = [regex]::Escape($addPath)
        $arrPath = $env:Path -split ';' | Where-Object {$_ -notMatch "^$regexAddPath\\?"}
        $env:Path = ($arrPath + $addPath) -join ';'
    }
    else {
        Throw "'$addPath' is not a valid path."
    }
}

################ Main ################

if ( 1 ) {
    msg "Install 7zip (local)"
    $kit = Fetch-Kit "https://www.7-zip.org/a/7zr.exe"
    $7z = Get-Command ".\$kit"
}

if ( Test-Path -path $wxdir ) {
    msg "Found $wxdir, skipping wxWidgets install"
    $wxskip = 1
}
else {
    msg "Installing wxWidgets $wxv in $wxdir"
    $wxskip = 0

    mkdir -path $wxdir

    msg "Add wxWidgets (Source)"
    $kit = Fetch-Kit "https://github.com/wxWidgets/wxWidgets/releases/download/v3.2.9/wxWidgets-3.2.9.7z"

    &$7z x "-o$wxdir" $kit

    msg "Add Webview2"
    $kit = Fetch-Kit  -Uri "https://globalcdn.nuget.org/packages/microsoft.web.webview2.1.0.2420.47.nupkg"

    mkdir "$wxdir/3rdparty/webview2"
    &$7z x "-o$wxdir/3rdparty/webview2" -aoa $kit
}

if ( Test-Path -path $spdir ) {
    msg "Found $spdir, skipping Strawberry Perl install"
}
else {
    msg "Installing Strawberry Perl $spv in $spdir"

    mkdir -path $spdir

    msg "Add Strawberry Perl"
    $kit = Fetch-Kit -Uri "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/$spsp/strawberry-perl-$spv-64bit-portable.zip"

    &$7z x "-o$spdir" -aoa $kit

    msg "Add Strawberry Perl to PATH"
    Add-PathVariable "$spdir\c\bin"
    Add-PathVariable "$spdir\perl\site\bin"
    Add-PathVariable "$spdir\perl\bin"
}

if ( $wxskip -eq 0 ) {
    msg "Build wxWidgets"
    Push-Location $wxdir/build/msw
    gmake -f makefile.gcc BUILD=release SHARED=1 setup_h
    perl -pi -e 's/wxUSE_WEBVIEW_IE \K1/0/;' -e 's/wxUSE_WEBVIEW_EDGE \K0/1/;' ../../lib/gcc_dll/mswu/wx/setup.h
    gmake -f makefile.gcc BUILD=release SHARED=1
    Pop-Location

    msg "Add wxWidgets to PATH"
    Add-PathVariable "$wxdir\lib\gcc_dll"

    msg "Build minimal sample"
    Push-Location $wxdir/samples/minimal
    gmake -f makefile.gcc BUILD=release SHARED=1
    Pop-Location
}

if ( 1 ) {
    msg "Add Alien::wxWidgets"
    $kit = Fetch-Kit -Uri "https://github.com/sciurius/perl-Alien-wxWidgets/releases/download/R$awv/Alien-wxWidgets-$awv.tar.gz"
    tar xf $kit
    Push-Location Alien-wxWidgets-$awv
    # With a pre-built wxWidgets (headers + libs only) Alien::wxWidgets cannot configure.
    mkdir $spdir/perl/site/lib/Alien/wxWidgets/Config
    copy lib/Alien/wxWidgets.pm $spdir/perl/site/lib/Alien
    copy lib/Alien/wxWidgets/Utility.pm $spdir/perl/site/lib/Alien/wxWidgets
    perl script/make_cfg.pl "--wxdir=$wxdir" "--output=%{sitelib}/%{alien_config}"
    Pop-Location
    rm -r Alien-wxWidgets-$awv
    # Verify install.
    perl -MAlien::wxWidgets -E "say Alien::wxWidgets->prefix"
}

if ( 1 ) {
    msg "Add wxPerl"
    $kit = Fetch-Kit -Uri "https://github.com/sciurius/wxPerl/releases/download/R$wxperlv/Wx-$wxperlv.tar.gz"
    tar xf $kit
    Push-Location Wx-$wxperlv
    cpanm ExtUtils::XSpp::Cmd
    perl Makefile.PL
    gmake
    perl -Mblib -MWx -E 'say $Wx::VERSION'
    gmake install
    Pop-Location
    rm -r -force Wx-$wxperlv
}

echo "Test wxPerl"
perl -MWx -E 'say join(q{ },$Wx::VERSION,$Wx::wxVERSION)'

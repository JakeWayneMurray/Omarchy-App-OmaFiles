pkgname=omarchy-app-omafiles
pkgver=0.1.0
pkgrel=1
pkgdesc='Omarchy-styled keyboard-first file manager'
arch=('any')
url='https://github.com/JakeWayneMurray/Omarchy-App-OmaFiles'
license=('MIT')
depends=('quickshell' 'python' 'file' 'poppler')
optdepends=('localsend: send selected files and folders over the local network')
source=()
sha256sums=()

package() {
  local appdir="$pkgdir/usr/share/$pkgname"
  install -dm755 "$appdir"
  install -Dm644 "$startdir/App.qml" "$appdir/App.qml"
  install -Dm755 "$startdir/quatro_files.py" "$appdir/quatro_files.py"
  install -Dm755 "$startdir/run.sh" "$appdir/run.sh"
  install -Dm755 "$startdir/omafiles" "$pkgdir/usr/bin/omafiles"
  install -Dm644 "$startdir/README.md" "$appdir/README.md"
  ln -s /usr/share/omarchy/shell/Commons "$appdir/Commons"
  ln -s /usr/share/omarchy/shell/Ui "$appdir/Ui"
  install -dm755 "$pkgdir/usr/share/applications"
  install -Dm644 "$startdir/omafiles.desktop" "$pkgdir/usr/share/applications/omafiles.desktop"
}

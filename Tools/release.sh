#!/usr/bin/env bash
#
# Build a distributable daily_log.app, zip it, and render the Homebrew cask.
#
# No Apple Developer account is involved. The app is ad-hoc signed (`-`), which
# is all macOS requires to *execute* it; the Gatekeeper prompt people associate
# with unsigned apps comes from the quarantine xattr on the download, and
# `brew install --cask --no-quarantine` never attaches one. The trade is that
# the code signature changes on every build, so macOS may treat an upgrade as a
# different app and re-ask for notification permission.
#
# Usage:
#   Tools/release.sh              build + zip + render the cask into build/release
#   Tools/release.sh --publish    also create the GitHub release and upload the zip
#
# Env:
#   SKIP_TESTS=1    skip the test run that otherwise gates the build
#   ALLOW_DIRTY=1   build from a dirty working tree

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROJECT=daily_log.xcodeproj
SCHEME=daily_log
APP=daily_log.app
OUT=build/release
PUBLISH=0

for arg in "$@"; do
	case "$arg" in
		--publish) PUBLISH=1 ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

if [[ -z "${ALLOW_DIRTY:-}" && -n "$(git status --porcelain)" ]]; then
	echo "working tree is dirty — commit first, or set ALLOW_DIRTY=1" >&2
	exit 1
fi

if [[ -z "${SKIP_TESTS:-}" ]]; then
	echo "==> tests"
	xcodebuild test -project "$PROJECT" -scheme "$SCHEME" \
		-destination 'platform=macOS' -quiet
fi

echo "==> build (Release, universal, ad-hoc signed)"
rm -rf "$OUT"
mkdir -p "$OUT"
xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
	-destination 'generic/platform=macOS' \
	CONFIGURATION_BUILD_DIR="$PWD/$OUT" \
	ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_STYLE=Manual \
	CODE_SIGN_IDENTITY=- \
	DEVELOPMENT_TEAM="" \
	-quiet

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
	"$OUT/$APP/Contents/Info.plist")
TAG="v$VERSION"
ZIP="$OUT/daily_log-$VERSION.zip"

# Cheap sanity check: the bundle is signed and the signature covers what it
# claims to. This will not pass `spctl -a` and is not meant to — that needs
# notarization, which needs a paid Developer ID.
codesign --verify --strict "$OUT/$APP"
lipo -archs "$OUT/$APP/Contents/MacOS/daily_log"

echo "==> package"
ditto -c -k --keepParent "$OUT/$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

sed -e '/^#!/d' -e "s/@VERSION@/$VERSION/g" -e "s/@SHA256@/$SHA/g" \
	Tools/daily-log.rb.tmpl > "$OUT/daily-log.rb"

echo
echo "    app     $OUT/$APP"
echo "    zip     $ZIP"
echo "    sha256  $SHA"
echo "    cask    $OUT/daily-log.rb"
echo

if [[ $PUBLISH -eq 1 ]]; then
	echo "==> publish $TAG"
	# --target pins the tag to the commit that was actually built. Without it
	# `gh` tags the default branch, which is only right by coincidence.
	#
	# The cask rides along as an asset so the tap can be updated from the
	# release itself, without re-running this script to regenerate it.
	gh release create "$TAG" "$ZIP" "$OUT/daily-log.rb" \
		--title "$TAG" --generate-notes \
		--target "$(git rev-parse HEAD)"
	echo
	echo "Now copy $OUT/daily-log.rb into homebrew-tap/Casks/ and commit it."
else
	cat <<-EOF
	Nothing was published. To ship this build:

	    Tools/release.sh --publish

	then copy $OUT/daily-log.rb into your tap's Casks/ directory and commit.
	EOF
fi

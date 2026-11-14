#!/bin/bash
# Publishes the iPhone install with the Apple Watch app (ipa, manifest.plist, index.html, icons) to https://cdn.kw.at/elementx/.
#
#   ./deploy.sh        builds it (Tools/Distribution/build-ota.sh into build/ota) and shows what an upload would
#                      change: a dry run, nothing on the server changes.
#   ./deploy.sh --go   uploads exactly that build, without building again, so what goes up is what the dry
#                      run showed. Run ./deploy.sh first. It refuses when the build isn't the one the dry
#                      run made within the last hour, or isn't the build number project.yml names now.
#
# Bump CURRENT_PROJECT_VERSION in project.yml before building, or installed devices won't see an update.
# The server's files belong to cdn-deploy:www-data, and cdn-deploy can't change files it doesn't own, so rsync
# keeps no owner, group, permissions or directory times. Always look at the dry run before --go.
set -euo pipefail
cd "$(dirname "$0")"

SRC="./build/ota/"
# What the dry run built: build number, the ipa's checksum and the time. Beside the folder, so it isn't uploaded.
STAMP="./build/ota.stamp"
STAMP_MAX_AGE=3600

build_number() { sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\{0,1\}\([0-9][0-9.]*\)"\{0,1\} *$/\1/p' project.yml | head -1; }
checksum() { shasum -a 256 "$1" | cut -d' ' -f1; }
DEST="cdn-kw:/var/www/cdn.kw.at/elementx/"

# Only ever a folder of its own under the CDN root, which holds many unrelated projects.
if [[ ! "$DEST" =~ ^cdn-kw:/var/www/cdn\.kw\.at/[A-Za-z0-9._-]+/$ ]] || [[ "$DEST" == *"/../"* ]] || [[ "$DEST" == *"/./"* ]]; then
  echo "error: DEST must be a subfolder of /var/www/cdn.kw.at/, not the CDN root or anything else: $DEST" >&2
  exit 1
fi

case "${1:-}" in
  --go) MODE=go ;;
  "") MODE=dry ;;
  *) echo "usage: ./deploy.sh [--go]" >&2; exit 2 ;;
esac

if [[ "$MODE" == dry ]]; then
  # From nothing: whatever an earlier build left in the folder would be uploaded with this one.
  rm -rf "$SRC" "$STAMP"
  Tools/Distribution/build-ota.sh "$SRC"
fi

if [[ ! -d "$SRC" ]] || [[ -z "$(ls -A "$SRC")" ]]; then
  echo "error: $SRC is missing or empty. Run ./deploy.sh (without --go) first: it builds and shows the dry run." >&2
  exit 1
fi
for file in ElementX.ipa manifest.plist index.html; do
  [[ -s "$SRC$file" ]] || { echo "error: $SRC$file is missing; the build didn't finish." >&2; exit 1; }
done

if [[ "$MODE" == go ]]; then
  # Only the build the dry run showed: not one from another day, and not one from before a version bump.
  [[ -s "$STAMP" ]] || { echo "error: no dry run on record. Run ./deploy.sh first, look at what it shows, then --go." >&2; exit 1; }
  read -r STAMP_BUILD STAMP_SUM STAMP_TIME < "$STAMP"
  AGE=$(( $(date +%s) - STAMP_TIME ))
  if (( AGE > STAMP_MAX_AGE )); then
    echo "error: the dry run is $(( AGE / 60 )) minutes old. Run ./deploy.sh again and upload what it shows." >&2; exit 1
  fi
  if [[ "$STAMP_BUILD" != "$(build_number)" ]]; then
    echo "error: project.yml now says build $(build_number), the dry run built $STAMP_BUILD. Run ./deploy.sh again." >&2; exit 1
  fi
  if [[ "$STAMP_SUM" != "$(checksum "${SRC}ElementX.ipa")" ]]; then
    echo "error: ElementX.ipa is not the file the dry run built. Run ./deploy.sh again." >&2; exit 1
  fi
fi

OPTIONS=(-rltvz --omit-dir-times --no-perms --delete --exclude=.git --exclude=.DS_Store)
if [[ "$MODE" == dry ]]; then
  echo "--- dry run: nothing changes on the server. ./deploy.sh --go uploads this build."
  rsync "${OPTIONS[@]}" --dry-run "$SRC" "$DEST"
  echo "$(build_number) $(checksum "${SRC}ElementX.ipa") $(date +%s)" > "$STAMP"
  echo "--- build $(build_number). ./deploy.sh --go uploads exactly this within the next hour."
else
  rsync "${OPTIONS[@]}" "$SRC" "$DEST"
  rm -f "$STAMP"
  echo "--- deployed build $STAMP_BUILD to https://cdn.kw.at/elementx/"
fi

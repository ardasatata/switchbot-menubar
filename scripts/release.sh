#!/bin/bash
#
# release.sh — bump MARKETING_VERSION, commit, and tag a release.
#
# Usage: ./scripts/release.sh 1.1.0
#
# Pushing the resulting tag (printed at the end, not run automatically)
# triggers .github/workflows/release.yml, which builds, packages, and
# publishes the GitHub Release.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PBXPROJ="switch-bot-menu-bar.xcodeproj/project.pbxproj"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>   (e.g. $0 1.1.0)" >&2
  exit 1
fi

VERSION="$1"
TAG="v$VERSION"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "error: version must look like X.Y or X.Y.Z (got '$VERSION')" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is dirty — commit or stash your changes first" >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists" >&2
  exit 1
fi

BEFORE=$(grep -c "MARKETING_VERSION = " "$PBXPROJ")
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
AFTER=$(grep -c "MARKETING_VERSION = $VERSION;" "$PBXPROJ")

if [ "$AFTER" -ne 6 ] || [ "$AFTER" -ne "$BEFORE" ]; then
  echo "error: expected to update exactly 6 MARKETING_VERSION entries, updated $AFTER (found $BEFORE before)" >&2
  echo "       check $PBXPROJ manually — it may be in a partially-edited state." >&2
  exit 1
fi

git add "$PBXPROJ"
git commit -m "chore: release $TAG"
git tag -a "$TAG" -m "Release $TAG"

echo ""
echo "Done. Review the commit, then push it and the tag:"
echo ""
echo "  git push origin main --follow-tags"
echo ""
echo "Pushing the tag triggers the Release workflow, which builds, packages, and"
echo "publishes v$VERSION to GitHub Releases."

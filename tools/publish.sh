#!/usr/bin/env bash
# Publishes this project into the build repo so GitHub Actions produces an unsigned IPA.
#
#   bash tools/publish.sh                                  # default remote, branch main
#   bash tools/publish.sh git@github.com:You/repo.git      # custom remote
#
# Needs your own git credentials: GitHub will ask for a browser login or a PAT
# the first time you push. Nothing is deleted; this only adds and commits files.
set -euo pipefail

REMOTE="${1:-https://github.com/StayModding/wow.lolv2.git}"
BRANCH="main"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

command -v git >/dev/null 2>&1 || { echo "git is not installed."; exit 1; }

if [ ! -d .git ]; then
  echo "-> initialising a git repository in $PROJECT_ROOT"
  git init -b "$BRANCH" >/dev/null
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi
echo "-> remote origin = $REMOTE"

if ! git config user.email >/dev/null || [ -z "$(git config user.email)" ]; then
  read -r -p "git email for commits: " EMAIL
  git config user.email "$EMAIL"
fi
if ! git config user.name >/dev/null || [ -z "$(git config user.name)" ]; then
  read -r -p "git name for commits: " NAME
  git config user.name "$NAME"
fi

# The remote usually already has a commit (its README). On a fresh local repo we
# adopt that commit as the parent so the push fast-forwards instead of being
# rejected for unrelated histories. Existing local history is left alone.
HAS_LOCAL_COMMITS="no"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  HAS_LOCAL_COMMITS="yes"
fi

if git fetch --quiet origin "$BRANCH" 2>/dev/null; then
  if [ "$HAS_LOCAL_COMMITS" = "no" ] && git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    echo "-> adopting existing origin/$BRANCH history as the base"
    git reset --soft "origin/$BRANCH"
  fi
fi

git add -A
if git diff --cached --quiet; then
  echo "-> nothing new to commit, pushing existing commits"
else
  git commit -m "wow.tok: wallpapers, Live Photo pipeline, tweaks and dev server" >/dev/null
  echo "-> committed"
fi

git symbolic-ref HEAD "refs/heads/$BRANCH" >/dev/null 2>&1 || true
echo "-> pushing to $BRANCH (authenticate when prompted)"
if ! git push -u origin "$BRANCH"; then
  cat <<'OOPS'

Push rejected. Most likely the remote branches moved since this script looked.
Run `git pull --rebase origin main` and then `bash tools/publish.sh` again.
(Older Git installs may also need `git fetch origin main && git reset --soft origin/main`.)
OOPS
  exit 1
fi

cat <<'DONE'

Pushed. Next:
  1. open the repo -> Actions -> "Build unsigned IPA" (it starts on its own on push)
  2. download the WowTok-unsigned-ipa artifact when the run is green
  3. sign it with your dev VPN / sideload tool, then install

If a build fails, grab the build-log artifact: it has the full xcodebuild output.
DONE

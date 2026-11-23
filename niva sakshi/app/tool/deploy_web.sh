#!/usr/bin/env bash
# Builds the web app and publishes it to https://niva-sakshi.vercel.app.
# Needs the Flutter SDK and a logged-in Vercel CLI (`vercel login`).
# The staging folder's name is the Vercel project name; its .vercel link is kept.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release
stage=build/vercel/niva-sakshi
mkdir -p "$stage"
find "$stage" -mindepth 1 -maxdepth 1 ! -name .vercel -exec rm -rf {} +
cp -r build/web/. "$stage/"
cd "$stage"
vercel deploy --prod --yes

#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${OMP2_REPO_URL:-https://github.com/can1357/oh-my-pi.git}"
SOURCE_DIR="${OMP2_SOURCE_DIR:-$HOME/.local/share/omp2/source}"
BIN_DIR="${OMP2_BIN_DIR:-$HOME/.local/bin}"
NATIVE_VERSION="${OMP2_NATIVE_VERSION:-18.1.17}"
PR_REF="${OMP2_PR_REF:-pull/11742/head}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMIT="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"

for command in git bun curl tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "omp2: dependência ausente: $command" >&2
    exit 1
  fi
done

mkdir -p "$(dirname -- "$SOURCE_DIR")" "$BIN_DIR"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --filter=blob:none "$REPO_URL" "$SOURCE_DIR"
elif [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
  echo "omp2: checkout local tem alterações; recusando sobrescrever: $SOURCE_DIR" >&2
  exit 1
fi

git -C "$SOURCE_DIR" remote set-url origin "$REPO_URL"
git -C "$SOURCE_DIR" fetch --no-tags --depth=1 origin "+refs/$PR_REF:refs/remotes/origin/omp2-pr"

if ! git -C "$SOURCE_DIR" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
  git -C "$SOURCE_DIR" fetch --no-tags origin "$COMMIT"
fi

git -C "$SOURCE_DIR" checkout --detach "$COMMIT"

bun --cwd="$SOURCE_DIR" install --frozen-lockfile

NATIVE_DIR="$SOURCE_DIR/packages/natives/native"
PACKAGE_DIR="$NATIVE_DIR/.omp2-native-package"
mkdir -p "$NATIVE_DIR"

if [[ ! -f "$NATIVE_DIR/pi_natives.linux-x64-modern.node" || ! -f "$NATIVE_DIR/pi_natives.linux-x64-baseline.node" ]]; then
  mkdir -p "$PACKAGE_DIR"
  ARCHIVE="$PACKAGE_DIR/pi-natives-linux-x64-${NATIVE_VERSION}.tgz"
  URL="https://registry.npmjs.org/@oh-my-pi/pi-natives-linux-x64/-/pi-natives-linux-x64-${NATIVE_VERSION}.tgz"
  curl -fsSL "$URL" -o "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C "$PACKAGE_DIR"
  for variant in modern baseline; do
    source_file="$PACKAGE_DIR/package/pi_natives.linux-x64-${variant}.node"
    target_file="$NATIVE_DIR/pi_natives.linux-x64-${variant}.node"
    [[ -f "$source_file" ]] || { echo "omp2: addon nativo ausente: $source_file" >&2; exit 1; }
    cp "$source_file" "$target_file"
  done
fi

install -m 0755 "$SCRIPT_DIR/omp2" "$BIN_DIR/omp2"

echo "omp2 instalado"
echo "  commit: $COMMIT"
echo "  source: $SOURCE_DIR"
echo "  binary: $BIN_DIR/omp2"
echo "  native: $NATIVE_VERSION"
echo ""
echo "Se necessário: export PATH=\"$BIN_DIR:\$PATH\""

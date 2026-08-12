#!/usr/bin/env bash

# Installs herdr (https://herdr.dev) from the tip of its git default branch
# instead of a release tag. Upstream's default branch is `master`, not
# `main` — passing no --branch always follows whatever the default is, so
# an upstream rename cannot break this. Set HERDR_BRANCH to pin one.
#
# Known failure: on a cold zig package cache the build can stall for hours
# inside zig 0.15.2's HTTP client while fetching the vendored ghostty deps
# from deps.files.ghostty.org — sockets sit in CLOSE_WAIT and it never
# times out. Interrupt and re-run; each attempt caches the packages it did
# get, so a few passes get through. Once ~/.cache/zig/p is populated the
# step is offline and instant.

set -euo pipefail

repo_url=https://github.com/herdrdev/herdr
install_root="$HOME/.local"
# cargo install builds in a throwaway target dir; pinning one makes every
# re-run an incremental rebuild instead of a cold multi-minute one.
build_cache_dir="$HOME/.cache/herdr-build"

if ! command -v cargo >/dev/null; then
  echo "cargo not found. Install Rust first: install/rust.sh" >&2
  exit 1
fi

# herdr pins its compiler in rust-toolchain.toml, which only rustup reads.
if ! command -v rustup >/dev/null; then
  echo "Warning: rustup not found — rust-toolchain.toml will be ignored" >&2
  echo "and a non-rustup cargo may be too old to build herdr." >&2
fi

# herdr's build.rs compiles the vendored libghostty-vt with zig, and
# vendor/libghostty-vt/build.zig.zon pins minimum_zig_version as an exact
# match — Homebrew's zig 0.16 fails the check outright. build.rs reads $ZIG,
# so pin a matching toolchain there instead of touching the global install.
required_zig_version=${HERDR_ZIG_VERSION:-0.15.2}

# True when the zig at $1 reports exactly the version herdr's vendor pins.
zig_version_matches() {
  [ "$("$1" version 2>/dev/null)" = "$required_zig_version" ]
}

if [ -n "${ZIG:-}" ]; then
  zig_version_matches "$ZIG" ||
    echo "Warning: \$ZIG is not zig $required_zig_version" >&2
elif command -v zig >/dev/null && zig_version_matches "$(command -v zig)"; then
  ZIG=$(command -v zig)
elif command -v mise >/dev/null; then
  # Installs on first run only; mise install is a no-op once present. Kept
  # out of the global mise config so the PATH zig stays whatever you chose.
  mise install "zig@$required_zig_version"
  ZIG="$(mise where "zig@$required_zig_version")/bin/zig"
else
  echo "zig $required_zig_version not found and mise is unavailable." >&2
  echo "Install it, then re-run with ZIG=/path/to/zig." >&2
  exit 1
fi
export ZIG

# True when the SDK at $1 still exports the host arch in its libc stub.
# Only the first tbd document describes libSystem.B.dylib itself; the
# reexported libraries further down list arch sets of their own, and on the
# macOS 26 SDKs those still carry arm64 even though libSystem does not.
sdk_exports_host_arch() {
  awk '/^targets:/ { found = 1 }
       found { printf "%s", $0; if (/\]/) exit }' \
    "$1/usr/lib/libSystem.tbd" 2>/dev/null |
    grep -qE "[[:space:],]$(uname -m)-macos[[:space:],]"
}

# Echoes the newest installed macOS SDK that passes the check above, or
# nothing when every installed SDK has dropped the host arch.
newest_compatible_sdk() {
  local dir sdk version
  for dir in "${sdk_search_dirs[@]}"; do
    [ -d "$dir" ] || continue
    for sdk in "$dir"/MacOSX*.sdk; do
      sdk_exports_host_arch "$sdk" || continue
      version=$(basename "$sdk" .sdk)
      printf '%s\t%s\n' "${version#MacOSX}" "$sdk"
    done
  done | sort -V | tail -1 | cut -f2
}

# The macOS 26 SDKs list only arm64e-macos in libSystem.tbd, so zig 0.15.2
# resolves no libc symbols at all on Apple Silicon (undefined _malloc,
# _fork, …). zig 0.16 maps arm64 onto arm64e but herdr pins 0.15.2. zig
# ignores SDKROOT and links its own build runner before any --sysroot
# reaches the build script, so the only lever is what xcrun reports back.
if [ "$(uname -s)" = "Darwin" ] &&
   ! sdk_exports_host_arch "$(xcrun --show-sdk-path 2>/dev/null)"; then
  sdk_search_dirs=(
    /Library/Developer/CommandLineTools/SDKs
    "$(xcode-select -p 2>/dev/null)/Platforms/MacOSX.platform/Developer/SDKs"
  )
  compatible_sdk=$(newest_compatible_sdk)

  if [ -z "$compatible_sdk" ]; then
    echo "No installed macOS SDK exports $(uname -m)-macos in its libc stub," >&2
    echo "so zig $required_zig_version cannot link the vendored ghostty." >&2
    exit 1
  fi

  shim_dir="$build_cache_dir/sdk-shim"
  mkdir -p "$shim_dir"
  cat > "$shim_dir/xcrun" <<'SHIM'
#!/usr/bin/env bash
# Answers zig's SDK probe with the pinned SDK; every other invocation is
# delegated untouched to the real xcrun.
for arg in "$@"; do
  if [ "$arg" = "--show-sdk-path" ]; then
    printf '%s\n' "$HERDR_ZIG_SDK"
    exit 0
  fi
done
exec /usr/bin/xcrun "$@"
SHIM
  chmod +x "$shim_dir/xcrun"

  export HERDR_ZIG_SDK="$compatible_sdk"
  export PATH="$shim_dir:$PATH"
  echo "Building against $compatible_sdk (zig $required_zig_version needs it)"
fi

mkdir -p "$build_cache_dir"

branch_args=()
if [ -n "${HERDR_BRANCH:-}" ]; then
  branch_args=(--branch "$HERDR_BRANCH")
fi

# --locked builds against the committed Cargo.lock; --force replaces an
# already-installed herdr; --root drops the binary in ~/.local/bin.
CARGO_TARGET_DIR="$build_cache_dir" cargo install \
  --git "$repo_url" \
  ${branch_args[@]+"${branch_args[@]}"} \
  --locked \
  --force \
  --root "$install_root" \
  herdr

echo
"$install_root/bin/herdr" --version

case ":$PATH:" in
  *":$install_root/bin:"*) ;;
  *) echo "Note: $install_root/bin is not on PATH." >&2 ;;
esac

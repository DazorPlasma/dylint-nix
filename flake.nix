{
  description = "A reusable Nix flake utility for using Dylint without global rustup";

  outputs = { self }: {
    lib = {
      # A helper function that generates the mock rustup/cargo shellHook
      mkDylintShellHook = { nightlyToolchain, stableToolchain }: ''
        export PATH=$PATH:~/.cargo/bin
        if ! command -v cargo-dylint &> /dev/null; then
          echo "cargo-dylint not found. Installing..."
          cargo install cargo-dylint dylint-link
        fi

        mkdir -p .bin
        cat << 'EOF' > .bin/rustup
#!/usr/bin/env bash
if [ "$1" = "which" ]; then
    CMD="$2"
    if [[ "$RUSTUP_TOOLCHAIN" == *"nightly"* ]]; then
        echo "${nightlyToolchain}/bin/$CMD"
    else
        echo "${stableToolchain}/bin/$CMD"
    fi
    exit 0
fi
if [ "$1" = "show" ] && [ "$2" = "active-toolchain" ]; then
    # If we are in a lint crate (assuming lint crates have nightly in their local rust-toolchain.toml)
    if [[ -f rust-toolchain.toml ]] && grep -q nightly rust-toolchain.toml; then
        echo "nightly-x86_64-unknown-linux-gnu (mock)"
    else
        echo "stable-x86_64-unknown-linux-gnu (mock)"
    fi
    exit 0
fi
echo "Mock rustup: unhandled args $@" >&2
exit 1
EOF
        cat << 'EOF' > .bin/cargo
#!/usr/bin/env bash
if [ -z "$RUSTUP_TOOLCHAIN" ]; then
    if [[ -f rust-toolchain.toml ]] && grep -q nightly rust-toolchain.toml; then
        export RUSTUP_TOOLCHAIN="nightly-x86_64-unknown-linux-gnu"
    else
        export RUSTUP_TOOLCHAIN="stable-x86_64-unknown-linux-gnu"
    fi
fi
if [[ "$RUSTUP_TOOLCHAIN" == *"nightly"* ]]; then
    exec ${nightlyToolchain}/bin/cargo "$@"
else
    exec ${stableToolchain}/bin/cargo "$@"
fi
EOF
        cat << 'EOF' > .bin/rustc
#!/usr/bin/env bash
if [ -z "$RUSTUP_TOOLCHAIN" ]; then
    if [[ -f rust-toolchain.toml ]] && grep -q nightly rust-toolchain.toml; then
        export RUSTUP_TOOLCHAIN="nightly-x86_64-unknown-linux-gnu"
    else
        export RUSTUP_TOOLCHAIN="stable-x86_64-unknown-linux-gnu"
    fi
fi
if [[ "$RUSTUP_TOOLCHAIN" == *"nightly"* ]]; then
    exec ${nightlyToolchain}/bin/rustc "$@"
else
    exec ${stableToolchain}/bin/rustc "$@"
fi
EOF
        chmod +x .bin/rustup .bin/cargo .bin/rustc
        export PATH=$PWD/.bin:$PATH
      '';
    };
  };
}

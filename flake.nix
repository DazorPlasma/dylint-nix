{
  description = "A reusable Nix flake utility for using Dylint without global rustup";

  outputs = {self}: {
    lib = {
      # Generate the mock rustup/cargo commands used by Dylint lint crates.
      #
      # Callers can pass Nix-packaged cargo-dylint and dylint-link derivations.
      # When they are omitted, the hook installs a pinned pair into an isolated
      # Cargo home instead of installing floating versions into ~/.cargo.
      mkDylintShellHook = {
        nightlyToolchain,
        stableToolchain,
        cargoDylint ? null,
        dylintLink ? null,
        dylintVersion ? "6.0.2",
      }: ''
                mkdir -p .bin

                cat << 'EOF' > .bin/dylint-toolchain
        dylint_toolchain_channel() {
            if [ -n "$RUSTUP_TOOLCHAIN" ]; then
                case "$RUSTUP_TOOLCHAIN" in
                    *nightly*) printf 'nightly\n' ;;
                    *) printf 'stable\n' ;;
                esac
                return
            fi

            dir="$PWD"
            while :; do
                if [ -f "$dir/rust-toolchain.toml" ]; then
                    channel=$(sed -nE 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$dir/rust-toolchain.toml" | head -n 1)
                elif [ -f "$dir/rust-toolchain" ]; then
                    channel=$(grep -Ev '^[[:space:]]*(#|$)' "$dir/rust-toolchain" | head -n 1 | tr -d '[:space:]')
                else
                    channel=
                fi

                if [ -n "$channel" ]; then
                    case "$channel" in
                        *nightly*) printf 'nightly\n' ;;
                        *) printf 'stable\n' ;;
                    esac
                    return
                fi

                if [ "$dir" = / ]; then
                    break
                fi
                dir=$(dirname -- "$dir")
            done

            printf 'stable\n'
        }
        EOF

                cat << 'EOF' > .bin/rustup
        #!/usr/bin/env bash
        source "$(dirname -- "$0")/dylint-toolchain"

        if [ "$1" = "which" ]; then
            CMD="$2"
            if [ "$(dylint_toolchain_channel)" = "nightly" ]; then
                echo "${nightlyToolchain}/bin/$CMD"
            else
                echo "${stableToolchain}/bin/$CMD"
            fi
            exit 0
        fi
        if [ "$1" = "show" ] && [ "$2" = "active-toolchain" ]; then
            if [ "$(dylint_toolchain_channel)" = "nightly" ]; then
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
        source "$(dirname -- "$0")/dylint-toolchain"
        if [ "$(dylint_toolchain_channel)" = "nightly" ]; then
            exec ${nightlyToolchain}/bin/cargo "$@"
        else
            exec ${stableToolchain}/bin/cargo "$@"
        fi
        EOF

                cat << 'EOF' > .bin/rustc
        #!/usr/bin/env bash
        source "$(dirname -- "$0")/dylint-toolchain"
        if [ "$(dylint_toolchain_channel)" = "nightly" ]; then
            exec ${nightlyToolchain}/bin/rustc "$@"
        else
            exec ${stableToolchain}/bin/rustc "$@"
        fi
        EOF

                chmod +x .bin/rustup .bin/cargo .bin/rustc
                export PATH="$PWD/.bin:${
          if cargoDylint == null
          then ""
          else "${cargoDylint}/bin:"
        }${
          if dylintLink == null
          then ""
          else "${dylintLink}/bin:"
        }$PATH"

                missingCargoDylint=0
                missingDylintLink=0
                command -v cargo-dylint >/dev/null 2>&1 || missingCargoDylint=1
                command -v dylint-link >/dev/null 2>&1 || missingDylintLink=1

                if [ "$missingCargoDylint" = 1 ] || [ "$missingDylintLink" = 1 ]; then
                    if [ -z "$CARGO_HOME" ]; then
                        if [ -n "$XDG_CACHE_HOME" ]; then
                            export CARGO_HOME="$XDG_CACHE_HOME/dylint-nix/cargo-home"
                        else
                            export CARGO_HOME="$HOME/.cache/dylint-nix/cargo-home"
                        fi
                    fi
                    mkdir -p "$CARGO_HOME"

                    if [ "$missingCargoDylint" = 1 ]; then
                        echo "Installing pinned cargo-dylint ${dylintVersion} into $CARGO_HOME"
                        cargo install --locked --version "${dylintVersion}" cargo-dylint
                    fi
                    if [ "$missingDylintLink" = 1 ]; then
                        echo "Installing pinned dylint-link ${dylintVersion} into $CARGO_HOME"
                        cargo install --locked --version "${dylintVersion}" dylint-link
                    fi
                    export PATH="$CARGO_HOME/bin:$PATH"
                fi
      '';
    };
  };
}

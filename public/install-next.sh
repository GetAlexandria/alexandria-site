#!/usr/bin/env bash
# Alexandria Next - Remote Installer
#
# Installs the Alexandria Next plugin payload plus the public `ax2` binary.
#
# Usage:
#   curl -fsSL https://getalexandria.ai/install-next.sh | bash
#   curl -fsSL https://getalexandria.ai/install-next.sh | bash -s -- --yes
#
# Environment:
#   ALEXANDRIA_NEXT_VERSION           Pin a specific version (default: latest)
#   ALEXANDRIA_NEXT_BASE_URL          Override site base URL
#   ALEXANDRIA_NEXT_DOWNLOADS_URL     Override downloads base URL
#   ALEXANDRIA_AX2_INSTALL_DIR        Override the directory that receives ax2
#   ALEXANDRIA_DOWNLOADS_URL          Fallback downloads base URL

set -euo pipefail

ALEXANDRIA_NEXT_BASE_URL_INPUT="${ALEXANDRIA_NEXT_BASE_URL:-}"
ALEXANDRIA_NEXT_BASE_URL="${ALEXANDRIA_NEXT_BASE_URL_INPUT:-https://getalexandria.ai}"

if [ -n "${ALEXANDRIA_NEXT_DOWNLOADS_URL:-}" ]; then
	ALEXANDRIA_NEXT_DOWNLOADS_URL="${ALEXANDRIA_NEXT_DOWNLOADS_URL%/}"
elif [ -n "${ALEXANDRIA_DOWNLOADS_URL:-}" ]; then
	ALEXANDRIA_NEXT_DOWNLOADS_URL="${ALEXANDRIA_DOWNLOADS_URL%/}"
elif [ -n "${ALEXANDRIA_NEXT_BASE_URL_INPUT:-}" ]; then
	ALEXANDRIA_NEXT_DOWNLOADS_URL="${ALEXANDRIA_NEXT_BASE_URL%/}/downloads"
else
	ALEXANDRIA_NEXT_DOWNLOADS_URL="https://downloads.getalexandria.ai"
fi

info() { echo "  -> $1"; }
success() { echo "  ✓ $1"; }
warn() { echo "  ! $1"; }
error() { echo "  x $1" >&2; }

ASSUME_YES=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	--yes | -y)
		ASSUME_YES=true
		shift
		;;
	--help | -h)
		echo "Alexandria Next Installer"
		echo ""
		echo "Usage: curl -fsSL https://getalexandria.ai/install-next.sh | bash"
		echo "       curl -fsSL https://getalexandria.ai/install-next.sh | bash -s -- --yes"
		echo ""
		echo "Environment:"
		echo "  ALEXANDRIA_NEXT_VERSION        Pin a specific version (default: latest)"
		echo "  ALEXANDRIA_NEXT_BASE_URL       Override Alexandria site base URL"
		echo "  ALEXANDRIA_NEXT_DOWNLOADS_URL  Override Alexandria downloads base URL"
		echo "  ALEXANDRIA_AX2_INSTALL_DIR     Override the directory that receives ax2"
		echo "  ALEXANDRIA_DOWNLOADS_URL       Fallback Alexandria downloads base URL"
		echo ""
		echo "Flags:"
		echo "  --yes, -y    Skip confirmation prompt"
		echo "  --help, -h   Show this help"
		exit 0
		;;
	*)
		error "Unknown option: $1"
		echo "Run with --help for usage" >&2
		exit 1
		;;
	esac
done

require_curl() {
	if ! command -v curl >/dev/null 2>&1; then
		error "curl is required for installation"
		exit 1
	fi
}

resolve_version() {
	if [ -n "${ALEXANDRIA_NEXT_VERSION:-}" ]; then
		printf '%s' "$ALEXANDRIA_NEXT_VERSION"
		return
	fi

	require_curl
	curl -fsSL "$ALEXANDRIA_NEXT_DOWNLOADS_URL/alexandria-next/latest-version.txt" | tr -d '[:space:]'
}

detect_plugin_target() {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		local repo_root
		repo_root="$(git rev-parse --show-toplevel)"
		printf '%s' "$repo_root/.claude/plugins/alexandria-next"
	else
		printf '%s' "$HOME/.claude/plugins/alexandria-next"
	fi
}

detect_context_label() {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		printf 'project-local'
	else
		printf 'global'
	fi
}

resolve_ax2_install_dir() {
	if [ -n "${ALEXANDRIA_AX2_INSTALL_DIR:-}" ]; then
		printf '%s' "$ALEXANDRIA_AX2_INSTALL_DIR"
		return
	fi

	local local_bin="$HOME/.local/bin"
	if [ -d "$local_bin" ] || mkdir -p "$local_bin" 2>/dev/null; then
		printf '%s' "$local_bin"
		return
	fi

	printf '%s' "$HOME/.alexandria/bin"
}

detect_platform() {
	local os arch
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m)"

	case "$os" in
	darwin) os="darwin" ;;
	linux) os="linux" ;;
	*)
		error "Unsupported operating system: $os"
		exit 1
		;;
	esac

	case "$arch" in
	x86_64 | amd64) arch="x64" ;;
	arm64 | aarch64) arch="arm64" ;;
	*)
		error "Unsupported architecture: $arch"
		exit 1
		;;
	esac

	printf '%s-%s' "$os" "$arch"
}

STAGING_DIR=""

cleanup() {
	if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
		rm -rf "$STAGING_DIR"
	fi
}

trap cleanup EXIT

download_file() {
	local url="$1"
	local output="$2"

	require_curl
	curl -fsSL "$url" -o "$output"
}

extract_single_root_tarball() {
	local archive="$1"
	local target_dir="$2"
	local expected_root="$3"

	tar -xzf "$archive" -C "$target_dir"
	if [ ! -d "$target_dir/$expected_root" ]; then
		error "Extraction failed - expected directory not found: $expected_root"
		exit 1
	fi
}

install_plugin_payload() {
	local version="$1"
	local plugin_target="$2"
	local archive_name="alexandria-next-plugin-v${version}.tar.gz"
	local archive_url="$ALEXANDRIA_NEXT_DOWNLOADS_URL/$archive_name"
	local archive_path="$STAGING_DIR/$archive_name"
	local extracted_root="alexandria-next-plugin-v${version}"

	info "Downloading Alexandria Next plugin payload..."
	download_file "$archive_url" "$archive_path"
	info "Extracting Alexandria Next plugin payload..."
	extract_single_root_tarball "$archive_path" "$STAGING_DIR" "$extracted_root"

	rm -rf "$plugin_target"
	mkdir -p "$(dirname "$plugin_target")"
	mv "$STAGING_DIR/$extracted_root" "$plugin_target"
	success "Installed plugin payload to: $plugin_target"
}

install_ax2_binary() {
	local version="$1"
	local ax2_install_dir="$2"
	local platform="$3"
	local archive_name="ax2-v${version}-${platform}.tar.gz"
	local archive_url="$ALEXANDRIA_NEXT_DOWNLOADS_URL/$archive_name"
	local archive_path="$STAGING_DIR/$archive_name"
	local extract_dir="$STAGING_DIR/ax2-$platform"
	local ax2_target="$ax2_install_dir/ax2"

	info "Downloading ax2 binary..."
	download_file "$archive_url" "$archive_path"

	rm -rf "$extract_dir"
	mkdir -p "$extract_dir"
	tar -xzf "$archive_path" -C "$extract_dir"

	if [ ! -f "$extract_dir/ax2" ]; then
		error "Extraction failed - expected ax2 binary in $archive_name"
		exit 1
	fi

	mkdir -p "$ax2_install_dir"
	install -m 0755 "$extract_dir/ax2" "$ax2_target"
	success "Installed ax2 to: $ax2_target"
}

register_plugin() {
	local plugin_target="$1"
	local context_label="$2"
	local scope

	if [ "$context_label" = "project-local" ]; then
		scope="project"
	else
		scope="user"
	fi

	if ! command -v claude >/dev/null 2>&1; then
		warn "Claude Code CLI not found - skipping plugin registration."
		warn "Register manually later with:"
		warn "  claude plugin marketplace add $plugin_target --scope $scope"
		warn "  claude plugin install alexandria-next@alexandria --scope $scope"
		return 1
	fi

	info "Registering plugin with Claude Code ($scope scope)..."

	if ! claude plugin marketplace add "$plugin_target" --scope "$scope" 2>/dev/null; then
		warn "Marketplace registration failed - register manually:"
		warn "  claude plugin marketplace add $plugin_target --scope $scope"
		warn "  claude plugin install alexandria-next@alexandria --scope $scope"
		return 1
	fi

	if ! claude plugin install "alexandria-next@alexandria" --scope "$scope" 2>/dev/null; then
		warn "Plugin install failed - install manually:"
		warn "  claude plugin install alexandria-next@alexandria --scope $scope"
		return 1
	fi

	success "Plugin registered with Claude Code ($scope scope)"
}

echo "Alexandria Next - Installer"
echo ""

VERSION="$(resolve_version)"
if [ -z "$VERSION" ]; then
	error "Could not resolve version. Set ALEXANDRIA_NEXT_VERSION or check your network."
	exit 1
fi

PLUGIN_TARGET="$(detect_plugin_target)"
AX2_INSTALL_DIR="$(resolve_ax2_install_dir)"
AX2_TARGET="$AX2_INSTALL_DIR/ax2"
CONTEXT_LABEL="$(detect_context_label)"
PLATFORM="$(detect_platform)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alexandria-next-install.XXXXXX")"

echo "Install plan:"
echo "  Context:     $CONTEXT_LABEL"
echo "  Plugin:      $PLUGIN_TARGET"
echo "  ax2 binary:  $AX2_TARGET"
echo "  Version:     $VERSION"
echo "  Platform:    $PLATFORM"
echo ""

if [ "$ASSUME_YES" = false ]; then
	if [ -t 0 ]; then
		printf "Proceed? [y/N] "
		read -r REPLY
	elif (exec </dev/tty) 2>/dev/null; then
		printf "Proceed? [y/N] " >/dev/tty
		read -r REPLY </dev/tty
	else
		error "No terminal available for confirmation. Pipe with: bash -s -- --yes"
		exit 1
	fi

	if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
		echo "Aborted."
		exit 0
	fi
fi

echo ""
install_plugin_payload "$VERSION" "$PLUGIN_TARGET"
install_ax2_binary "$VERSION" "$AX2_INSTALL_DIR" "$PLATFORM"
PLUGIN_REGISTERED=false
if register_plugin "$PLUGIN_TARGET" "$CONTEXT_LABEL"; then
	PLUGIN_REGISTERED=true
fi

echo ""
echo "Installation complete! (v$VERSION)"
echo ""

if [[ ":$PATH:" != *":$AX2_INSTALL_DIR:"* ]]; then
	warn "ax2 is installed outside your current PATH."
	warn "Add this to your shell profile:"
	warn "  export PATH=\"$AX2_INSTALL_DIR:\$PATH\""
	echo ""
fi

if [ "$CONTEXT_LABEL" = "project-local" ]; then
	if [ "$PLUGIN_REGISTERED" = true ]; then
		echo "The plugin is installed and registered for this project."
	else
		echo "The plugin is installed for this project but still needs Claude Code registration."
	fi
	echo ""
	echo "Tip: add .claude/plugins/alexandria-next/ to your .gitignore:"
	echo ""
	echo "  echo '.claude/plugins/alexandria-next/' >> .gitignore"
	echo ""
else
	if [ "$PLUGIN_REGISTERED" = true ]; then
		echo "The plugin is globally installed and registered."
	else
		echo "The plugin is globally installed but still needs Claude Code registration."
	fi
	echo ""
fi

echo "Then initialize Alexandria Next:"
echo "  Run ax2 init"
echo "  Use the ax-next-start skill to begin"

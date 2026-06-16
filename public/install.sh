#!/usr/bin/env bash
# Alexandria - Remote Installer
#
# Installs the Alexandria Claude plugin, public `ax` binary, and
# bundled Fabro orchestration binary.
#
# Usage:
#   curl -fsSL https://getalexandria.ai/install.sh | bash
#   curl -fsSL https://getalexandria.ai/install.sh | bash -s -- --yes
#   curl -fsSL https://getalexandria.ai/install.sh | bash -s -- --yes --init
#
# Environment:
#   ALEXANDRIA_VERSION         Pin a specific version (default: latest)
#   ALEXANDRIA_BASE_URL        Override site base URL
#   ALEXANDRIA_DOWNLOADS_URL   Override downloads base URL
#   ALEXANDRIA_AX_INSTALL_DIR  Override the directory that receives ax/fabro
#   ALEXANDRIA_ACP_PROVIDER    ACP provider for Fabro plays: codex or claude

set -euo pipefail

ALEXANDRIA_BASE_URL_INPUT="${ALEXANDRIA_BASE_URL:-}"
ALEXANDRIA_BASE_URL="${ALEXANDRIA_BASE_URL_INPUT:-https://getalexandria.ai}"

if [ -n "${ALEXANDRIA_DOWNLOADS_URL:-}" ]; then
	ALEXANDRIA_DOWNLOADS_URL="${ALEXANDRIA_DOWNLOADS_URL%/}"
elif [ -n "${ALEXANDRIA_BASE_URL_INPUT:-}" ]; then
	ALEXANDRIA_DOWNLOADS_URL="${ALEXANDRIA_BASE_URL%/}/downloads"
else
	ALEXANDRIA_DOWNLOADS_URL="https://downloads.getalexandria.ai"
fi

info() { echo "  -> $1"; }
success() { echo "  ✓ $1"; }
warn() { echo "  ! $1"; }
error() { echo "  x $1" >&2; }

ASSUME_YES=false
RUN_INIT=false
ACP_PROVIDER="${ALEXANDRIA_ACP_PROVIDER:-codex}"

validate_acp_provider() {
	case "$1" in
	codex | claude) ;;
	*)
		error "Unsupported ACP provider: $1"
		error "Supported providers: codex, claude"
		exit 1
		;;
	esac
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--yes | -y)
		ASSUME_YES=true
		shift
		;;
	--init)
		RUN_INIT=true
		shift
		;;
	--acp-provider)
		if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
			error "Missing value for --acp-provider"
			exit 1
		fi
		ACP_PROVIDER="$2"
		validate_acp_provider "$ACP_PROVIDER"
		shift 2
		;;
	--acp-provider=*)
		ACP_PROVIDER="${1#--acp-provider=}"
		if [ -z "$ACP_PROVIDER" ]; then
			error "Missing value for --acp-provider"
			exit 1
		fi
		validate_acp_provider "$ACP_PROVIDER"
		shift
		;;
	--help | -h)
		echo "Alexandria Installer"
		echo ""
		echo "Usage: curl -fsSL https://getalexandria.ai/install.sh | bash"
		echo "       curl -fsSL https://getalexandria.ai/install.sh | bash -s -- --yes"
		echo "       curl -fsSL https://getalexandria.ai/install.sh | bash -s -- --yes --init --acp-provider claude"
		echo ""
		echo "Environment:"
		echo "  ALEXANDRIA_VERSION        Pin a specific version (default: latest)"
		echo "  ALEXANDRIA_BASE_URL       Override Alexandria site base URL"
		echo "  ALEXANDRIA_DOWNLOADS_URL  Override Alexandria downloads base URL"
		echo "  ALEXANDRIA_AX_INSTALL_DIR Override the directory that receives ax/fabro"
		echo "  ALEXANDRIA_ACP_PROVIDER   ACP provider for Fabro plays: codex or claude"
		echo ""
		echo "Flags:"
		echo "  --yes, -y                 Skip confirmation prompt"
		echo "  --init                    Initialize the current project after installation"
		echo "  --acp-provider <provider> ACP provider for Fabro plays: codex or claude"
		echo "  --help, -h                Show this help"
		exit 0
		;;
	*)
		error "Unknown option: $1"
		echo "Run with --help for usage" >&2
		exit 1
		;;
	esac
done

validate_acp_provider "$ACP_PROVIDER"

require_curl() {
	if ! command -v curl >/dev/null 2>&1; then
		error "curl is required for installation"
		exit 1
	fi
}

resolve_version() {
	if [ -n "${ALEXANDRIA_VERSION:-}" ]; then
		printf '%s' "$ALEXANDRIA_VERSION"
		return
	fi

	require_curl
	curl -fsSL "$ALEXANDRIA_DOWNLOADS_URL/latest-version.txt" | tr -d '[:space:]'
}

detect_plugin_target() {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		local repo_root
		repo_root="$(git rev-parse --show-toplevel)"
		printf '%s' "$repo_root/.claude/plugins/alexandria"
	else
		printf '%s' "$HOME/.claude/plugins/alexandria"
	fi
}

detect_context_label() {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		printf 'project-local'
	else
		printf 'global'
	fi
}

resolve_ax_install_dir() {
	if [ -n "${ALEXANDRIA_AX_INSTALL_DIR:-}" ]; then
		printf '%s' "$ALEXANDRIA_AX_INSTALL_DIR"
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
	local archive_name="alexandria-plugin-v${version}.tar.gz"
	local archive_url="$ALEXANDRIA_DOWNLOADS_URL/$archive_name"
	local archive_path="$STAGING_DIR/$archive_name"
	local extracted_root="alexandria-plugin-v${version}"

	info "Downloading Alexandria Claude plugin..."
	download_file "$archive_url" "$archive_path"
	info "Extracting Alexandria Claude plugin..."
	extract_single_root_tarball "$archive_path" "$STAGING_DIR" "$extracted_root"

	rm -rf "$plugin_target"
	mkdir -p "$(dirname "$plugin_target")"
	mv "$STAGING_DIR/$extracted_root" "$plugin_target"
	success "Installed Alexandria Claude plugin to: $plugin_target"
}

install_ax_binary() {
	local version="$1"
	local ax_install_dir="$2"
	local platform="$3"
	local archive_name="ax-v${version}-${platform}.tar.gz"
	local archive_url="$ALEXANDRIA_DOWNLOADS_URL/$archive_name"
	local archive_path="$STAGING_DIR/$archive_name"
	local extract_dir="$STAGING_DIR/ax-$platform"
	local ax_target="$ax_install_dir/ax"

	info "Downloading ax binary..."
	download_file "$archive_url" "$archive_path"

	rm -rf "$extract_dir"
	mkdir -p "$extract_dir"
	tar -xzf "$archive_path" -C "$extract_dir"

	if [ ! -f "$extract_dir/ax" ]; then
		error "Extraction failed - expected ax binary in $archive_name"
		exit 1
	fi

	mkdir -p "$ax_install_dir"
	install -m 0755 "$extract_dir/ax" "$ax_target"
	if [ -d "$extract_dir/dist/viewer" ]; then
		rm -rf "$ax_install_dir/dist/viewer"
		mkdir -p "$ax_install_dir/dist"
		cp -R "$extract_dir/dist/viewer" "$ax_install_dir/dist/viewer"
	fi
	success "Installed ax to: $ax_target"
}

install_fabro_binary() {
	local version="$1"
	local ax_install_dir="$2"
	local platform="$3"
	local archive_name="fabro-v${version}-${platform}.tar.gz"
	local archive_url="$ALEXANDRIA_DOWNLOADS_URL/$archive_name"
	local archive_path="$STAGING_DIR/$archive_name"
	local extract_dir="$STAGING_DIR/fabro-$platform"
	local fabro_target="$ax_install_dir/fabro"

	info "Downloading Fabro binary..."
	download_file "$archive_url" "$archive_path"

	rm -rf "$extract_dir"
	mkdir -p "$extract_dir"
	tar -xzf "$archive_path" -C "$extract_dir"

	if [ ! -f "$extract_dir/fabro" ]; then
		error "Extraction failed - expected Fabro binary in $archive_name"
		exit 1
	fi

	mkdir -p "$ax_install_dir"
	install -m 0755 "$extract_dir/fabro" "$fabro_target"
	success "Installed Fabro to: $fabro_target"
}

initialize_ax() {
	local ax_target="$1"

	if [ "$RUN_INIT" = true ]; then
		info "Initializing Alexandria in the current project..."
		"$ax_target" init all --acp-provider "$ACP_PROVIDER"
		success "Initialized Alexandria project and orchestration support"
		return
	fi

	info "Installing $ACP_PROVIDER ACP orchestration support..."
	"$ax_target" init orchestration --acp-provider "$ACP_PROVIDER"
	success "Installed $ACP_PROVIDER ACP orchestration support"
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
		warn "  claude plugin install alexandria@alexandria --scope $scope"
		return 1
	fi

	info "Registering plugin with Claude Code ($scope scope)..."

	if ! claude plugin marketplace add "$plugin_target" --scope "$scope" 2>/dev/null; then
		warn "Marketplace registration failed - register manually:"
		warn "  claude plugin marketplace add $plugin_target --scope $scope"
		warn "  claude plugin install alexandria@alexandria --scope $scope"
		return 1
	fi

	if ! claude plugin install "alexandria@alexandria" --scope "$scope" 2>/dev/null; then
		warn "Plugin install failed - install manually:"
		warn "  claude plugin install alexandria@alexandria --scope $scope"
		return 1
	fi

	success "Plugin registered with Claude Code ($scope scope)"
}

echo "Alexandria - Installer"
echo ""

VERSION="$(resolve_version)"
if [ -z "$VERSION" ]; then
	error "Could not resolve version. Set ALEXANDRIA_VERSION or check your network."
	exit 1
fi

PLUGIN_TARGET="$(detect_plugin_target)"
AX_INSTALL_DIR="$(resolve_ax_install_dir)"
AX_TARGET="$AX_INSTALL_DIR/ax"
FABRO_TARGET="$AX_INSTALL_DIR/fabro"
CONTEXT_LABEL="$(detect_context_label)"
PLATFORM="$(detect_platform)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alexandria-install.XXXXXX")"

echo "Install plan:"
echo "  Context:     $CONTEXT_LABEL"
echo "  Claude plugin: $PLUGIN_TARGET"
echo "  ax binary:  $AX_TARGET"
echo "  Fabro:       $FABRO_TARGET"
echo "  ACP provider: $ACP_PROVIDER"
if [ "$RUN_INIT" = true ]; then
	echo "  Initialize:  current project"
else
	echo "  Initialize:  no project files ($ACP_PROVIDER ACP support only)"
fi
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
install_fabro_binary "$VERSION" "$AX_INSTALL_DIR" "$PLATFORM"
install_ax_binary "$VERSION" "$AX_INSTALL_DIR" "$PLATFORM"
initialize_ax "$AX_TARGET"
PLUGIN_REGISTERED=false
if register_plugin "$PLUGIN_TARGET" "$CONTEXT_LABEL"; then
	PLUGIN_REGISTERED=true
fi

echo ""
echo "Installation complete! (v$VERSION)"
echo ""

if [[ ":$PATH:" != *":$AX_INSTALL_DIR:"* ]]; then
	warn "ax is installed outside your current PATH."
	warn "Add this to your shell profile:"
	warn "  export PATH=\"$AX_INSTALL_DIR:\$PATH\""
	echo ""
fi

if [ "$CONTEXT_LABEL" = "project-local" ]; then
	if [ "$PLUGIN_REGISTERED" = true ]; then
		echo "The Alexandria Claude plugin is installed and registered for this project."
	else
		echo "The Alexandria Claude plugin is installed for this project but still needs Claude Code registration."
	fi
	echo ""
	echo "Tip: add .claude/plugins/alexandria/ to your .gitignore:"
	echo ""
	echo "  echo '.claude/plugins/alexandria/' >> .gitignore"
	echo ""
else
	if [ "$PLUGIN_REGISTERED" = true ]; then
		echo "The Alexandria Claude plugin is globally installed and registered."
	else
		echo "The Alexandria Claude plugin is globally installed but still needs Claude Code registration."
	fi
	echo ""
fi

if [ "$RUN_INIT" = true ]; then
	echo "Alexandria is initialized in this project."
else
	echo "$ACP_PROVIDER ACP support is installed. To initialize this project later:"
	echo "  Run ax init --acp-provider $ACP_PROVIDER"
fi
echo "  Use the ax-start skill to begin"

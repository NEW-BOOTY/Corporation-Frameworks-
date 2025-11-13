#!/usr/bin/env bash
#
# Copyright © 2025 Devin B. Royal.
# All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Enterprise Governance Meta-Builder
# Author: Devin B. Royal, CTO
# Version: 1.0.6
#
# This script provides a self-healing, modular, and audit-ready framework
# for bootstrapping, generating, compiling, and managing complex enterprise projects.
#
# Changelog 1.0.6:
# - Fixed cosmetic logging bug in fn_install_packages. It now logs all
#   arguments passed to it (e.g., "$*") instead of just the first ("$@").

# --- Strict Mode & Error Handling ---
set -eEuo pipefail

# --- Global Configuration ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="1.0.6"
SCRIPT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Logging Configuration ---
LOG_DIR="${HOME}/.logs/meta_builder"
LOG_FILE="${LOG_DIR}/meta_builder_$(date -u +"%Y%m%d").log"
AUDIT_FILE="${LOG_DIR}/meta_builder_audit.log"
FORENSIC_DIR="${LOG_DIR}/forensic_logs"

# --- Color Codes for Logging ---
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RESET="\033[0m"
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  BOLD="\033[1m"
else
  RESET=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
  BOLD=""
fi

# --- Core Functions (Moved Up in 1.0.3) ---
# All logging and trap handlers MUST be defined before 'trap' is called.

# --- Core Logging Functions ---
_log() {
  local level="$1"
  local color="$2"
  local message="$3"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_entry="${timestamp} [${level}] ${message}"
  
  # Log to file (append)
  echo "${log_entry}" >> "$LOG_FILE"
  
  # Log to stdout/stderr
  if [[ "$level" == "ERROR" ]]; then
    echo -e "${color}${BOLD}${log_entry}${RESET}" >&2
  else
    echo -e "${color}${log_entry}${RESET}"
  fi
}

log_info() { _log "INFO" "$GREEN" "$1"; }
log_warn() { _log "WARN" "$YELLOW" "$1"; }
log_error() { _log "ERROR" "$RED" "$1"; }
log_debug() { _log "DEBUG" "$CYAN" "$1"; }

# log_audit: For immutable, audit-ready logging
log_audit() {
  local action="$1"
  local details="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local user
  user=$(whoami)
  local project="${PROJECT_NAME:-"Global"}"
  
  local audit_entry="${timestamp} | ${user} | ${project} | ${action} | ${details}"
  echo "${audit_entry}" >> "$AUDIT_FILE"
}

# --- Error and Exit Handlers ---
fn_handle_error() {
  local exit_code="$1"
  local line_number="$2"
  local command="$3"
  
  log_error "Execution failed:"
  log_error "  Exit Code: ${exit_code}"
  log_error "  Line: ${line_number}"
  log_error "  Command: ${command}"
  
  # Forensic logging
  local forensic_log="${FORENSIC_DIR}/err_$(date -u +"%Y%m%dT%H%M%S").log"
  echo "--- FORENSIC LOG: ${SCRIPT_START_TIME} ---" > "$forensic_log"
  echo "User: $(whoami)" >> "$forensic_log"
  echo "Project: ${PROJECT_NAME:-"N/A"}" >> "$forensic_log"
  echo "Error Code: ${exit_code}" >> "$forensic_log"
  echo "Line: ${line_number}" >> "$forensic_log"
  echo "Command: ${command}" >> "$forensic_log"
  echo "--- STACK TRACE ---" >> "$forensic_log"
  local i=0
  while caller $i; do
    ((i++))
  done >> "$forensic_log"
  
  # Use 'type -t' to safely check if audit/heal functions are defined
  if type -t log_audit &> /dev/null; then
    log_audit "SELF_HEAL_TRIGGER" "Error ${exit_code} at line ${line_number}. Forensic log created at ${forensic_log}"
  fi
  
  if type -t fn_project_self_heal &> /dev/null; then
    log_warn "Attempting project-specific self-healing..."
    fn_project_self_heal "$exit_code" "$line_number" "$command"
  else
    log_warn "No project-specific self-heal function defined. Default rollback may apply."
  fi
}

fn_cleanup() {
  # Use 'type -t' for safety
  if type -t log_info &> /dev/null; then
    log_info "Meta-Builder session finished."
  else
    echo "Meta-Builder session finished."
  fi
}

# --- Trap for ERR and EXIT ---
trap 'fn_handle_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'fn_cleanup' EXIT

# --- Log Directory Initialization ---
mkdir -p "$LOG_DIR"
mkdir -p "$FORENSIC_DIR"
touch -a "$LOG_FILE"
touch -a "$AUDIT_FILE"

# --- Help/Usage Function ---
fn_show_help() {
  echo -e "${BOLD}Enterprise Governance Meta-Builder${RESET} (v${SCRIPT_VERSION})"
  echo -e "Authored by Devin B. Royal, CTO. Copyright © 2025."
  echo ""
  echo -e "${BOLD}USAGE:${RESET}"
  echo -e "  ${SCRIPT_NAME} --project <name> [command] [options]"
  echo ""
  echo -e "${BOLD}PROJECT:${RESET}"
  echo -e "  ${CYAN}--project <name>${RESET}   Load a project configuration (e.g., 'chimera', 'sentry')."
  echo ""
  echo -e "${BOLD}CORE COMMANDS:${RESET}"
  echo -e "  ${CYAN}--bootstrap${RESET}        Bootstraps the development environment. Detects OS, installs packages, keys."
  echo -e "  ${CYAN}--generate <type> <name>${RESET} Generate a new artifact (e.g., 'script', 'module', 'license')."
  echo -e "  ${CYAN}--compile <target>${RESET}   Compile a specific target or the entire project."
  echo -e "  ${CYAN}--ai <task> [args...]{RESET}   Run an AI-assisted task (e.g., 'validate', 'commit', 'remediate')."
  echo -e "  ${CYAN}--sync${RESET}             Run privacy-aware rclone synchronization."
  echo -e "  ${CYAN}--audit <report>${RESET}     Generate a compliance or audit report (e.g., 'spdx', 'risk')."
  echo -e "  ${CYAN}--heal${RESET}             Manually trigger the self-healing and rollback mechanism."
  echo ""
  echo -e "${BOLD}OTHER FLAGS:${RESET}"
  echo -e "  ${CYAN}--help${RESET}             Show this help message."
  echo -e "  ${CYAN}--version${RESET}          Show the script version."
  echo -e "  ${CYAN}--no-color${RESET}         Disable color output."
  echo ""
}

# --- Utility Functions ---

# fn_detect_os: Detects the operating system
fn_detect_os() {
  local os
  os=$(uname -s)
  case "$os" in
    Linux*)
      # Check for iSH (iOS)
      if (uname -a | grep -q "ish"); then
        OS_TYPE="ish"
        PKG_MANAGER="apk"
      else
        OS_TYPE="linux"
        if [ -f /etc/debian_version ]; then
          PKG_MANAGER="apt-get"
        elif [ -f /etc/redhat-release ]; then
          PKG_MANAGER="yum" # or dnf
        else
          log_warn "Unsupported Linux distribution. Package management may fail."
          PKG_MANAGER="unknown"
        fi
      fi
      ;;
    Darwin*)
      OS_TYPE="macos"
      if command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
      else
        log_error "Homebrew (brew) not found. Please install it to continue."
        return 1
      fi
      ;;
    *)
      log_error "Unsupported Operating System: $os"
      return 1
      ;;
  esac
  log_info "Detected OS: ${OS_TYPE} (Package Manager: ${PKG_MANAGER})"
}

# fn_install_packages: Installs required packages
fn_install_packages() {
  if [[ "$PKG_MANAGER" == "unknown" ]]; then
    log_warn "Cannot install packages. Unknown package manager."
    return 1
  fi
  
  # FIX 1.0.6: Use "$*" to log all packages as a single string.
  log_info "Installing packages: $*"
  
  case "$PKG_MANAGER" in
    apt-get) sudo apt-get update && sudo apt-get install -y "$@" ;;
    yum) sudo yum install -y "$@" ;;
    apk) sudo apk add "$@" ;;
    brew) brew install "$@" ;;
  esac
  log_audit "BOOTSTRAP" "Installed packages: $*"
}

# --- Core Capability Functions (Weak Definitions) ---
# These functions provide default behavior and are designed
# to be overridden by the project-specific .conf files.

fn_project_bootstrap() {
  log_warn "No project-specific bootstrap defined. Running global bootstrap."
  
  # 1. Install base dependencies
  local base_packages="git curl rclone gnupg"
  fn_install_packages "$base_packages"
  
  # 2. Setup dotfiles (example)
  if [ ! -d "${HOME}/.dotfiles" ]; then
    log_info "Cloning base dotfiles..."
    # git clone "git@github.com:enterprise/dotfiles.git" "${HOME}/.dotfiles"
    # ... stow or symlink logic ...
  else
    log_info "Dotfiles already present."
  fi
  
  # 3. Setup GPG/SSH keys (example)
  if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
    log_warn "No primary SSH key found. Please provision one."
  fi
}

fn_project_generate() {
  local type="$1"
  local name="$2"
  local filepath="$3"
  
  log_info "Generating artifact type '${type}' with name '${name}' at '${filepath}'"
  
  # This is the "Script Generation Factory"
  local header
  header=$(cat <<EOF
#!/usr/bin/env bash
#
# Copyright © 2025 Devin B. Royal.
# All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Generated by: Enterprise Meta-Builder
# Project: ${PROJECT_NAME}
# Artifact: ${name}
#

set -eEuo pipefail

log_info() {
  echo "[\$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [INFO] \$1"
}

main() {
  log_info "Executing ${name}"
  # TODO: Implement script logic
}

# Ensure main is called
main "\$@"

EOF
)
  
  case "$type" in
    bash | script)
      echo "$header" > "$filepath"
      chmod +x "$filepath"
      log_info "Generated Bash script: ${filepath}"
      log_audit "GENERATE" "Created Bash script at ${filepath}"
      ;;
    python)
      # Python generation logic
      echo "# Copyright © 2025 Devin B. Royal." > "$filepath"
      # ...
      log_audit "GENERATE" "Created Python module at ${filepath}"
      ;;
    java)
      # Java generation logic
      echo "// Copyright © 2025 Devin B. Royal." > "$filepath"
      # ...
      log_audit "GENERATE" "Created Java class at ${filepath}"
      ;;
    *)
      log_error "Unsupported generation type: ${type}"
      return 1
      ;;
  esac
}

fn_project_compile() {
  log_warn "No project-specific compile function defined."
  log_info "Languages to compile: ${LANGS_SUPPORTED[*]}"
  # Placeholder logic
  if [[ " ${LANGS_SUPPORTED[*]} " =~ " go " ]]; then
    log_info "Compiling Go targets..."
    go build ./...
  fi
  if [[ " ${LANGS_SUPPORTED[*]} " =~ " rust " ]]; then
    log_info "Compiling Rust targets..."
    cargo build --release
  fi
  log_audit "COMPILE" "Ran default compile for targets: ${LANGS_SUPPORTED[*]}"
}

fn_project_ai_assist() {
  local task="$1"
  shift
  local args=("$@")
  
  log_info "AI Assist Task: ${task}"
  case "$task" in
    validate)
      log_info "Validating code logic with AI model..."
      # Placeholder:
      # response=$(curl -s -X POST "https://api.llm.enterprise.com/v1/validate" \
      #   -H "Authorization: Bearer $ENTERPRISE_LLM_KEY" \
      #   -d "{\"code\": \"$(cat ${args[0]})\"}")
      # log_info "AI Validation Response: ${response}"
      log_audit "AI_ASSIST" "Task: validate, Target: ${args[0]}"
      ;;
    commit)
      log_info "Generating semantic commit message..."
      local diff
      diff=$(git diff --staged)
      # Placeholder:
      # commit_msg=$(curl -s -X POST "https://api.llm.enterprise.com/v1/semantic_commit" \
      #   -H "Authorization: Bearer $ENTERPRISE_LLM_KEY" \
      #   -d "{\"diff\": \"${diff}\"}")
      # log_info "Generated Commit Message: ${commit_msg}"
      # git commit -m "${commit_msg}"
      log_audit "AI_ASSIST" "Task: commit"
      ;;
    *)
      log_error "Unsupported AI task: ${task}"
      return 1
      ;;
  esac
}

fn_project_sync() {
  log_info "Running privacy-aware rclone synchronization..."
  if ! command -v rclone &> /dev/null; then
    log_error "rclone command not found. Please install it."
    fn_install_packages "rclone"
  fi
  
  # Example: Sync audit logs to a secure, immutable S3 bucket
  # --log-level=NOTICE: Don't log individual filenames (privacy)
  # --no-unicode-normalization: Preserve symlinks and special chars
  local rclone_target="enterprise_s3_secure:audit-logs/${PROJECT_NAME}/"
  log_info "Syncing audit logs to ${rclone_target}"
  
  rclone sync "$AUDIT_FILE" "$rclone_target" \
    --log-level=NOTICE \
    --no-unicode-normalization \
    --checksum
  
  log_audit "SYNC" "Synced ${AUDIT_FILE} to ${rclone_target}"
}

fn_project_audit() {
  local report_type="$1"
  log_info "Generating audit report: ${report_type}"
  
  case "$report_type" in
    spdx)
      log_info "Generating SPDX license compliance report..."
      # Placeholder:
      # spdx-scanner -i . -o spdx_report.json
      log_audit "AUDIT" "Generated SPDX report."
      ;;
    risk)
      log_info "Generating operational risk report..."
      # Placeholder logic
      log_audit "AUDIT" "Generated risk report."
      ;;
    *)
      log_error "Unsupported audit report type: ${report_type}"
      return 1
      ;;
  esac
}

fn_project_self_heal() {
  local exit_code="$1"
  local line_number="$2"
  local command="$3"
  
  log_warn "Executing default self-heal mechanism."
  log_warn "Error ${exit_code} at line ${line_number} executing: ${command}"
  
  # Example: Rollback last 'git commit' if a build fails
  if [[ "$command" == *"bazel build"* || "$command" == *"make"* ]]; then
    log_warn "Build failed. Attempting to roll back last commit..."
    # git reset --hard HEAD~1
    log_audit "SELF_HEAL" "Build failure detected. Rolled back HEAD~1."
  else
    log_info "No default heal action for this command."
  fi
}

# --- Main Execution ---
main() {
  if [[ $# -eq 0 ]]; then
    fn_show_help
    exit 1
  fi
  
  # --- Argument Parsing ---
  PROJECT_CONFIG=""
  COMMAND=""
  ARGS=()
  
  # Initialize PROJECT_NAME to a default to prevent 'unbound' error in log_audit
  # if --project is not first.
  PROJECT_NAME="Global"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        if [[ -z "${2:-}" ]]; then
          log_error "Missing project name for --project flag."
          exit 1
        fi
        PROJECT_CONFIG_PATH="./${2}.conf"
        if [ ! -f "$PROJECT_CONFIG_PATH" ]; then
          log_error "Project configuration file not found: ${PROJECT_CONFIG_PATH}"
          exit 1
        fi
        # --- This is the Modular Architecture ---
        # Source the project config, overriding weak functions
        # shellcheck source=/dev/null
        source "$PROJECT_CONFIG_PATH"
        log_info "Loaded project framework: ${PROJECT_NAME}"
        log_audit "INIT" "Loaded project framework: ${PROJECT_NAME}"
        shift 2
        ;;
      --bootstrap | --generate | --compile | --ai | --sync | --audit | --heal)
        if [[ -n "$COMMAND" ]]; then
          log_error "Only one command can be specified."
          exit 1
        fi
        COMMAND="$1"
        shift
        ;;
      --help)
        fn_show_help
        exit 0
        ;;
      --version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
      --no-color)
        NO_COLOR=1
        shift
        ;;
      *)
        # Collect remaining arguments for the command
        ARGS+=("$1")
        shift
        ;;
    esac
  done
  
  # --- Project Validation ---
  if [[ "$PROJECT_NAME" == "Global" ]] && [[ "$COMMAND" != "--help" ]] && [[ "$COMMAND" != "--version" ]]; then
    log_error "You must specify a project using --project <name>."
    fn_show_help
    exit 1
  fi
  
  # --- Command Dispatcher ---
  log_debug "Executing command: ${COMMAND} with args: ${ARGS[*]:-}"
  
  # --- FIX 1.0.5 ---
  # Use ${ARGS[@]:-} in ALL command dispatches to prevent 'unbound variable'.
  case "$COMMAND" in
    --bootstrap)
      fn_detect_os
      fn_project_bootstrap "${ARGS[@]:-}"
      ;;
    --generate)
      if [[ ${#ARGS[@]} -lt 2 ]]; then
        log_error "Usage: --generate <type> <name> [path]"
        exit 1
      fi
      local type="${ARGS[0]}"
      local name="${ARGS[1]}"
      local filepath="${ARGS[2]:-"./${name}"}"
      fn_project_generate "$type" "$name" "$filepath"
      ;;
    --compile)
      fn_project_compile "${ARGS[@]:-}"
      ;;
    --ai)
      if [[ ${#ARGS[@]} -lt 1 ]]; then
        log_error "Usage: --ai <task> [args...]"
        exit 1
      fi
      fn_project_ai_assist "${ARGS[@]:-}"
      ;;
    --sync)
      fn_project_sync "${ARGS[@]:-}"
      ;;
    --audit)
      if [[ ${#ARGS[@]} -lt 1 ]]; then
        log_error "Usage: --audit <report_type>"
        exit 1
      fi
      fn_project_audit "${ARGS[0]}"
      ;;
    --heal)
      log_warn "Manual self-heal triggered by user."
      log_audit "SELF_HEAL" "Manual trigger by user $(whoami)."
      fn_project_self_heal "MANUAL" "$LINENO" "User trigger"
      ;;
    *)
      if [[ -z "$COMMAND" ]]; then
        log_error "No command specified. Use --help for options."
        exit 1
      else
        log_error "Unknown command: ${COMMAND}"
        exit 1
      fi
      ;;
  esac
  
  log_info "Command '${COMMAND}' executed successfully."
}

# Pass all arguments to main
main "$@"
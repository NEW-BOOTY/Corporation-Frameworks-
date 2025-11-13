#!/usr/bin/env bash
#
# Copyright © 2025 Devin B. Royal.
# All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Enterprise Governance Meta-Builder (v1.0.6)
#
# This script is the core, production-grade engine for the Enterprise
# Governance Framework. It is designed to be a universal, self-healing
# meta-builder that loads project-specific logic from .conf files.
#
# Authored for Devin Benard Royal, CTO.
#
# v1.0.6 Fixes:
# - Corrected logging in fn_install_packages to show all packages, not just one.
#

# --- Strict Mode & Error Handling ---
# set -euo pipefail:
#   -e: Exit immediately if a command exits with a non-zero status.
#   -u: Treat unset variables as an error when substituting.
#   -o pipefail: The return value of a pipeline is the status of
#                the last command to exit with a non-zero status,
#                or zero if no command exited with a non-zero status.
set -euo pipefail

# --- Global Variables ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="1.0.6"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_CONFIG=""
PROJECT_NAME=""
LOG_DIR="${HOME}/.logs/meta_builder"
LOG_FILE="${LOG_DIR}/meta_builder_$(date +%Y%m%d).log"

# --- OS Detection Globals ---
OS=""
OS_ARCH=""
PKG_MANAGER=""

# --- Logging & Color Functions (Moved to Top) ---
# Initialize color variables
RESET=""
BOLD=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
NC="" # No Color (alias for RESET)

# Check if stdout is a TTY and NO_COLOR is not set
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RESET="\033[0m"
  BOLD="\033[1m"
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  BLUE="\033[0;34m"
  NC="\033[0m"
fi

fn_setup_logging() {
  # Create log directory and file
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
}

fn_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_entry="${timestamp} [${level}] ${message}"
  
  # Write to log file
  echo "${log_entry}" >> "$LOG_FILE"
  
  # Write to stderr if it's a TTY
  if [[ -t 1 ]]; then
    case "$level" in
      INFO)
        echo -e "${GREEN}${log_entry}${NC}" >&2
        ;;
      WARN)
        echo -e "${YELLOW}${log_entry}${NC}" >&2
        ;;
      ERROR)
        echo -e "${RED}${log_entry}${NC}" >&2
        ;;
      DEBUG)
        echo -e "${BLUE}${log_entry}${NC}" >&2
        ;;
      AUDIT)
        echo -e "${BOLD}${log_entry}${NC}" >&2
        ;;
      *)
        echo -e "${log_entry}" >&2
        ;;
    esac
  fi
}

# Logging helper functions
fn_log_info() { fn_log "INFO" "$*"; }
fn_log_warn() { fn_log "WARN" "$*"; }
fn_log_error() { fn_log "ERROR" "$*"; }
fn_log_debug() { fn_log "DEBUG" "$*"; }
fn_log_audit() { fn_log "AUDIT" "$*"; }

# --- Error Handling & Cleanup (Moved to Top) ---

fn_handle_error() {
  local exit_code=$1
  local line_number=$2
  local command_that_failed=$3
  fn_log_error "Execution failed:"
  fn_log_error "  Exit Code: ${exit_code}"
  fn_log_error "  Line: ${line_number}"
  fn_log_error "  Command: ${command_that_failed}"
  
  # Attempt to call the project-specific self-healing function
  fn_log_warn "Attempting project-specific self-healing..."
  if command -v fn_project_self_heal &>/dev/null; then
    # Pass all relevant info to the healer
    fn_project_self_heal "${exit_code}" "${line_number}" "${command_that_failed}" "${COMMAND}"
  else
    fn_log_warn "No project-specific self-heal function (fn_project_self_heal) defined."
  fi
}

fn_cleanup() {
  # This function is called on script EXIT
  fn_log_info "Meta-Builder session finished."
}

# --- Set Traps ---
# These must be set *after* the functions they call are defined.
trap 'fn_handle_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'fn_cleanup' EXIT

# --- Core Engine Functions ---

fn_show_help() {
  # Using echo -e for color compatibility
  echo -e "${BOLD}Enterprise Governance Meta-Builder (v${SCRIPT_VERSION})${RESET}"
  echo -e "Authored by Devin B. Royal, CTO. Copyright © 2025."
  echo ""
  echo -e "${BOLD}USAGE:${RESET}"
  echo "  $SCRIPT_NAME --project <name> [command] [options]"
  echo ""
  echo -e "${BOLD}PROJECT:${RESET}"
  echo -e "  ${YELLOW}--project <name>${NC}   Load a project configuration (e.g., 'chimera', 'sentry')."
  echo ""
  echo -e "${BOLD}CORE COMMANDS:${RESET}"
  echo -e "  ${YELLOW}--bootstrap${NC}        Bootstraps the development environment. Detects OS, installs packages, keys."
  echo -e "  ${YELLOW}--generate <type> <name>${NC} Generate a new artifact (e.g., 'script', 'module', 'license')."
  echo -e "  ${YELLOW}--compile <target>${NC}  Compile a specific target or the entire project."
  echo -e "  ${YELLOW}--ai <task> [args...]${NC} Run an AI-assisted task (e.g., 'validate', 'commit', 'remediate')."
  echo -e "  ${YELLOW}--sync${NC}             Run privacy-aware rclone synchronization."
  echo -e "  ${YELLOW}--audit <report>${NC}   Generate a compliance or audit report (e.g., 'spdx', 'risk')."
  echo -e "  ${YELLOW}--heal${NC}             Manually trigger the self-healing and rollback mechanism."
  echo ""
  echo -e "${BOLD}OTHER FLAGS:${RESET}"
  echo -e "  ${YELLOW}--help${NC}             Show this help message."
  echo -e "  ${YELLOW}--version${NC}          Show the script version."
  echo -e "  ${YELLOW}--no-color${NC}         Disable color output."
}

fn_detect_os() {
  # This function sets the global vars: OS, OS_ARCH, PKG_MANAGER
  OS_ARCH=$(uname -m)
  case "$(uname -s)" in
    Linux)
      OS='linux'
      if command -v apt-get &>/dev/null; then
        PKG_MANAGER='apt'
      elif command -v dnf &>/dev/null; then
        PKG_MANAGER='dnf'
      elif command -v yum &>/dev/null; then
        PKG_MANAGER='yum'
      elif command -v pacman &>/dev/null; then
        PKG_MANAGER='pacman'
      else
        fn_log_error "Unsupported Linux package manager."
        return 1
      fi
      ;;
    Darwin)
      OS='macos'
      if ! command -v brew &>/dev/null; then
        fn_log_error "Homebrew (brew) not found. Please install it."
        return 1
      fi
      PKG_MANAGER='brew'
      ;;
    *)
      OS='unknown'
      PKG_MANAGER='unknown'
      fn_log_error "Unsupported OS: $(uname -s)"
      return 1
      ;;
  esac
  fn_log_info "Detected OS: ${OS} (Package Manager: ${PKG_MANAGER})"
}

fn_install_packages() {
  if [[ $# -eq 0 ]]; then
    fn_log_warn "No packages requested for installation."
    return 0
  fi
  
  # v1.0.6 fix: Use "$*" to log all packages as a single string
  fn_log_info "Installing packages: $*"
  
  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update
      sudo apt-get install -y "$@"
      ;;
    dnf | yum)
      # Use "$PKG_MANAGER" variable to call correct command
      sudo "${PKG_MANAGER}" install -y "$@"
      ;;
    pacman)
      sudo pacman -Syu --noconfirm "$@"
      ;;
    brew)
      # Homebrew doesn't need sudo
      brew install "$@"
      ;;
    *)
      fn_log_error "Cannot install packages: unknown package manager."
      return 1
      ;;
  esac
}

# --- Main Execution ---

main() {
  # 1. Setup Logging (Must be first)
  fn_setup_logging
  
  # 2. Parse Global Flags (Help, Version, Project)
  if [[ $# -eq 0 ]]; then
    fn_show_help
    return 0
  fi
  
  # Global flags
  local COMMAND=""
  local ARGS=()
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        if [[ -z "${2:-}" ]]; then
          fn_log_error "Error: --project flag requires an argument."
          return 1
        fi
        PROJECT_CONFIG="${SCRIPT_DIR}/${2}.conf"
        shift 2
        ;;
      --help)
        fn_show_help
        return 0
        ;;
      --version)
        echo "$SCRIPT_VERSION"
        return 0
        ;;
      --no-color)
        # Re-initialize color variables as empty
        RESET=""
        BOLD=""
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
        shift
        ;;
      --*)
        # This is a command, break the loop
        COMMAND="$1"
        shift
        break
        ;;
      *)
        fn_log_error "Unknown option: $1"
        fn_show_help
        return 1
        ;;
    esac
  done
  
  # 3. Validate Project Config
  if [[ -z "$PROJECT_CONFIG" ]]; then
    fn_log_error "Error: --project <name> is a required flag."
    fn_show_help
    return 1
  fi
  
  if [[ ! -f "$PROJECT_CONFIG" ]]; then
    fn_log_error "Error: Project config file not found: $PROJECT_CONFIG"
    fn_log_error "Please run the phase_2_generator.sh script first."
    return 1
  fi
  
  # 4. Load Project Config
  # This sources the .conf file, loading all project-specific functions
  # (fn_project_bootstrap, fn_project_compile, etc.)
  # shellcheck source=/dev/null
  source "$PROJECT_CONFIG"
  
  # $PROJECT_NAME is set inside the .conf file
  fn_log_info "Loaded project framework: ${PROJECT_NAME}"

  # 5. Store remaining arguments
  # v1.0.5 fix: Use : - to provide a default empty value for unbound variable check
  ARGS=("$@")
  
  # 6. Dispatch Command
  if [[ -z "$COMMAND" ]]; then
    fn_log_error "No command specified (e.g., --bootstrap, --compile)."
    fn_show_help
    return 1
  fi
  
  fn_log_debug "Executing command: ${COMMAND} with args: ${ARGS[*]:-}"
  
  # v1.0.5 fix: Use "${ARGS[@]:-}" in all dispatches to handle empty array
  case "$COMMAND" in
    --bootstrap)
      fn_project_bootstrap "${ARGS[@]:-}"
      ;;
    --generate)
      fn_project_generate "${ARGS[@]:-}"
      ;;
    --compile)
      fn_project_compile "${ARGS[@]:-}"
      ;;
    --ai)
      fn_project_ai_assist "${ARGS[@]:-}"
      ;;
    --sync)
      fn_project_sync "${ARGS[@]:-}"
      ;;
    --audit)
      fn_project_audit "${ARGS[@]:-}"
      ;;
    --heal)
      fn_log_warn "Manual self-heal triggered."
      # Call with placeholder values for a manual trigger
      fn_project_self_heal "MANUAL" "$LINENO" "manual_trigger" "$COMMAND"
      ;;
    *)
      fn_log_error "Unknown command: $COMMAND"
      fn_show_help
      return 1
      ;;
  esac
  
  fn_log_info "Command '${COMMAND}' executed successfully."
}

# Pass all arguments to main
main "$@"
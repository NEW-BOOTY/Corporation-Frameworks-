#!/usr/bin/env bash
# /*
#  * Copyright © 2025 Devin B. Royal.
#  * All Rights Reserved.
#  */
#
# SPDX-License-Identifier: Apache-2.0
#
# Enterprise-Meta-Builder.sh
# Version: 1.0.6
#
# Universal meta-builder for multi-corporate governance frameworks.
# Loads a project-specific .conf plugin and dispatches commands with
# robust logging, error handling, and self-healing hooks.

set -euo pipefail

# ------------- Color & TTY Handling -------------

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  RED="\033[0;31m"
  RESET="\033[0m"
else
  BOLD=""
  GREEN=""
  YELLOW=""
  RED=""
  RESET=""
fi

# ------------- Global State -------------

SCRIPT_NAME="$(basename "${0}")"
VERSION="1.0.6"
LOG_ROOT="${HOME}/.logs/meta_builder"
mkdir -p "${LOG_ROOT}"

TIMESTAMP="$(date -u +%Y%m%d)"
LOG_FILE="${LOG_ROOT}/meta_builder_${TIMESTAMP}.log"

# Initialize project-level globals
PROJECT_ID=""
PROJECT_CONF=""
PROJECT_NAME=""

COMMAND=""
# Always initialize ARGS as an empty array to keep set -u happy.
ARGS=()

# ------------- Logging Helpers -------------

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_raw() {
  local level="$1"; shift || true
  local msg="$*"
  printf "%s [%s] %s\n" "$(timestamp)" "${level}" "${msg}" | tee -a "${LOG_FILE}"
}

log_info()  { log_raw "INFO"  "$*"; }
log_warn()  { log_raw "WARN"  "$*"; }
log_error() { log_raw "ERROR" "$*"; }
log_audit() {
  local action="$1"; shift || true
  local detail="$*"
  printf "%s [%s] %s | %s\n" "$(timestamp)" "AUDIT" "${action}" "${detail}" | tee -a "${LOG_FILE}"
}
log_debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    log_raw "DEBUG" "$*"
  fi
}

# ------------- Error Handling & Cleanup -------------

fn_project_self_heal_safe() {
  # Call project self-heal only if defined.
  local exit_code="$1"
  if declare -F fn_project_self_heal >/dev/null 2>&1; then
    fn_project_self_heal "${exit_code}" || true
  else
    log_warn "Project self-heal hook not defined; skipping."
  fi
}

fn_handle_error() {
  local exit_code="$?"
  local line_no="${BASH_LINENO[0]:-0}"
  local cmd="${BASH_COMMAND:-unknown}"
  log_error "Execution failed:"
  log_error "  Exit Code: ${exit_code}"
  log_error "  Line: ${line_no}"
  log_error "  Command: ${cmd}"
  # Attempt project-level self healing
  fn_project_self_heal_safe "${exit_code}"
}

fn_cleanup() {
  log_info "Meta-Builder session finished."
}

trap fn_handle_error ERR
trap fn_cleanup EXIT

# ------------- OS & Package Management -------------

OS_TYPE="unknown"
PKG_MGR=""

fn_detect_os() {
  local uname_s
  uname_s="$(uname -s || echo "Unknown")"
  case "${uname_s}" in
    Darwin)
      OS_TYPE="macos"
      PKG_MGR="brew"
      ;;
    Linux)
      OS_TYPE="linux"
      if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
      elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
      else
        PKG_MGR="unknown"
      fi
      ;;
    *)
      OS_TYPE="unknown"
      PKG_MGR="unknown"
      ;;
  esac
  log_info "Detected OS: ${OS_TYPE} (Package Manager: ${PKG_MGR:-none})"
}

fn_install_packages() {
  if [[ "$#" -eq 0 ]]; then
    log_warn "fn_install_packages called with no packages."
    return 0
  fi

  log_info "Installing packages: $*"

  case "${PKG_MGR}" in
    brew)
      if ! command -v brew >/dev/null 2>&1; then
        log_warn "Homebrew not found. Skipping actual installation."
        return 0
      fi
      # Protect against set -e by using an explicit test.
      if ! brew install "$@"; then
        log_warn "brew install failed for: $* (continuing)"
        return 0
      fi
      ;;
    apt)
      if ! command -v apt-get >/dev/null 2>&1; then
        log_warn "apt-get not found. Skipping installation."
        return 0
      fi
      if ! sudo apt-get update; then
        log_warn "apt-get update failed (continuing)."
      fi
      if ! sudo apt-get install -y "$@"; then
        log_warn "apt-get install failed for: $* (continuing)."
        return 0
      fi
      ;;
    yum)
      if ! command -v yum >/dev/null 2>&1; then
        log_warn "yum not found. Skipping installation."
        return 0
      fi
      if ! sudo yum install -y "$@"; then
        log_warn "yum install failed for: $* (continuing)."
        return 0
      fi
      ;;
    *)
      log_warn "Unknown package manager '${PKG_MGR}'. Packages not installed."
      ;;
  esac
}

# ------------- Usage -------------

show_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} - Enterprise Governance Meta-Builder (v${VERSION})

Usage:
  ${SCRIPT_NAME} --project <id> <command> [args...]

Required:
  --project <id>       One of: chimera, sentry, aegis, veritas, synergy, clarity, orchard, connect

Commands:
  --bootstrap          Bootstrap environment for the selected project
  --compile [target]   Run project compile/build step (optional target)
  --audit <type>       Run project-specific audit (e.g., spdx, risk-score)
  --ai-assist <task>   Run AI-assist workflow (project-specific)
  --help               Show this help

Examples:
  ${SCRIPT_NAME} --project chimera --bootstrap
  ${SCRIPT_NAME} --project sentry --audit risk-score
  ${SCRIPT_NAME} --project clarity --ai-assist ip-detect
EOF
}

# ------------- Plugin Loading -------------

fn_load_project_conf() {
  case "${PROJECT_ID}" in
    chimera|sentry|aegis|veritas|synergy|clarity|orchard|connect)
      PROJECT_CONF="${PROJECT_ID}.conf"
      ;;
    *)
      log_error "Unknown project id: ${PROJECT_ID}"
      show_help
      exit 1
      ;;
  esac

  if [[ ! -f "${PROJECT_CONF}" ]]; then
    log_error "Project configuration file not found: ${PROJECT_CONF}"
    log_error "Make sure to run phase_2_generator.sh first to create all *.conf files."
    exit 1
  fi

  # shellcheck source=/dev/null
  source "${PROJECT_CONF}"

  if [[ -z "${PROJECT_NAME:-}" ]]; then
    PROJECT_NAME="Unknown Project (${PROJECT_ID})"
  fi

  log_info "Loaded project framework: ${PROJECT_NAME}"
}

# ------------- Argument Parsing -------------

fn_parse_args() {
  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 0
  fi

  local i=1
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --project)
        shift || true
        PROJECT_ID="${1:-}"
        if [[ -z "${PROJECT_ID}" ]]; then
          log_error "--project requires an argument."
          exit 1
        fi
        ;;
      --bootstrap|--compile|--audit|--ai-assist|--help)
        if [[ -n "${COMMAND}" ]]; then
          log_error "Only one primary command may be specified."
          exit 1
        fi
        COMMAND="$1"
        ;;
      --debug)
        DEBUG=1
        ;;
      *)
        # Remaining args belong to the command.
        ARGS+=("$1")
        ;;
    esac
    shift || true
    ((i++)) || true
  done

  if [[ -z "${PROJECT_ID}" && "${COMMAND}" != "--help" ]]; then
    log_error "Missing required --project argument."
    show_help
    exit 1
  fi
}

# ------------- Command Dispatch -------------

fn_dispatch() {
  if [[ "${COMMAND}" == "--help" || -z "${COMMAND}" ]]; then
    show_help
    return 0
  fi

  # Ensure common runtime state (OS, package manager).
  fn_detect_os

  log_debug "Executing command: ${COMMAND} with args: ${ARGS[*]:-}"

  case "${COMMAND}" in
    --bootstrap)
      if ! declare -F fn_project_bootstrap >/dev/null 2>&1; then
        log_error "fn_project_bootstrap is not defined in ${PROJECT_CONF}."
        exit 1
      fi
      fn_project_bootstrap "${ARGS[@]:-}"
      ;;
    --compile)
      if ! declare -F fn_project_compile >/dev/null 2>&1; then
        log_error "fn_project_compile is not defined in ${PROJECT_CONF}."
        exit 1
      fi
      fn_project_compile "${ARGS[@]:-}"
      ;;
    --audit)
      if ! declare -F fn_project_audit >/dev/null 2>&1; then
        log_error "fn_project_audit is not defined in ${PROJECT_CONF}."
        exit 1
      fi
      if [[ "${#ARGS[@]}" -lt 1 ]]; then
        log_error "--audit requires an audit type argument."
        exit 1
      fi
      fn_project_audit "${ARGS[@]:-}"
      ;;
    --ai-assist)
      if ! declare -F fn_project_ai_assist >/dev/null 2>&1; then
        log_error "fn_project_ai_assist is not defined in ${PROJECT_CONF}."
        exit 1
      fi
      if [[ "${#ARGS[@]}" -lt 1 ]]; then
        log_error "--ai-assist requires a task argument."
        exit 1
      fi
      fn_project_ai_assist "${ARGS[@]:-}"
      ;;
    *)
      log_error "Unknown command: ${COMMAND}"
      show_help
      exit 1
      ;;
  esac

  log_info "Command '${COMMAND}' executed successfully."
}

# ------------- Main -------------

main() {
  # Ensure log file exists and is writable.
  : > "${LOG_FILE}" || {
    echo "ERROR: Cannot write to log file: ${LOG_FILE}" >&2
    exit 1
  }

  log_info "Starting ${SCRIPT_NAME} v${VERSION}"

  fn_parse_args "$@"

  if [[ "${COMMAND}" != "--help" ]]; then
    fn_load_project_conf
  fi

  fn_dispatch
}

main "$@"

# /*
#  * Copyright © 2025 Devin B. Royal.
#  * All Rights Reserved.
#  */

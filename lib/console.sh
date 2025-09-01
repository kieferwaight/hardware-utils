#!/usr/bin/bash
# console.sh - Logging & error handling utilities
# Provides functions for logging messages with different severity levels.

set -e

if [ -z "${RED+x}" ]; then readonly RED="\033[1;31m"; fi
if [ -z "${GREEN+x}" ]; then readonly GREEN="\033[1;32m"; fi
if [ -z "${YELLOW+x}" ]; then readonly YELLOW="\033[1;33m"; fi
if [ -z "${CYAN+x}" ]; then readonly CYAN="\033[1;36m"; fi
if [ -z "${RESET+x}" ]; then readonly RESET="\033[0m"; fi

log()    { printf "%b\n" "${GREEN}[*]${RESET} $1"; }
warn()   { printf "%b\n" "${YELLOW}[!]${RESET} $1"; }
info()   { printf "%b\n" "${CYAN}[*]${RESET} $1"; }
error()  { printf "%b\n" "${RED}[!]${RESET} $1" >&2; }
fail()   { error "$1"; exit 1; }

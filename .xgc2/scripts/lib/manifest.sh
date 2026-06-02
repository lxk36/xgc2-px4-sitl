#!/usr/bin/env bash

manifest_path() {
  if [[ -n "${PX4_RUNTIME_MANIFEST:-}" ]]; then
    printf '%s\n' "${PX4_RUNTIME_MANIFEST}"
    return
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s\n' "${script_dir}/../manifest/px4_runtime.yaml"
}

manifest_value() {
  local key="$1"
  local manifest
  manifest="$(manifest_path)"

  awk -v key="${key}" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*:" {
      value = $0
      sub("^[[:space:]]*" key "[[:space:]]*:[[:space:]]*", "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      print value
      exit
    }
  ' "${manifest}"
}

require_manifest_value() {
  local key="$1"
  local value
  value="$(manifest_value "${key}")"
  if [[ -z "${value}" ]]; then
    echo "missing manifest key: ${key}" >&2
    exit 1
  fi
  printf '%s\n' "${value}"
}

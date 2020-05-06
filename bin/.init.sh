#!/usr/bin/env bash

function check_for_dependencies() {
  hash apigeetool 1>&2 2>/dev/null || (error "Missing dependency: apigeetool" && exit 2)
}

function parse_common_arguments() {
  # Defaults
  APIGEE_URL=${APIGEE_URL:-https://api.enterprise.apigee.com}

  # Common arguments
  while getopts 'e:H:m:o:p:P:u:' option; do
    case "$option" in
      e )
        APIGEE_ENV="$OPTARG"
        ;;
      m )
        APIGEE_MFA_CODE="$OPTARG"
        ;;
      o )
        APIGEE_ORGANIZATION="$OPTARG"
        ;;
      P )
        APIGEE_PASSCODE="$OPTARG"
        ;;
      p )
        APIGEE_PASSWORD="$OPTARG"
        ;;
      u )
        APIGEE_USERNAME="$OPTARG"
        ;;
      U )
        APIGEE_URL="$OPTARG"
        ;;
    esac
  done

  shift $((OPTIND -1))
}

function check_credentials() {
  info "Verifying credentials..."
  local url="$1"
  local org="$2"
  local username="$3"
  local password="$4"

  response="$(curl -s -o /dev/null -I -w "%{http_code}" $url/v1/organizations/$org -u "$username:$password")"

  if [ $response -eq 401 ]; then
    error "Authentication failed!"
    error "Please re-run the script using the correct username/password."
    exit 2
  elif [ $response -eq 403 ]; then
    error "Organization $org is invalid!"
    error "Please re-run the script using the right org."
    exit 3
  else
    info "Credentials verfied! Proceeding with deployment."
  fi
}

function get-auth-token() {
  local username="${APIGEE_USERNAME:-}"
  local password="${APIGEE_PASSWORD:-}"
  local mfa_code="${APIGEE_MFA_CODE:-}"
  local passcode="${APIGEE_PASSCODE:-}"

  local creds="$username"
  if [[ -n "$password" ]]; then
    creds="$creds:$password"
  fi

  info "Getting an Authorization token"
  TOKEN=$(get_token \
    -u "$username:$password" \
    -m "$mfa_code" \
    -p "$passcode"
  )

  echo "$TOKEN"
}

###
# @env DEPLOY_COMMAND The apigeetool command to deploy with
# @env DEPLOY_REQUIRED_DIR The directory that files are required to be in
##
function apigee-deploy() {
  local command="$DEPLOY_COMMAND"
  local required_dir="$DEPLOY_REQUIRED_DIR"

  local url="${APIGEE_URL}"
  local org="${APIGEE_ORGANIZATION}"
  local env="${APIGEE_ENV:-test}"

  local username="${APIGEE_USERNAME:-}"
  local password="${APIGEE_PASSWORD:-}"

  local build="${BUILD_DIR:-build}"
  local directory="$1"
  local name="${2:-}"

  # We can just use the directory name if not provided
  if [[ -z "${name}" ]]; then
    name="$(basename "$directory")"
  fi

  local base_dir="$build/$name"
  local out_dir="$base_dir/$required_dir"

  info "Building bundle from $directory"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  for file in "$directory"/*; do
    local filename="$(basename "$file")"
    if [[ -d "$file" ]]; then
      debug "Found a directory: $filename"
      cp -r "$file" "$out_dir"
    fi

    if [[ -f "$file" && "${file##*.}" == xml ]]; then
      debug "Found a file: $filename"
      cp "$file" "$out_dir"
    fi
  done

  local token="$(get-auth-token)"

  # check_credentials "$url" "$org" "$username" "$password"
  info "Asking the apigeetool to deploy $name from $base_dir"
  apigeetool "$command" \
    -n "$name" \
    -o "$org" \
    -e "$env" \
    -L "$url" \
    -u "$username" \
    -p "$password" \
    -d "$base_dir" \
    -t "$token" \
    -V
}

function load_init() {
  function _log() {
    {
      local args=$-
      set +x

      local reset=$'\e[39m'
      local no_color="${NO_COLOR:-false}"

      local color="$1"
      shift
      local id="$1"
      shift

      echo -n '['

      if [[ ${no_color} != true ]]; then
        echo -en "${color}"
      fi

      echo -n "$id"

      if [[ ${no_color} != true ]]; then
        echo -en "${reset}"
      fi
      echo -n '] '

      echo "${@:-}"

      set $args
    } >&2
  }

  function debug() {
    if [[ "${DEBUG:-false}" == true ]]; then
      _log $'\e[96m' DEBUG "$*"
    fi
  }
  export -f debug

  function info() {
    _log $'\e[92m' INFO "$*"
  }
  export -f info

  function warn() {
    _log $'\e[93m' WARN "$*"
  }
  export -f warn

  function error() {
    _log $'\e[91m' ERROR "$*"
  }
  export -f error
}

if [[ ${__INIT_LOADED:-false} == true ]]; then
  :
else
  load_init
  check_for_dependencies
  parse_common_arguments

  export __INIT_LOADED=true
fi

# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/.init.sh

#!/bin/bash

fail() {
  echo "${red}$@${reset}" >&2
  exit 1
}

cleanup () {
  [[ -e $support_extract ]] && rm -rf "$support_extract"

  for f in "${temp_files[@]}"; do
    rm -f "$f"
  done
}

usage() {
  cat <<EOF
usage: $0 <job> <support_script_archive>
<job> may be one of ${cmds[@]}
EOF
}

# main
shopt -s nocasematch
set -o pipefail
red="$(tput setaf 1)"
reset="$(tput sgr0)"
declare -A db_names db_tables du_dbs
temp_files=()
cmds=("db_sizes" "modules")

trap 'cleanup' ERR SIGINT SIGKILL SIGTERM EXIT

# Source all *sh scripts in the bin directory under this script.  Works regardless of where this is called from
_base_dir="${BASH_SOURCE[0]%/*}"
for f in "$_base_dir"/bin/*sh; do source "$f"; done

type jq &>/dev/null || fail "jq not installed"

# Only one job at a time for now...
if (( $# != 2 )) || [[ $@ =~ --help ]]; then
  usage
  exit 1
fi

job="$1"
[[ " ${cmds[@]} " =~ " $job " ]] || {
  usage
  fail "ERROR: invalid job name $job"
}

support_gz="$2"
[[ -e $support_gz ]] || fail "couldn't find support extract"

support_extract="$(mktemp -d)"
# Strip the toplevel directory of the extract and put it directly in our temp dir so we don't have to worry about the name
tar -xf "$support_gz" -C "$support_extract" --strip-components=1 || fail "failed to extract archive"

# Assume v1 support script if no metadata.json or empty v3 field
if [[ -e $support_extract/metadata.json ]]; then
  v3="$(jq '.v3' <"$support_extract/metadata.json")" || fail "couldn't extract metadata"
else
  v3=
fi

# This processing only differs in file names, so we'll only have one function for now
case "$job" in
  db_sizes)
    case "$v3" in
      *)
        v1_db_parse "$support_extract"
    esac ;;

  modules)
    case "$v3" in
      "true")
        v3_modules_parse "$support_extract"
        ;;
      *)
        v1_modules_parse "$support_extract"
    esac ;;
  esac

  exit

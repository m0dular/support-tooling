#!/bin/bash

fail() {
   echo "${red}$@${reset}" >&2
   exit 1
}

v1_parse() {
   # Parse and format db_relation_sizes.txt
   db_sizes="$1/resources/db_relation_sizes.txt"
   [[ -e $db_sizes ]] || fail "couldn't find db_relation_sizes.txt"

   # Get a unique list of database names from the first column, i.e. starting with pe
   dbs=($(awk -F '|' '{ print $1 }' <"$db_sizes" | grep '^[[:space:]]*pe' | sort -u))

   db_sizes_temp="$(mktemp)"
   temp_files+=("$db_sizes_temp")

   # Iterate over every line of the file containing table info
   mapfile -t lines < <(sed -n "/^[[:space:]]*pe/p" "$db_sizes")
   for line in "${lines[@]}"; do
      IFS='|' read -ra fields <<<"${line//\ /}"

      db="${fields[0]}"; table="${fields[1]}";
      # Convert human readable sizes output by pg_size_pretty into those numfmt can understand
      # e.g. 1600 bytes --> 1600, 16kB --> 16K
      size="${fields[-1]}"; size="${size//bytes/}"; size="${size//b/}"
      size="$(echo "${size^^}" | numfmt --from=iec)"

      echo "${db}|${table}|${size}" >>"$db_sizes_temp"

   done

   # Parse and format db_sizes_from_du.txt
   du_sizes="$1/resources/db_sizes_from_du.txt"
   [[ -e $du_sizes ]] || fail "couldn't find db_sizes_from_du.txt"

   du_sizes_temp="$(mktemp)"
   temp_files+=("$du_sizes_temp")
   # du output doesn't prefix the tables with "pe-", so create a string like 'activity|orchestrator' etc to pass to grep -E
   du_grep="$(IFS='|'; echo "${dbs[*]//pe-/}")"

   mapfile -t lines < <(grep -E "$dbs_grep" "$du_sizes" )

   # pass each size value to numfmt, adding to the totals in our associative array
   for db in "${dbs[@]//pe-/}"; do
      for line in "${lines[@]}"; do
         IFS=$'\t' read -ra fields <<<"$line"

         if [[ ${fields[1]} =~ $db ]]; then
            size="$(echo ${fields[0]} | numfmt --from=iec)"
            (( du_dbs["$db"]+="$size" ))
         fi
      done
   done

   # Create a pipe delimited file with the databases and sizes
   for db in "${!du_dbs[@]}"; do
      echo "pe-${db}|${du_dbs[$db]}" >>"$du_sizes_temp"
   done

   ./json_format_v1.py "$db_sizes_temp" "$du_sizes_temp" || fail "couldn't create json"
}

v2_parse() {
   :
}

cleanup () {
   [[ -e $support_extract ]] && rm -rf "$support_extract"

   for f in "${temp_files[@]}"; do
      rm -f "$f"
   done
}

# main

if (( $# != 1 )) || [[ $@ =~ --help ]]; then
   echo "usage: $0 <support_script_archive>"
   exit 1
fi

shopt -s nocasematch
set -o pipefail
red="$(tput setaf 1)"
reset="$(tput sgr0)"
declare -A db_names db_tables du_dbs
temp_files=()

trap 'cleanup' ERR SIGINT SIGKILL SIGTERM EXIT

type jq &>/dev/null || fail "jq not installed"

support_gz="$1"
[[ -e $support_gz ]] || fail "couldn't find support extract"

support_extract="$(mktemp -d)"
# Strip the toplevel directory of the extract and put it directly in out temp dir so we don't have to worry about the name
tar -xf "$support_gz" -C "$support_extract" --strip-components=1 || fail "failed to extract archive"

# Assume v1 support script if no metadata.json or empty ticket field
# TODO: how will this work
if [[ -e $support_extract/metadata.json ]]; then
   ticket="$(jq '.ticket' <"$support_extract/metadata.json")" || fail "couldn't extract metadata"
else
   ticket=
fi

case "$ticket" in
   *)
      v1_parse "$support_extract"
esac

exit

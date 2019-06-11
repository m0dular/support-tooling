v1_db_parse() {
   # Parse and format db relation sizes. File differs between versions
   if [[ -e "$1/resources/db_relation_sizes.txt" ]]; then
     db_sizes="$1/resources/db_relation_sizes.txt"
   elif [[ -e "$1/resources/db_relation_sizes_from_psql.txt" ]]; then
     db_sizes="$1/resources/db_relation_sizes_from_psql.txt"
   else
     fail "No suitable relation sizes file found"
   fi

   # Get a unique list of database names from the first column, i.e. starting with pe
   dbs=($(awk -F '|' '{ print $1 }' <"$db_sizes" | grep '^[[:space:]]*pe' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort -u))

   db_sizes_temp="$(mktemp)"
   temp_files+=("$db_sizes_temp")

   # Iterate over every line of the file containing table info
   mapfile -t lines < <(sed -n "/^[[:space:]]\+pe/p" "$db_sizes")
   for line in "${lines[@]}"; do
      IFS='|' read -ra fields <<<"${line//\ /}"

      db="${fields[0]}"; table="${fields[1]}";
      # Convert human readable sizes output by pg_size_pretty into those numfmt can understand
      # e.g. 1600 bytes --> 1600, 16kB --> 16K
      size="${fields[-1]}"; size="${size//bytes/}"; size="${size//[bB]/}"
      size="$(echo "${size^^}" | numfmt --from=iec)"

      echo "${db}|${table}|${size}" >>"$db_sizes_temp"

   done

   # Parse and format db sizes from_du. File differs between versions
   if [[ -e "$1/resources/db_sizes_from_du.txt" ]]; then
     du_sizes="$1/resources/db_sizes_from_du.txt"
   elif [[ -e "$1/resources/db_table_sizes_from_du.txt" ]]; then
     du_sizes="$1/resources/db_sizes_from_du.txt"
   else
     fail "No suitable du table sizes file found"
   fi

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

   "$_base_dir"/bin/db_sizes_format_v1.py "$db_sizes_temp" "$du_sizes_temp" || fail "couldn't create json"
}

v1_modules_parse() {
   _modules_temp="$(mktemp)"
   temp_files+=("$_modules_temp")

   # If we have this file, just add a modules total to each environment and we're done
   if [[ -e "$1/enterprise/modules.json" ]]; then
      jq -cM 'map(. + { "total_modules": .modules | length })' <"$1/enterprise/modules.json" || fail "couldn't create json"
      return

   # If not, we should have a listing of /etc/puppetlabs/code/environments/*/modules and /opt/puppetlabs/puppet/modules
   elif [[ -e "$1/enterprise/find/_opt_puppetlabs.txt" && -e "$1/enterprise/find/_etc_puppetlabs.txt" ]]; then
      enterprise_mods=($(grep -o '/opt/puppetlabs/puppet/modules/[^/]*' "$1/enterprise/find/_opt_puppetlabs.txt"  | sort -u))
      enterprise_mods=("${enterprise_mods[@]//\/opt\/puppetlabs\/puppet\/modules\/}")
      echo "enterprise_mods: ${enterprise_mods[@]}"

      envs=($(grep -o '/etc/puppetlabs/code/environments/[^/]*' "$1/enterprise/find/_etc_puppetlabs.txt" | sort -u))
      env_mods=($(grep -o '/etc/puppetlabs/code/environments/[^/]*/modules/[^/]*/' "$1/enterprise/find/_etc_puppetlabs.txt" | sort -u))

   # Possibly in a .txt.gz
   elif [[ -e "$1/enterprise/find/_opt_puppetlabs.txt.gz" && -e "$1/enterprise/find/_etc_puppetlabs.txt.gz" ]]; then
      enterprise_mods=($(zgrep -o '/opt/puppetlabs/puppet/modules/[^/]*' "$1/enterprise/find/_opt_puppetlabs.txt.gz"  | sort -u))
      enterprise_mods=("${enterprise_mods[@]//\/opt\/puppetlabs\/puppet\/modules\/}")

      envs=($(zgrep -o '/etc/puppetlabs/code/environments/[^/]*' "$1/enterprise/find/_etc_puppetlabs.txt.gz" | sort -u))
      env_mods=($(zgrep -o '/etc/puppetlabs/code/environments/[^/]*/modules/[^/]*' "$1/enterprise/find/_etc_puppetlabs.txt.gz" | sort -u))

   else
      fail "No suitable module files found"
   fi

# Build a file with each environment and module list on separate lines
# e.g. production:stdlib|zsh
for env in "${envs[@]}"; do
   echo -n "${env##*/}:" >>"$_modules_temp"

   for mod in "${env_mods[@]}"; do
      [[ $mod =~ ^$env ]] && echo -n "${mod##*/}|" >>"$_modules_temp"
   done

   # Modules in /opt/puppetlabs/puppet/modules apply to all environments
   (IFS='|'; echo "${enterprise_mods[*]}") >>"$_modules_temp"
done

"$_base_dir"/bin/modules_format_v1.py "$_modules_temp" || exit 1

}


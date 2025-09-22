_mulle_platform_complete()
{
   local cur prev words cword

   _get_comp_words_by_ref -n : cur prev words cword

   local cmd="${words[1]}"
   local i=1

   # Global options
   case "$cur" in
      -*)
         COMPREPLY=($(compgen -W "-f --force -h --help --version" -- "$cur"))
         return 0
      ;;
   esac

   # No command yet, complete commands
   if [[ $cword -eq 1 ]]; then
      COMPREPLY=($(compgen -W "env environment search includepath searchpath translate wholearchive sdkpath libexec-dir uname version" -- "$cur"))
      return 0
   fi

   # Check for verboseness or hidden commands
   # Since it's hard to check MULLE_FLAG_LOG_VERBOSE here, include hidden commands anyway
   if [[ $cword -eq 1 ]]; then
      COMPREPLY=($(compgen -W "env environment search includepath searchpath translate wholearchive sdkpath libexec-dir uname version" -- "$cur"))
      return 0
   fi

   case "$cmd" in
      env|environment)
         if [[ "$prev" == --platform ]]; then
            COMPREPLY=($(compgen -W "$(uname -s | tr '[:upper:]' '[:lower:]')" -- "$cur"))  # Default to current, but fixed
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "-b --build-tools --no-build-tools -l --library --no-library --platform" -- "$cur"))
            return 0
         fi
         ;;
      search)
         if [[ "$prev" == --prefer || "$prev" == --require ]]; then
            COMPREPLY=($(compgen -W "static dynamic" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --type ]]; then
            COMPREPLY=($(compgen -W "library standalone framework" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --output-format ]]; then
            COMPREPLY=($(compgen -W "file ld" -- "$cur"))  # As per usage
            return 0
         fi
         if [[ "$prev" == --searchpath ]]; then
            COMPREPLY=($(compgen -d -- "$cur"))  # Directory paths
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--prefer --require --searchpath --type --output-format" -- "$cur"))
            return 0
         fi
         ;;
      includepath)
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--cmake" -- "$cur"))
            return 0
         fi
         ;;
      searchpath)
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "" -- "$cur"))  # No options
            return 0
         fi
         ;;
      translate)
         # Many options, list key ones
         if [[ "$prev" == --output-format ]]; then
            COMPREPLY=($(compgen -W "ld file ldpath ld_library_path path rpath" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --separator ]]; then
            COMPREPLY=($(compgen -W "$(printf '%q\n' $'\n')" -- "$cur"))  # Suggest newline or other
            return 0
         fi
         if [[ "$prev" == --quote ]]; then
            COMPREPLY=($(compgen -W "\"" "'" -- "$cur"))
            return 0
         fi
         if [[ "$prev" == --option || "$prev" == --prefix || "$prev" == --mode || "$prev" == --marks || "$prev" == --preferred-library-style || "$prev" == --whole-archive-format ]]; then
            COMPREPLY=()  # Free form
            return 0
         fi
         if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--option --output-format --separator --quote --prefix --mode --marks --preferred-library-style --whole-archive-format --dynamic --static --standalone --fake-uname" -- "$cur"))
            return 0
         fi
         COMPREPLY=($(compgen -f -- "$cur"))  # File paths for <filename>
         return 0
         ;;
      wholearchive)
         # No options, no args
         ;;
      sdkpath|libexec-dir|uname|version)
         ;;  # No options or args
   esac

   return 0
}

complete -F _mulle_platform_complete mulle-platform

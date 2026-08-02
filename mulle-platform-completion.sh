# shellcheck shell=bash
#
#   bash completion for mulle-platform
#
#   Generates intelligent, context-aware completions for all commands,
#   subcommands and options of mulle-platform.
#
#   Strategies used:
#     1. Static tables below mirror the dispatch in `mulle-platform` and the
#        option parsing in src/*.sh (always available, fast).
#     2. Dynamic discovery merges commands/options from `mulle-platform -h`
#        and `mulle-platform <cmd> [<subcmd>] -h` when the tool is on PATH
#        (results cached, falls back to static on any failure).
#     3. Option argument completion for enums (platform, language, dialect,
#        configuration, ...), paths and libraries.
#
#   Source this file from your .bashrc, e.g.:
#
#      . /path/to/mulle-platform/mulle-platform-completion.sh
#

# ---------------------------------------------------------------------------------
# Static value tables
#   mirror the enum values parsed out of src/*.sh
# ---------------------------------------------------------------------------------

__mulle_platform_global_options="-f --force -h --help --version help -n --dry-run -s --silent --silent-but-warn -v --verbose -V --no-verbose -vv --very-verbose -vvv --very-very-verbose -ld --log-debug -le --log-environment -ls --log-settings -lx --log-exekutor --log-execution -lt --trace -tfpwd --trace-full-pwd -tp --trace-profile -tpwd --trace-pwd -tx --trace-immediately -t- --mulle-clear-flags --mulle-list-technical-flags --mulle-no-colors --mulle-no-errors"

__mulle_platform_static_commands="compile compiler crosscompiler-root emulator env environment export flags includepath languages link linker quirks search searchpath translate wholearchive sdkpath libexec-dir uname version"

__mulle_platform_compiler_subcommands="run env list flags"
__mulle_platform_linker_subcommands="run env list flags"
__mulle_platform_quirks_subcommands="list show check"

__mulle_platform_platforms="linux darwin mingw windows freebsd openbsd netbsd dragonfly sunos bsd msys"
__mulle_platform_languages="c cpp objc objcpp"
__mulle_platform_dialects="c objc objcpp cpp mulle-objc"
__mulle_platform_configurations="Debug Release Test RelWithDebInfo"
__mulle_platform_compiler_types="gcc clang mulle-clang msvc cl icc icpc xlc xlC"
__mulle_platform_linker_types="ld gold lld link"
__mulle_platform_sanitizers="address thread undefined memory leak"
__mulle_platform_flag_types="compile link both"
__mulle_platform_library_types="library standalone framework"
__mulle_platform_static_dynamic="static dynamic"
__mulle_platform_search_output_formats="file ld"
__mulle_platform_translate_output_formats="ld file ldpath ld_library_path path rpath"
__mulle_platform_wholearchive_formats="DEFAULT STATIC whole-archive force-load none whole-archive-win as-needed"
__mulle_platform_quirks="mingw-needs-link-flag needs-exported-symbols windows-needs-dll-path msvc-needs-md-flag needs-pic-for-shared supports-rpath needs-framework-flag needs-whole-archive uses-dyld uses-ld-library-path supports-sanitizer-address supports-sanitizer-thread supports-sanitizer-undefined supports-sanitizer-memory supports-sanitizer-leak supports-coverage"

__mulle_platform_source_exts='*.@(c|m|aam|mm|cpp|cxx|cc|C)'
__mulle_platform_object_exts='*.@(o|obj|a|so|so.[0-9]*|dylib|dll|lib)'

# ---------------------------------------------------------------------------------
# Caches
#   populated lazily, once per shell session
# ---------------------------------------------------------------------------------

__mulle_platform_cached_commands=
__mulle_platform_cached_libraries=
__mulle_platform_dynamic_failed='NO'


# ---------------------------------------------------------------------------------
# Dynamic discovery helpers
#   best-effort: on any failure the static tables are used instead
# ---------------------------------------------------------------------------------

__mulle_platform_dynamic_tool()
{
   local bin="${MULLE_PLATFORM_COMPLETION_BIN:-mulle-platform}"
   local out

   command -v "${bin}" >/dev/null 2>&1 || return 1
   command -v timeout >/dev/null 2>&1  || return 1

   out="$(timeout 2 "${bin}" "$@" 2>&1)"
   if [ $? -eq 0 ] && [ -n "${out}" ]
   then
      printf '%s' "${out}"
      return 0
   fi
   return 1
}


__mulle_platform_dynamic_commands()
{
   local out

   [ "${__mulle_platform_dynamic_failed}" = 'NO' ] || return 1

   if out="$(__mulle_platform_dynamic_tool -h)"
   then
      printf '%s\n' "${out}" \
         | sed -n '/^Commands:/,$p' \
         | sed -n -E 's/^[[:space:]]+([A-Za-z0-9][A-Za-z0-9-]*).*/\1/p' \
         | sort -u \
         | tr '\n' ' '
      return 0
   fi

   __mulle_platform_dynamic_failed='YES'
   return 1
}


__mulle_platform_dynamic_options()
{
   local cmd="$1"
   local subcmd="${2:-}"
   local out

   [ "${__mulle_platform_dynamic_failed}" = 'NO' ] || return 1

   if out="$(__mulle_platform_dynamic_tool ${cmd} ${subcmd} -h)"
   then
      printf '%s\n' "${out}" \
         | sed -n '/^Options:/,$p' \
         | sed -n -E 's/^[[:space:]]+(--?[^[:space:]<]*).*/\1/p' \
         | sort -u \
         | tr '\n' ' '
      return 0
   fi

   __mulle_platform_dynamic_failed='YES'
   return 1
}


# ---------------------------------------------------------------------------------
# Command list
# ---------------------------------------------------------------------------------

__mulle_platform_commands()
{
   local list dyn

   if [ -n "${__mulle_platform_cached_commands}" ]
   then
      printf '%s' "${__mulle_platform_cached_commands}"
      return 0
   fi

   list="${__mulle_platform_static_commands}"

   if dyn="$(__mulle_platform_dynamic_commands)"
   then
      list="$(printf '%s %s' "${list}" "${dyn}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
   fi

   __mulle_platform_cached_commands="${list% }"
   printf '%s' "${list% }"
}


# ---------------------------------------------------------------------------------
# Options per command/subcommand
#   static part is authoritative; dynamic discovery extends it with new
#   options that were added after this file was written.
# ---------------------------------------------------------------------------------

__mulle_platform_static_options()
{
   local cmd="$1"
   local subcmd="${2:-}"

   case "${cmd}:${subcmd}" in
      compile:*|compiler:run)
         printf '%s\n' "--platform --language --dialect --objc-dialect --configuration --no-default-cflags --compiler-type -F -I -D -c --shared --sanitizer --coverage --export-symbol --export-dynamic --output-asm --emit-llvm --show-headers --rpath -L -l --wholearchive -Wl, -o --print-only --"
      ;;

      compiler:env)
         printf '%s\n' "--platform --language --dialect --objc-dialect --compiler-type --print-env --print-json"
      ;;

      compiler:list)
         printf '%s\n' "-v --verbose"
      ;;

      compiler:flags|flags:*)
         printf '%s\n' "--platform --language --dialect --objc-dialect --configuration --compiler-type --type --sanitizer --print-env --print-list"
      ;;

      crosscompiler-root:*)
         printf '%s\n' "--compiler --platform"
      ;;

      emulator:*)
         printf '%s\n' "--platform"
      ;;

      env:*|environment:*)
         printf '%s\n' "-b --build-tools --no-build-tools -l --library --no-library -p --os --platform"
      ;;

      export:*)
         printf '%s\n' "--platform --compiler-type --compiler --linker"
      ;;

      includepath:*)
         printf '%s\n' "--cmake"
      ;;

      languages:*)
         printf '%s\n' "--compiler-type"
      ;;

      link:*|linker:run)
         printf '%s\n' "--platform --language --dialect --objc-dialect --configuration --compiler-type -L -l -F -framework -o --shared --print-only --"
      ;;

      linker:env)
         printf '%s\n' "--platform --language --dialect --linker-type --print-env --print-json"
      ;;

      linker:list)
         printf '%s\n' "--platform -v --verbose"
      ;;

      linker:flags)
         printf '%s\n' "--platform --language --dialect --configuration --linker-type --type --print-env --print-list"
      ;;

      quirks:*)
         printf '%s\n' "--platform"
      ;;

      search:*)
         printf '%s\n' "--prefer --require --platform --searchpath --search-path --type --output-format"
      ;;

      translate:*)
         printf '%s\n' "--dynamic --static --standalone --fake-uname -p --os --platform --marks --mode --option --prefix --preferred-library-style --quote --separator --output-format --whole-archive-format --"
      ;;
   esac
}


__mulle_platform_command_options()
{
   local cmd="$1"
   local subcmd="${2:-}"
   local opts dyn

   opts="$(__mulle_platform_static_options "${cmd}" "${subcmd}")"

   if dyn="$(__mulle_platform_dynamic_options "${cmd}" "${subcmd}")"
   then
      opts="$(printf '%s %s' "${opts}" "${dyn}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
   fi

   printf '%s' "${opts}"
}


# ---------------------------------------------------------------------------------
# Low level completion helpers
# ---------------------------------------------------------------------------------

__mulle_platform_complete_words()
{
   if [ $# -eq 1 ] && [ -n "$1" ]
   then
      COMPREPLY=( $(compgen -W "$1" -- "${cur}") )
   else
      COMPREPLY=()
   fi
}


__mulle_platform_complete_dirs()
{
   COMPREPLY=( $(compgen -d -- "$1") )
}


__mulle_platform_complete_files()
{
   local extpat="$1"

   if [ -n "${extpat}" ] && [ -z "${cur}" ]
   then
      local old
      old="$(shopt -p extglob)" || old="shopt -s extglob"
      shopt -s extglob 2>/dev/null
      COMPREPLY=( $(compgen -f -X "!${extpat}" -- "${cur}") )
      eval "${old}" 2>/dev/null
      if [ ${#COMPREPLY[@]} -eq 0 ]
      then
         COMPREPLY=( $(compgen -f -- "${cur}") )
      fi
   else
      COMPREPLY=( $(compgen -f -- "${cur}") )
   fi
}


# Discover installed library names for -l, --wholearchive and `search`
__mulle_platform_complete_libraries()
{
   if [ -z "${__mulle_platform_cached_libraries}" ]
   then
      local list=""
      local d f base
      local IFS=':'

      for d in ${LD_LIBRARY_PATH:-} ${MULLE_PLATFORM_LIBRARY_PATH:-} /usr/local/lib /usr/lib /lib /opt/homebrew/lib /usr/local/lib64 /usr/lib64
      do
         [ -d "${d}" ] || continue

         for f in "${d}"/lib*.a "${d}"/lib*.so "${d}"/lib*.so.* "${d}"/lib*.dylib "${d}"/lib*.lib
         do
            [ -f "${f}" ] || continue

            base="$(basename -- "${f}")"
            case "${base}" in
               lib*.so.*)  base="${base#lib}"; base="${base%%.so.*}" ;;
               lib*.so)    base="${base#lib}"; base="${base%.so}" ;;
               lib*.dylib) base="${base#lib}"; base="${base%.dylib}" ;;
               lib*.a)     base="${base#lib}"; base="${base%.a}" ;;
               lib*.lib)   base="${base#lib}"; base="${base%.lib}" ;;
            esac

            case "${list}" in
               *" ${base} "*) ;;
               *) list="${list} ${base} " ;;
            esac
         done
      done

      __mulle_platform_cached_libraries="${list}"
   fi

   if [ -n "${__mulle_platform_cached_libraries}" ]
   then
      __mulle_platform_complete_words "${__mulle_platform_cached_libraries}"
   fi
}


# Complete the value of the option in $prev
# returns 0 when handled, 1 to fall through to default handling
__mulle_platform_option_arg()
{
   local cmd="$1"
   local subcmd="${2:-}"
   local prev="$3"

   case "${prev}" in
      --platform|-p|--os|--fake-uname)
         __mulle_platform_complete_words "${__mulle_platform_platforms}"
      ;;

      --language)
         __mulle_platform_complete_words "${__mulle_platform_languages}"
      ;;

      --dialect|--objc-dialect)
         __mulle_platform_complete_words "${__mulle_platform_dialects}"
      ;;

      --configuration)
         __mulle_platform_complete_words "${__mulle_platform_configurations}"
      ;;

      --compiler-type)
         __mulle_platform_complete_words "${__mulle_platform_compiler_types}"
      ;;

      --compiler)
         if [ "${cmd}" = "crosscompiler-root" ]
         then
            __mulle_platform_complete_words "${__mulle_platform_compiler_types}"
         else
            return 1
         fi
      ;;

      --linker-type)
         __mulle_platform_complete_words "${__mulle_platform_linker_types}"
      ;;

      --sanitizer)
         __mulle_platform_complete_words "${__mulle_platform_sanitizers}"
      ;;

      --type)
         if [ "${cmd}" = "search" ]
         then
            __mulle_platform_complete_words "${__mulle_platform_library_types}"
         else
            __mulle_platform_complete_words "${__mulle_platform_flag_types}"
         fi
      ;;

      --prefer|--require)
         __mulle_platform_complete_words "${__mulle_platform_static_dynamic}"
      ;;

      --search-path|--searchpath)
         __mulle_platform_complete_dirs "${cur}"
      ;;

      --output-format)
         case "${cmd}" in
            search)
               __mulle_platform_complete_words "${__mulle_platform_search_output_formats}"
            ;;
            translate)
               __mulle_platform_complete_words "${__mulle_platform_translate_output_formats}"
            ;;
            *)
               return 1
            ;;
         esac
      ;;

      --whole-archive-format)
         __mulle_platform_complete_words "${__mulle_platform_wholearchive_formats}"
      ;;

      -L|-F|-I|--rpath)
         __mulle_platform_complete_dirs "${cur}"
      ;;

      -o)
         __mulle_platform_complete_files
      ;;

      -l|--wholearchive)
         __mulle_platform_complete_libraries
      ;;

      -D|-Wl,|-framework|--marks|--mode|--option|--prefix|--preferred-library-style|--quote|--separator|--export-symbol)
         COMPREPLY=()
      ;;

      *)
         return 1
      ;;
   esac

   return 0
}


# ---------------------------------------------------------------------------------
# Main completion function
# ---------------------------------------------------------------------------------

_mulle_platform_complete()
{
   local cur prev words cword
   local cmd="" subcmd=""
   local cmd_index=0
   local i j opts

   if declare -F _get_comp_words_by_ref >/dev/null 2>&1
   then
      _get_comp_words_by_ref -n : cur prev words cword
   else
      cur="${COMP_WORDS[COMP_CWORD]}"
      prev="${COMP_WORDS[COMP_CWORD-1]}"
      words=("${COMP_WORDS[@]}")
      cword="${COMP_CWORD}"
   fi

   COMPREPLY=()

   # find the command: the first non-option word on the command line
   # (global flags never take a value, so a naive skip of "-*" is safe)
   for ((i=1; i<cword; i++))
   do
      case "${words[i]}" in
         -*) ;;
         *)  cmd="${words[i]}"; cmd_index="${i}"; break ;;
      esac
   done

   # no command yet
   if [ -z "${cmd}" ]
   then
      case "${cur}" in
         -*)
            __mulle_platform_complete_words "${__mulle_platform_global_options}"
         ;;
         *)
            __mulle_platform_complete_words "$(__mulle_platform_commands)"
         ;;
      esac
      return 0
   fi

   # figure out the subcommand (quirks allows leading options with values,
   # e.g. "quirks --platform linux check", so skip option/value pairs there)
   if [ "${cword}" -gt $((cmd_index+1)) ]
   then
      j=$((cmd_index+1))
      case "${cmd}" in
         quirks)
            while [ "${j}" -lt "${cword}" ]
            do
               case "${words[j]}" in
                  --platform|--os|-p) j=$((j+2)) ;;
                  -*)                  j=$((j+1)) ;;
                  *)                   subcmd="${words[j]}"; break ;;
               esac
            done
         ;;
         *)
            case "${words[j]}" in
               -*) ;;
               *) subcmd="${words[j]}" ;;
            esac
         ;;
      esac
   fi

   # completing the subcommand itself
   if [ "${cword}" -eq $((cmd_index+1)) ]
   then
      case "${cmd}" in
         compiler) __mulle_platform_complete_words "${__mulle_platform_compiler_subcommands}" ;;
         linker)   __mulle_platform_complete_words "${__mulle_platform_linker_subcommands}" ;;
         quirks)   __mulle_platform_complete_words "${__mulle_platform_quirks_subcommands}" ;;
      esac
      return 0
   fi

   # glued directory options: -L/path, -I/path, -F/path
   case "${cur}" in
      -L*) __mulle_platform_complete_dirs "${cur#-L}"; return 0 ;;
      -I*) __mulle_platform_complete_dirs "${cur#-I}"; return 0 ;;
      -F*) __mulle_platform_complete_dirs "${cur#-F}"; return 0 ;;
   esac

   # value of the previous option
   if __mulle_platform_option_arg "${cmd}" "${subcmd}" "${prev}"
   then
      return 0
   fi

   # quirk name for "quirks check"
   if [ "${cmd}" = "quirks" ] && [ "${subcmd}" = "check" ]
   then
      __mulle_platform_complete_words "${__mulle_platform_quirks}"
      return 0
   fi

   # in-flight option
   if [[ "${cur}" == -* ]]
   then
      opts="$(__mulle_platform_command_options "${cmd}" "${subcmd}")"
      __mulle_platform_complete_words "${opts}"
      return 0
   fi

   # context-aware positional completion
   case "${cmd}" in
      compile)
         __mulle_platform_complete_files "${__mulle_platform_source_exts}"
      ;;
      compiler)
         if [ "${subcmd}" = "run" ]
         then
            __mulle_platform_complete_files "${__mulle_platform_source_exts}"
         fi
      ;;
      link)
         __mulle_platform_complete_files "${__mulle_platform_object_exts}"
      ;;
      linker)
         if [ "${subcmd}" = "run" ]
         then
            __mulle_platform_complete_files "${__mulle_platform_object_exts}"
         fi
      ;;
      translate|wholearchive)
         __mulle_platform_complete_files
      ;;
      search)
         __mulle_platform_complete_libraries
      ;;
   esac

   return 0
}


complete -F _mulle_platform_complete mulle-platform
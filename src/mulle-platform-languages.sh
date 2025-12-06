# shellcheck shell=bash
#
#   Copyright (c) 2024 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#

MULLE_PLATFORM_LANGUAGES_SH='included'


platform::languages::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} languages [options]

   List available languages and their dialects from compiler plugins.

Options:
   --compiler-type <type>   : Show languages for specific compiler (gcc, clang, msvc)

Example:
   mulle-platform languages
   mulle-platform languages --compiler-type gcc

EOF
   exit 1
}


platform::languages::main()
{
   log_entry "platform::languages::main" "$@"

   local OPTION_COMPILER_TYPE

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::languages::usage
         ;;

         --compiler-type)
            [ $# -eq 1 ] && platform::languages::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER_TYPE="$1"
         ;;

         -*)
            platform::languages::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::languages::usage "Superfluous arguments \"$*\""

   include "platform::plugin"

   local compiler_types
   local compiler_type
   local language
   local dialect

   # Determine which compiler types to query
   if [ ! -z "${OPTION_COMPILER_TYPE}" ]
   then
      compiler_types="${OPTION_COMPILER_TYPE}"
   else
      compiler_types="$(platform::plugin::list_compilers)"
   fi

   # Query each compiler plugin
   .foreachline compiler_type in ${compiler_types}
   .do
      if ! platform::plugin::load_compiler "${compiler_type}"
      then
         log_verbose "Skipping compiler type '${compiler_type}' (plugin not found)"
         .continue
      fi

      local get_languages_func="platform::plugin::compiler::${compiler_type}::get_languages"
      local get_dialects_func="platform::plugin::compiler::${compiler_type}::get_dialects"

      if ! shell_is_function "${get_languages_func}"
      then
         log_verbose "Compiler '${compiler_type}' does not support get_languages"
         .continue
      fi

      printf "Compiler Type: %s\n" "${compiler_type}"

      .foreachline language in `"${get_languages_func}"`
      .do
         if shell_is_function "${get_dialects_func}"
         then
            local dialects
            dialects="$("${get_dialects_func}" "${language}" | tr '\n' ', ' | sed 's/,$//')"
            printf "  %s: %s\n" "${language}" "${dialects}"
         else
            printf "  %s\n" "${language}"
         fi
      .done

      printf "\n"
   .done
}

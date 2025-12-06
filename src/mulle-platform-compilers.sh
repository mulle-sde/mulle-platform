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

MULLE_PLATFORM_COMPILERS_SH='included'


platform::compilers::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} compilers [options]

   List installed compilers on the system.

Options:
   --verbose                : Show full paths and version information

Example:
   mulle-platform compilers
   mulle-platform compilers --verbose

EOF
   exit 1
}


platform::compilers::check_compiler()
{
   log_entry "platform::compilers::check_compiler" "$@"

   local compiler="$1"
   local verbose="$2"

   if command -v "${compiler}" >/dev/null 2>&1
   then
      if [ "${verbose}" = "YES" ]
      then
         local path
         local version

         path="$(command -v "${compiler}")"
         version="$("${compiler}" --version 2>&1 | head -1 || echo "version unavailable")"

         printf "  %-20s : %s\n" "${compiler}" "${path}"
         printf "  %-20s   %s\n" "" "${version}"
      else
         printf "  %s\n" "${compiler}"
      fi
      return 0
   fi
   return 1
}


platform::compilers::main()
{
   log_entry "platform::compilers::main" "$@"

   local OPTION_VERBOSE='NO'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::compilers::usage
         ;;

         -v|--verbose)
            OPTION_VERBOSE='YES'
         ;;

         -*)
            platform::compilers::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::compilers::usage "Superfluous arguments \"$*\""

   # List of common compilers to check
   local gcc_compilers="gcc g++ cc c++"
   local clang_compilers="clang clang++ mulle-clang"
   local msvc_compilers="cl cl.exe"
   local other_compilers="icc icpc xlc xlC"

   local found_any='NO'

   # Check GCC family
   printf "GCC/GNU Compilers:\n"
   local compiler
   for compiler in ${gcc_compilers}
   do
      if platform::compilers::check_compiler "${compiler}" "${OPTION_VERBOSE}"
      then
         found_any='YES'
      fi
   done
   printf "\n"

   # Check Clang family
   printf "Clang/LLVM Compilers:\n"
   for compiler in ${clang_compilers}
   do
      if platform::compilers::check_compiler "${compiler}" "${OPTION_VERBOSE}"
      then
         found_any='YES'
      fi
   done
   printf "\n"

   # Check MSVC
   printf "MSVC Compilers:\n"
   for compiler in ${msvc_compilers}
   do
      if platform::compilers::check_compiler "${compiler}" "${OPTION_VERBOSE}"
      then
         found_any='YES'
      fi
   done
   printf "\n"

   # Check other compilers
   printf "Other Compilers:\n"
   for compiler in ${other_compilers}
   do
      if platform::compilers::check_compiler "${compiler}" "${OPTION_VERBOSE}"
      then
         found_any='YES'
      fi
   done

   if [ "${found_any}" = 'NO' ]
   then
      log_warning "No compilers found in PATH"
      return 1
   fi

   return 0
}

# shellcheck shell=bash
#
#   Copyright (c) 2025 Nat! - Mulle kybernetiK
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

MULLE_PLATFORM_LINKER_LIST_SH='included'


platform::linker_list::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} linker list [options]

   List installed linkers on the system.

Options:
   --platform <name> : Platform to check (default: ${MULLE_UNAME})
   --verbose         : Show detailed information about each linker

Example:
   mulle-platform linker list
   mulle-platform linker list --verbose
EOF
   exit 1
}


platform::linker_list::main()
{
   log_entry "platform::linker_list::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_VERBOSE='NO'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::linker_list::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::linker_list::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         -v|--verbose)
            OPTION_VERBOSE='YES'
         ;;

         -*)
            platform::linker_list::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::linker_list::usage "Superfluous arguments \"$*\""

   # TODO: Implement actual linker detection and listing
   # For now, show placeholder output
   
   if [ "${OPTION_VERBOSE}" = 'YES' ]
   then
      printf "%-12s %-20s %s\n" "NAME" "PATH" "VERSION"
      printf "%-12s %-20s %s\n" "----" "----" "-------"
      printf "%-12s %-20s %s\n" "ld" "/usr/bin/ld" "TODO: detect version"
   else
      printf "%s\n" "ld"
   fi
}

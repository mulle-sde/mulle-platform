#! /usr/bin/env bash
#
#   Copyright (c) 2018 nat -
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
#   Neither the name of  nor the names of its contributors
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

MULLE_PLATFORM_INCLUDEPATH_SH="included"


platform::includepath::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-includepath}

   Show the includepath used on this platform for finding headers.
   For this to work best it is useful to have gcc or clang installed on the system.
EOF
   exit 1
}


#
# somewhat dependent on linux to have gcc/clang installed
#
platform::includepath::r_platform_includepath()
{
   log_entry "platform::includepath::r_platform_includepath" "$@"

   local separator="${1:-:}"

   if [ -z "${MULLE_PLATFORM_INCLUDEPATH}" ]
   then
      case "${MULLE_UNAME}" in
         *)
            MULLE_PLATFORM_INCLUDEPATH="/usr/local/include:/usr/include"
         ;;
      esac

      local cc
      local filepath

      cc="`mudo -f which gcc`"
      if [ -z "${cc}" ]
      then
         cc="`mudo -f which clang`"
      else
         if [ -z "${cc}" ]
         then
            cc="`mudo -f which mulle-clang`"
         fi
      fi

      if filepath="`rexekutor "${cc:-cc}" -E -Wp,-v -xc /dev/null 2>&1`"
      then
         filepath="`echo "${filepath}" \
               | sed -n -e '/^ /s/^\ \([^(]*\).*/\1/p' \
               | sed 's/[ \t]*$//' \
               | egrep -v '/Frameworks$' \
               | egrep -v '^$' \
               | tr '\012' "${separator}" `"
         filepath="${filepath%%:}"
         filepath="${filepath##:}"
         if [ ! -z "${filepath}" ]
         then
            MULLE_PLATFORM_INCLUDEPATH="${filepath}"
         fi
      else
         log_warning "Could not figure out system include paths, using platform defaults"
      fi
   fi

   RVAL="${MULLE_PLATFORM_INCLUDEPATH}"
   log_verbose "Platform header includepath: ${MULLE_PLATFORM_INCLUDEPATH}"
}


platform::includepath::main()
{
   log_entry "platform::includepath::main" "$@"

   local OPTION_SEPARATOR

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::includepath::usage
         ;;

         --cmake)
            OPTION_SEPARATOR=';'
         ;;

         -*)
            platform::includepath::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::includepath::usage "Superflous parameters \"$*\""

   platform::includepath::r_platform_includepath "${OPTION_SEPARATOR}"
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}

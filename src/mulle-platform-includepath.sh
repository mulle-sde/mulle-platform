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


platform_includepath_usage()
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
r_platform_includepath()
{
   log_entry "r_platform_includepath" "$@"

   local separator="${1:-:}"

   if [ -z "${MULLE_PLATFORM_INCLUDEPATH}" ]
   then
      case "${MULLE_UNAME}" in
         *)
            MULLE_PLATFORM_INCLUDEPATH="/usr/local/include:/usr/include"
         ;;
      esac

      local cc
      local path

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

      if path="`rexekutor "${cc:-cc}" -E -Wp,-v -xc /dev/null 2>&1`"
      then
         path="`echo "${path}" \
               | sed -n -e '/^ /s/^\ \([^(]*\).*/\1/p' \
               | sed 's/[ \t]*$//' \
               | egrep -v '/Frameworks$' \
               | egrep -v '^$' \
               | tr '\012' "${separator}" `"
         path="${path%%:}"
         path="${path##:}"
         if [ ! -z "${path}" ]
         then
            MULLE_PLATFORM_INCLUDEPATH="${path}"
         fi
      else
         log_warning "Could not figure out system include paths, using platform defaults"
      fi
   fi

   RVAL="${MULLE_PLATFORM_INCLUDEPATH}"
   log_verbose "Platform header includepath: ${MULLE_PLATFORM_INCLUDEPATH}"
}


platform_includepath_main()
{
   log_entry "platform_includepath_main" "$@"

   local OPTION_SEPARATOR

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform_includepath_usage
         ;;

         --cmake)
            OPTION_SEPARATOR=';'
         ;;

         -*)
            platform_includepath_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local name
   local directory

   [ $# -eq 0 ] || platform_includepath_usage "Superflous parameters \"$*\""

   r_platform_includepath "${OPTION_SEPARATOR}"
   echo "${RVAL}"
}

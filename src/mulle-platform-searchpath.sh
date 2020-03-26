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

MULLE_PLATFORM_SEARCHPATH_SH="included"


platform_searchpath_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-searchpath}

   Show the searchpath used on this platform for finding OS libraries.

Notes:
   On linux one
EOF
   exit 1
}


#
# somewhat dependent on linux to have gcc/clang installed
#
r_platform_searchpath()
{
   log_entry "r_platform_searchpath" "$@"

   if [ -z "${MULLE_PLATFORM_SEARCHPATH}" ]
   then
      case "${MULLE_UNAME}" in
         *)
            MULLE_PLATFORM_SEARCHPATH="/usr/local/lib:/usr/lib"
         ;;
      esac

      local cc

      cc="`mudo -f command -v "gcc"`"
      if [ -z "${cc}" ]
      then
         cc="`mudo -f command -v "clang"`"
      else
         if [ -z "${cc}" ]
         then
            cc="`mudo -f command -v "mulle-clang"`"
         fi
      fi

      local path

      case "${MULLE_UNAME}" in
         darwin)
            path="`xcrun --show-sdk-path`"
            if [ ! -z "${path}" ]
            then
               path="/usr/local/lib:${path}/usr/lib:/usr/lib"
            fi
         ;;

         *)
            path="`rexekutor "${cc:-cc}" -Xlinker --verbose  2>/dev/null \
                  | sed -n -e 's/SEARCH_DIR("=\?\([^"]\+\)"); */\1\n/gp'  \
                  | egrep -v '^$' \
                  | sed 's/[ \t]*$//' \
                  | tr '\012' ':' `"
         ;;
      esac

      if [ ! -z "${path}" ]
      then
         path="${path%%:}"
         path="${path##:}"
         if [ ! -z "${path}" ]
         then
            MULLE_PLATFORM_SEARCHPATH="${path}"
         fi
      else
         log_warning "Could not figure out system library paths, using platform defaults"
      fi
   fi

   RVAL="${MULLE_PLATFORM_SEARCHPATH}"
   log_verbose "Platform library searchpath: ${MULLE_PLATFORM_SEARCHPATH}"
}



platform_searchpath_main()
{
   log_entry "platform_searchpath_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform_searchpath_usage
         ;;

         -*)
            platform_searchpath_usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local name
   local directory

   [ $# -eq 0 ] || platform_searchpath_usage "Superflous parameters \"$*\""

   r_platform_searchpath
   echo "${RVAL}"
}

#! /usr/bin/env bash
#
#   Copyright (c) 2021 nat -
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

MULLE_PLATFORM_SDKPATH_SH="included"


platform::sdkpath::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-sdkpath}

   Show the SDK used on this platform.

Notes:
   Useful on darwin only.

EOF
   exit 1
}


platform::sdkpath::r_darwin_sdkpath()
{
   log_entry "platform::sdkpath::r_darwin_sdkpath" "$@"

   # on 10.6 this will fail as --show-sdk-path ain't there
   RVAL="`xcrun --show-sdk-path 2> /dev/null`"
   if [ -z "${RVAL}" ]
   then
      RVAL="`xcode-select -print-path 2> /dev/null`"
      if [ ! -d "${RVAL}" ]
      then
         fail "Doesn't look like a developer kit is installed.
${C_RESET_BOLD}xcrun${C_WARNING} and ${C_RESET_BOLD}xcode-select${C_WARNING} are missing."
      fi
   fi
}


platform::sdkpath::main()
{
   log_entry "platform::sdkpath::main" "$@"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::sdkpath::usage
         ;;

         -*)
            platform::sdkpath::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::sdkpath::usage "Superflous parameters \"$*\""

   local functionname

   functionname="platform::sdkpath::r_${MULLE_UNAME}_sdkpath"

   if ! shell_is_function "${functionname}"
   then
      return 0
   fi

   if ! ${functionname}
   then
      return 1
   fi

   printf "%s\n" "${RVAL}"
}


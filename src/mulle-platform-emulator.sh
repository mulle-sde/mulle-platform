# shellcheck shell=bash
#
#   Copyright (c) 2026 Nat! - Mulle kybernetiK
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

MULLE_PLATFORM_EMULATOR_SH='included'


platform::emulator::r_include_plugin()
{
   if [ -z "${MULLE_PLATFORM_PLUGIN_SH}" ]
   then
      # shellcheck source=src/mulle-platform-plugin.sh
      . "${MULLE_PLATFORM_LIBEXEC_DIR}/mulle-platform-plugin.sh" || return 1
   fi
}


platform::emulator::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} emulator [options]

   Get the default emulator for running binaries of a target platform on
   the current host platform. Returns empty if no emulator is needed or
   known.

Options:
   --platform <platform>  : Target platform to get emulator for (required)

Examples:
   mulle-platform emulator --platform windows
   # On Linux, might return: wine

EOF
   exit 1
}


platform::emulator::get()
{
   log_entry "platform::emulator::get" "$@"

   local target_platform="$1"
   local host_platform="${MULLE_UNAME}"

   # If target and host are the same, no emulator needed
   if [ "${target_platform}" = "${host_platform}" ]
   then
      return 0
   fi

   # Try to load host platform plugin and get emulator
   platform::emulator::r_include_plugin || return 1
   
   if platform::plugin::load_platform "${host_platform}"
   then
      local functionname="platform::plugin::platform::${host_platform}::r_emulator"
      if shell_is_function "${functionname}"
      then
         "${functionname}" "${target_platform}"
         [ -n "${RVAL}" ] && echo "${RVAL}"
         return 0
      fi
   fi

   return 0
}


platform::emulator::main()
{
   log_entry "platform::emulator::main" "$@"

   local OPTION_PLATFORM

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::emulator::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::emulator::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         -*)
            platform::emulator::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   [ $# -ne 0 ] && platform::emulator::usage "Superfluous arguments \"$*\""
   [ -z "${OPTION_PLATFORM}" ] && platform::emulator::usage "Missing --platform option"

   platform::emulator::get "${OPTION_PLATFORM}"
}

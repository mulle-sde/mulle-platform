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

MULLE_PLATFORM_LINKER_FLAGS_SH='included'


platform::linker_flags::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} linker flags [options]

   Generate platform and configuration-appropriate linker flags.
   Output is in environment variable format suitable for eval.

Options:
   --platform <name>        : Platform (default: ${MULLE_UNAME})
   --language <name>        : Language: c (default: c)
   --dialect <name>         : Dialect for the language (c has: c, objc)
   --configuration <name>   : Debug, Release, Test, RelWithDebInfo (default: Debug)
   --linker-type <type>     : Linker type (ld, gold, lld, link)
   --type <type>            : Flag type: link, or both (default: both)
   --print-env              : Output as environment variables (default)
   --print-list             : Output as space-separated list

Example:
   eval \`mulle-platform linker flags --configuration Release\`
   echo \${LDFLAGS}
EOF
   exit 1
}


platform::linker_flags::main()
{
   log_entry "platform::linker_flags::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"
   local OPTION_LANGUAGE="c"
   local OPTION_DIALECT="c"
   local OPTION_CONFIGURATION="Debug"
   local OPTION_LINKER_TYPE=""
   local OPTION_FLAG_TYPE="both"
   local OPTION_OUTPUT_FORMAT="env"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::linker_flags::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         --language)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_LANGUAGE="$1"
         ;;

         --dialect)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_DIALECT="$1"
         ;;

         --configuration)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_CONFIGURATION="$1"
         ;;

         --linker-type)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_LINKER_TYPE="$1"
         ;;

         --type)
            [ $# -eq 1 ] && platform::linker_flags::usage "Missing argument to \"$1\""
            shift
            OPTION_FLAG_TYPE="$1"
            case "${OPTION_FLAG_TYPE}" in
               link|both)
               ;;
               *)
                  platform::linker_flags::usage "Unknown flag type \"${OPTION_FLAG_TYPE}\""
               ;;
            esac
         ;;

         --print-env)
            OPTION_OUTPUT_FORMAT="env"
         ;;

         --print-list)
            OPTION_OUTPUT_FORMAT="list"
         ;;

         -*)
            platform::linker_flags::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::linker_flags::usage "Superfluous arguments \"$*\""

   # TODO: Implement actual linker flag generation logic
   # For now, return placeholder values
   local ldflags=""
   
   case "${OPTION_CONFIGURATION}" in
      Debug)
         ldflags="-g"
      ;;
      Release)
         ldflags="-O2"
      ;;
      *)
         ldflags=""
      ;;
   esac

   case "${OPTION_OUTPUT_FORMAT}" in
      env)
         printf 'LDFLAGS="%s"\n' "${ldflags}"
      ;;
      list)
         printf '%s\n' "${ldflags}"
      ;;
   esac
}

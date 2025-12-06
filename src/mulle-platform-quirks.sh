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

MULLE_PLATFORM_QUIRKS_SH='included'


platform::quirks::r_normalize_platform_name()
{
   log_entry "platform::quirks::r_normalize_platform_name" "$@"

   local platform="$1"

   # Normalize platform names to match plugin names
   case "${platform}" in
      mingw|msys)
         RVAL="windows"
      ;;
      
      *bsd|freebsd|openbsd|netbsd)
         RVAL="bsd"
      ;;
      
      dragonfly)
         RVAL="bsd"
      ;;
      
      *)
         RVAL="${platform}"
      ;;
   esac
}


platform::quirks::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} quirks [options] [list|show|check <name>]

   List platform-specific behaviors that need special handling.

Quirk Names:
   mingw-needs-link-flag              MinGW needs -link before linker args
   needs-exported-symbols             Darwin needs -Wl,-exported_symbol for dylibs
   windows-needs-dll-path             Windows needs DLL in PATH
   msvc-needs-md-flag                 MSVC needs /MD or /MDd
   needs-pic-for-shared               Platform needs -fPIC for shared libs
   supports-rpath                     Platform supports -rpath
   needs-framework-flag               Platform needs -framework flag (Darwin)
   needs-whole-archive                Platform needs whole-archive linking
   uses-dyld                          Platform uses DYLD for dynamic linking
   uses-ld-library-path               Platform uses LD_LIBRARY_PATH
   supports-sanitizer-address         Platform supports address sanitizer
   supports-sanitizer-thread          Platform supports thread sanitizer
   supports-sanitizer-undefined       Platform supports undefined behavior sanitizer
   supports-sanitizer-memory          Platform supports memory sanitizer
   supports-sanitizer-leak            Platform supports leak sanitizer
   supports-coverage                  Platform supports code coverage

Options:
   --platform <name>  : Platform to check (${MULLE_UNAME})

EOF
   exit 1
}

KNOWN_QUIRKS="\
mingw-needs-link-flag
needs-exported-symbols
windows-needs-dll-path
msvc-needs-md-flag
needs-pic-for-shared
supports-rpath
needs-framework-flag
needs-whole-archive
uses-dyld
uses-ld-library-path
supports-sanitizer-address
supports-sanitizer-thread
supports-sanitizer-undefined
supports-sanitizer-memory
supports-sanitizer-leak
supports-coverage"


platform::quirks::r_quirks()
{
   log_entry "platform::quirks::r_quirks" "$@"

   local platform="$1"

   # Normalize platform name to match plugin names
   local normalized_platform

   platform::quirks::r_normalize_platform_name "${platform}"
   normalized_platform="${RVAL}"

   # Try to load and use platform plugin
   include "platform::plugin"

   if platform::plugin::load_platform "${normalized_platform}"
   then
      local functionname

      functionname="platform::plugin::platform::${normalized_platform}::r_quirks"
      if shell_is_function "${functionname}"
      then
         "${functionname}"
         return $?
      fi
   fi

   log_warning "Unknown platform, assuming some defaults"
   # Fallback for platforms without plugins or generic quirks
   RVAL="needs-whole-archive
supports-rpath"
}


platform::quirks::show()
{
   log_entry "platform::quirks::show" "$@"

   sort <<< "${KNOWN_QUIRKS}"
}


platform::quirks::list()
{
   log_entry "platform::quirks::list" "$@"

   local platform="$1"

   platform::quirks::r_quirks "$1"
   sort <<< "${RVAL}"
}


platform::quirks::check()
{
   log_entry "platform::quirks::check" "$@"

   local platform="$1"
   local quirk="$2"

   platform::quirks::r_quirks "$1"
   find_line "${RVAL}" "${quirk}"
}


platform::quirks::main()
{
   log_entry "platform::quirks::main" "$@"

   local OPTION_PLATFORM="${MULLE_UNAME}"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::quirks::usage
         ;;

         --platform)
            [ $# -eq 1 ] && platform::quirks::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         -*)
            platform::quirks::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   local cmd=list

   if [ $# -gt 0 ]
   then
      cmd="$1"
      shift
   fi

   local quirk

   case "${cmd}" in
      'list')
         [ $# -eq 0 ] || platform::quirks::usage "Superfluous arguments \"$*\""
         platform::quirks::list "${OPTION_PLATFORM}"
      ;;

      'show')
         [ $# -eq 0 ] || platform::quirks::usage "Superfluous arguments \"$*\""
         platform::quirks::show
      ;;

      'check')
         [ $# -eq 0 ] && platform::quirks::usage "Missing quirk argument"

         quirk="$1"
         shift

         [ $# -eq 0 ] || platform::quirks::usage "Superfluous arguments \"$*\""

         platform::quirks::check "${OPTION_PLATFORM}" "${quirk}"
      ;;

      *)
         platform::quirks::usage "Unknown command \"${cmd}\""
      ;;
   esac
}

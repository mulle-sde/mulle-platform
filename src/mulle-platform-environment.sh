# shellcheck shell=bash
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

MULLE_PLATFORM_ENVIRONMENT_SH='included'


platform::environment::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} [options] environment

   Output a list of definitions pertaining to the chosen platform.
   F.e. on macOS expect to see a definition like this:

   MULLE_PLATFORM_SHLIB_EXTENSION=".dylib"

Example:
   local MULLE_PLATFORM_EXECUTABLE_SUFFIX
   local MULLE_PLATFORM_FRAMEWORK_PATH_LDFLAG
   local MULLE_PLATFORM_FRAMEWORK_PREFIX
   local MULLE_PLATFORM_FRAMEWORK_SUFFIX
   local MULLE_PLATFORM_LIBRARY_LDFLAG
   local MULLE_PLATFORM_LIBRARY_PATH_LDFLAG
   local MULLE_PLATFORM_LIBRARY_PREFIX
   local MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC
   local MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC
   local MULLE_PLATFORM_LINK_MODE
   local MULLE_PLATFORM_OBJECT_SUFFIX
   local MULLE_PLATFORM_RPATH_LDFLAG
   local MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_DEFAULT
   local MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_STATIC

   eval \`${MULLE_USAGE_NAME} environment --platform darwin\`

Options:
   --platform <os> : specify platform (${MULLE_UNAME})
   --build-tools   : output build tool definitions like CC
   --library       : output library flags and strings (default)
   --executable    : output executable flags and strings (default)

EOF
   exit 1
}


platform::environment::r_nomangle()
{
   RVAL="$1"
}


# TODO add this from mulle-objc-unarchive
# r_shlib_cflags()
# {
#    case "${MULLE_UNAME}" in
#       darwin)
#          RVAL="-fno-common"
#       ;;
#
#       *)
#          RVAL="-fPIC -fno-common"
#        ;;
#    esac
# }
#
#
# r_shlib_ldflags()
# {
#    case "${MULLE_UNAME}" in
#       darwin)
#          RVAL="-dynamiclib -all_load -Os -flat_namespace -undefined suppress"
#       ;;
#
#       *)
#          RVAL="-shared"
#        ;;
#    esac
# }



#
# this sets up make/cmake and other tools
#
platform::environment::__get_build_tools()
{
   log_entry "test::environment::__get_build_tools" "$@"

   local platform="${1:-${MULLE_UNAME}}"

   case "${platform}" in
      mingw|msys)
         include "platform::mingw"

         platform::mingw::r_mangle_compiler_exe "${CC}" "CC"
         CC="${RVAL:-gcc}"
         platform::mingw::r_mangle_compiler_exe "${CXX}" "CXX"
         CXX="${RVAL:-g++}"
         CMAKE="${CMAKE:-cmake}"
         MAKE="${MAKE:-nmake}"

         case "${MAKE}" in
            nmake)
               CMAKE_GENERATOR="NMake Makefiles"
            ;;

            make|ming32-make|"")
               CC="${CC:-cl}"
               CXX="${CXX:-cl}"
               CMAKE="mulle-mingw-cmake.sh"
               MAKE="mulle-mingw-make.sh"
               CMAKE_GENERATOR="MinGW Makefiles"
               # unused
               # FILEPATH_DEMANGLER="platform::mingw::demangle_path"
            ;;

            *)
               CMAKE_GENERATOR="${CMAKE_GENERATOR:-"Unix Makefiles"}"
            ;;
         esac
      ;;

      windows)
         CC="${CC:-cl.exe}"
         CXX="${CXX:-cl.exe}"
         MAKE="${MAKE:-ninja.exe}"

         case "${MAKE}" in
            nmake*)
               CMAKE_GENERATOR="NMake Makefiles"
            ;;

            ninja*)
               CMAKE_GENERATOR="Ninja"
            ;;

            *)
               CMAKE_GENERATOR="${CMAKE_GENERATOR:-Unix Makefiles}"
            ;;
         esac
      ;;

      "")
         fail "platform not set"
      ;;

      *bsd|dragonfly)
         CMAKE_GENERATOR="${CMAKE_GENERATOR:-Unix Makefiles}"
         CMAKE="${CMAKE:-cmake}"
         MAKE="${MAKE:-make}"
         CC="${CC:-clang}"
         CXX="${CXX:-clang++}"
      ;;

      sunos)
         CMAKE_GENERATOR="${CMAKE_GENERATOR:-Unix Makefiles}"
         CMAKE="${CMAKE:-cmake}"
         MAKE="${MAKE:-make}"
         CC="${CC:-gcc}"
         CXX="${CXX:-g++}"
      ;;

      *)
         CMAKE_GENERATOR="${CMAKE_GENERATOR:-Unix Makefiles}"
         CMAKE="${CMAKE:-cmake}"
         MAKE="${MAKE:-make}"
         CC="${CC:-cc}"
         CXX="${CXX:-c++}"
      ;;
   esac

   #
   #
   #
}


#
# local _option_frameworkpath
# local _option_libpath
# local _option_rpath
# local _option_link_mode
# local _option_linklib
# local _prefix_framework
# local _prefix_lib
# local _suffix_dynamiclib
# local _suffix_framework
# local _suffix_staticlib
# local _suffix_object
# local _suffix_executable
#
# local _r_path_mangler
#
platform::environment::__get_fix_definitions()
{
   log_entry "platform::environment::__get_fix_definitions" "$@"

   local platform="${1:-${MULLE_UNAME}}"

   _option_frameworkpath=""
   _option_libpath="-L"
   _option_linklib="-l"
   _option_rpath="-Wl,-rpath " # keep space
   _prefix_framework=""
   _prefix_lib="lib"
   _option_link_mode="basename,no-suffix"
   _suffix_dynamiclib=".so"
   _suffix_framework=""
   _suffix_staticlib=".a"
   _suffix_object=".o"
   _suffix_executable=""

   case "${platform}" in
      darwin)
         _option_frameworkpath="-F"
         _suffix_dynamiclib=".dylib"
         _suffix_framework=".framework"
      ;;

      linux)
         _option_rpath="-Wl,-rpath="
      ;;

      'mingw'|'msys'|'windows')
         _option_rpath=""
         _option_libpath="-libpath:" # no space is important
         _option_linklib=""
         _prefix_lib=""
         _strip_suffix='NO'
         _suffix_dynamiclib=".dll"
         _suffix_staticlib=".lib"
         _option_link_mode="basename,no-suffix,add-suffix-staticlib"
         _suffix_object=".obj"
         _suffix_executable=".exe"
      ;;
   esac

   case "${platform}" in
      windows)
         include "platform::wsl"

         _r_path_mangler=platform::wsl::r_wslpath
      ;;

      *)
         include "platform::mingw"

         _r_path_mangler=platform::environment::r_nomangle
      ;;
   esac
}


#
# local _option_frameworkpath
# local _option_libpath
# local _option_rpath
# local _option_link_mode
# local _option_linklib
# local _prefix_framework
# local _prefix_lib
# local _suffix_dynamiclib
# local _suffix_framework
# local _suffix_staticlib
# local _suffix_object
# local _suffix_executable
# local _r_path_mangler
#
platform::environment::__get_exe_definitions()
{
   log_entry "platform::environment::__get_exe_definitions" "$@"

   local platform="${1:-${MULLE_UNAME}}"

   _prefix_executable=""
   _suffix_executable=""

   case "${platform}" in
      'mingw'|'msys'|'windows')
         _option_rpath=""
         _option_libpath="-libpath:" # no space is important
         _option_linklib=""
         _prefix_lib=""
         _strip_suffix='NO'
         _suffix_dynamiclib=".dll"
         _suffix_staticlib=".lib"
         _option_link_mode="basename,no-suffix,add-suffix-staticlib"
         _suffix_object=".obj"
      ;;
   esac

   case "${platform}" in
      windows)
         include "platform::wsl"

         _r_path_mangler=platform::wsl::r_wslpath
      ;;

      *)
         include "platform::mingw"

         _r_path_mangler=platform::environment::r_nomangle
      ;;
   esac
}



platform::environment::r_whole_archive_format()
{
   log_entry "platform::environment::r_whole_archive_format" "$@"

   local wholearchiveformat="$1"
   local platform="${2:-${MULLE_UNAME}}"

   case "${wholearchiveformat}" in
      DEFAULT)
         case "${platform}" in
            'mingw'|'msys'|'windows')
               RVAL="whole-archive-win"
            ;;

            darwin)
               RVAL="force-load"
            ;;

            *)
               RVAL="whole-archive,no-as-needed,export-dynamic"
            ;;
         esac
      ;;

      STATIC)
         case "${platform}" in
            'mingw'|'msys'|'windows')
               RVAL="whole-archive-win"
            ;;

            darwin)
               RVAL="force-load"
            ;;

            *)
               RVAL="whole-archive,no-as-needed"
            ;;
         esac
      ;;

      *)
         # just pass thru
         RVAL="${wholearchiveformat}"
      ;;
   esac
}



platform::environment::main()
{
   log_entry "platform::environment::main" "$@"

   local OPTION_PLATFORM
   local OPTION_BUILD_TOOLS='NO'
   local OPTION_LIBRARY='DEFAULT'

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::environment::usage
         ;;

         -b|--build-tools)
            OPTION_BUILD_TOOLS='YES'
            if [ "${OPTION_LIBRARY}" = 'DEFAULT' ]
            then
               OPTION_LIBRARY='NO'
            fi
         ;;

         --no-build-tools)
            OPTION_BUILD_TOOLS='NO'
         ;;

         -l|--library)
            OPTION_LIBRARY='YES'
         ;;

         --no-library)
            OPTION_LIBRARY='NO'
         ;;

         -p|--os|--platform)
            [ $# -eq 1 ] && platform::environment::usage "Missing argument to \"$1\""
            shift

            OPTION_PLATFORM="$1"
         ;;

         -*)
            platform::environment::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::environment::usage "Superflous arguments \"$\""

   if [ "${OPTION_BUILD_TOOLS}" = 'YES' ]
   then
      platform::environment::__get_build_tools "${OPTION_PLATFORM}"

      r_escaped_doublequotes "${CC}"
      printf "%s=\"%s\"\n" "CC" "${RVAL}"
      r_escaped_doublequotes "${CXX}"
      printf "%s=\"%s\"\n" "CXX" "${RVAL}"
      r_escaped_doublequotes "${CMAKE}"
      printf "%s=\"%s\"\n" "CMAKE" "${CMAKE}"
      r_escaped_doublequotes "${CMAKE_GENERATOR}"
      printf "%s=\"%s\"\n" "CMAKE_GENERATOR" "${CMAKE_GENERATOR}"
      r_escaped_doublequotes "${MAKE}"
      printf "%s=\"%s\"\n" "MAKE" "${MAKE}"
   fi

   if [ "${OPTION_LIBRARY}" != 'NO' ]
   then
      local _option_frameworkpath
      local _option_libpath
      local _option_rpath
      local _option_link_mode
      local _option_linklib
      local _prefix_framework
      local _prefix_lib
      local _suffix_dynamiclib
      local _suffix_framework
      local _suffix_staticlib
      local _suffix_object
      local _suffix_executable
      local _r_path_mangler

      platform::environment::__get_fix_definitions "${OPTION_PLATFORM}"

      r_escaped_doublequotes "${_suffix_executable}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_EXECUTABLE_SUFFIX" "${RVAL}"
      r_escaped_doublequotes "${_option_frameworkpath}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_FRAMEWORK_PATH_LDFLAG" "${RVAL}"
      r_escaped_doublequotes "${_prefix_framework}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_FRAMEWORK_PREFIX" "${RVAL}"
      r_escaped_doublequotes "${_suffix_framework}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_FRAMEWORK_SUFFIX" "${RVAL}"
      r_escaped_doublequotes "${_option_linklib}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LIBRARY_LDFLAG" "${RVAL}"
      r_escaped_doublequotes "${_option_libpath}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LIBRARY_PATH_LDFLAG" "${RVAL}"
      r_escaped_doublequotes "${_prefix_lib}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LIBRARY_PREFIX" "${RVAL}"
      r_escaped_doublequotes "${_suffix_staticlib}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LIBRARY_SUFFIX_STATIC" "${RVAL}"
      r_escaped_doublequotes "${_suffix_dynamiclib}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LIBRARY_SUFFIX_DYNAMIC" "${RVAL}"
      r_escaped_doublequotes "${_option_link_mode}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_LINK_MODE" "${RVAL}"
      r_escaped_doublequotes "${_suffix_object}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_OBJECT_SUFFIX" "${RVAL}"
      r_escaped_doublequotes "${_option_rpath}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_RPATH_LDFLAG" "${RVAL}"

      platform::environment::r_whole_archive_format "DEFAULT" "${OPTION_PLATFORM}"
      r_escaped_doublequotes "${RVAL}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_DEFAULT" "${RVAL}"

      platform::environment::r_whole_archive_format "STATIC" "${OPTION_PLATFORM}"
      r_escaped_doublequotes "${RVAL}"
      printf "%s=\"%s\"\n" "MULLE_PLATFORM_WHOLE_ARCHIVE_LDFLAG_STATIC" "${RVAL}"
   fi
}

# shellcheck shell=bash
#
#   Copyright (c) 2015 Nat! - Mulle kybernetiK
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
MULLE_PLATFORM_MINGW_SH='included'

#
# The configure plugin can't use nmake on mingw it must use mingw32-make
# (still called mingw32-make on 64 bit)
# The cmake plugin will use nmake though
#


# used by tests
platform::mingw::demangle_path()
{
   printf "%s\n" "$1" | sed 's|^/\(.\)|\1:|' | sed s'|/|\\|g'
}


platform::mingw::eval_demangle_path()
{
   printf "%s\n" "$1" | sed 's|^/\(.\)|\1:|' | sed s'|/|\\\\|g'
}


#
# mingw wille demangle first -I/c/users but not the next one
# but when one -I looks demangled, it doesn't demangle the first
# one. It's so complicated
#
platform::mingw::eval_demangle_paths()
{
#   if [ $# -eq 0 ]
#   then
#      return
#   fi
#
#   printf "%s\n" "$1"
#   shift

   while [ $# -ne 0 ]
   do
      platform::mingw::eval_demangle_path "$1"
      shift
   done
}


# not used by anyone ?
# platform::mingw::mangle_compiler()
# {
#    local compiler
#
#    compiler="$1"
#    case "${compiler}" in
#       *clang) # mulle-clang|clang
#          compiler="${compiler}-cl"
#       ;;
#
#       *)
#          compiler="cl"
#          log_fluff "Using default compiler cl"
#       ;;
#    esac
#    printf "%s\n" "${compiler}"
# }


#
# just use regular clang on commandline tests
#
platform::mingw::r_mangle_compiler_exe()
{
   log_entry "platform::mingw::r_mangle_compiler_exe" "$@"

   local compiler="$1"

   case "${compiler}" in
      mulle-clang*|clang*)
         RVAL="${compiler}"
      ;;

      *)
         RVAL="cl.exe"
         log_verbose "Using default compiler cl for $2"
      ;;
   esac
}


#
# fix path fckup
#
platform::mingw::setup_buildenvironment()
{
   log_debug "platform::mingw::setup_buildenvironment"

#   if [ -z "${LIBPATH}" -o -z "${INCLUDE}" ] && [ -z "${DONT_USE_VS}" ]
#   then
#      log_warning "Environment variables INCLUDE and LIBPATH not set, start MINGW \
#inside IDE environment"
#   fi

   if r_mingw_find_msvc_executable "link.exe" "linker"
   then
      LD="${RVAL}"
      export LD
      log_verbose "Environment variable ${C_INFO}LD${C_VERBOSE} set to ${C_RESET}\"${LD}\""
   else
      log_warning "MSVC link.exe not found"
   fi

   local directory

   case "${MULLE_EXECUTABLE_FILE}" in
      /*|~*)
         r_dirname "${MULLE_EXECUTABLE_FILE}"
         directory="${RVAL}"
      ;;

      *)
         directory="${MULLE_EXECUTABLE_PWD}"
      ;;
   esac

   local searchpath

   searchpath="${directory}:$PATH"
   if r_mingw_find_msvc_executable "mulle-mingw-cpp" \
                                   "preprocessor" \
                                   "${searchpath}"
   then
      CPP="${RVAL}"
      export CPP
      log_verbose "Environment variable ${C_INFO}CPP${C_VERBOSE} set to ${C_RESET}\"${CPP}\""
   else
      log_warning "mulle-mingw-cpp not found"
   fi
}



#
# mingw likes to put it's stuff in front, obscuring Visual Studio
# executables this function resorts this (used in mulle-tests)
#
# platform::mingw::visualstudio_buildpath()
# {
#    local i
#    local buildpath
#    local vspath
#
#    .foreachpath i in $PATH
#    .do
#       case "$i" in
#          *"/Microsoft Visual Studio"*)
#             if [ -z "${vspath}" ]
#             then
#                vspath="${i}"
#             else
#                vspath="${vspath}:${i}"
#             fi
#          ;;
#
#          *)
#             if [ -z "${buildpath}" ]
#             then
#                buildpath="${i}"
#             else
#                buildpath="${buildpath}:${i}"
#             fi
#          ;;
#       esac
#    .done
#
#    if [ ! -z "${vspath}" ]
#    then
#       if [ -z "${buildpath}" ]
#       then
#          buildpath="${vspath}"
#       else
#          buildpath="${vspath}:${buildpath}"
#       fi
#    fi
#
#    printf "%s\n" "${buildpath}"
# }


mulle::platform::initialize()
{
   include "platform::mingwbourne"
}

mulle::platform::initialize

:


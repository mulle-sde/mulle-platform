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
MULLE_PLATFORM_MINGW_SH="included"


# DO NOT USE MULLE_BASHFUNCTIONS HERE
# (Not sure why really ???, i think these are partially old "rescued" functions
# from other scripts)...

#
# The configure plugin can't use nmake on mingw it must use mingw32-make
# (still called mingw32-make on 64 bit)
# The cmake plugin will use nmake though
#
platform::mingw::bitness()
{
   uname | sed -e 's/MINGW\([0-9]*\)_.*/\1/'
}



platform::mingw::find_msvc_executable()
{
   local exe="${1:-cl.exe}"
   local name="${2:-compiler}"
   local searchpath="${3:-$PATH}"

   local filepath
   local compiler

   IFS=':'
   shell_disable_glob
   for filepath in ${searchpath}
   do
      IFS="${DEFAULT_IFS}"
      shell_enable_glob

      case "${filepath}" in
         /usr/*|/bin)
            continue;
         ;;

         *)
            executable="${filepath}/${exe}"
            if [ -x "${executable}" ]
            then
               # echo "MSVC ${name} found as ${executable}" >&2
               printf "%s\n" "${executable}"
               break
            fi
         ;;
      esac
   done
   shell_enable_glob

   IFS="${DEFAULT_IFS}"
}


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


# used by anyone ?
platform::mingw::mangle_compiler()
{
   local compiler

   compiler="$1"
   case "${compiler}" in
      *clang) # mulle-clang|clang
         compiler="${compiler}-cl"
      ;;

      *)
         compiler="cl"
         log_fluff "Using default compiler cl"
      ;;
   esac
   printf "%s\n" "${compiler}"
}


#
# just use regular clang on commandline tests
#
platform::mingw::mangle_compiler_exe()
{
   log_entry "platform::mingw::mangle_compiler_exe" "$@"

   local compiler="$1"

   case "${compiler}" in
      mulle-clang*|clang*)
      ;;

      *)
         compiler="cl.exe"
         echo "Using default compiler cl for $2" >&2
      ;;
   esac
   printf "%s\n" "${compiler}"
}


#
# fix path fckup
#
platform::mingw::setup_buildenvironment()
{
   log_debug "platform::mingw::setup_buildenvironment"

   local linker

   if [ -z "${LIBPATH}" -o  -z "${INCLUDE}" ] && [ -z "${DONT_USE_VS}" ]
   then
      fail "environment variables INCLUDE and LIBPATH not set, start MINGW \
inside IDE environment"
   fi

   linker="`platform::mingw::find_msvc_executable "link.exe" "linker"`"
   if [ ! -z "${linker}" ]
   then
      LD="${linker}"
      export LD
      log_verbose "Environment variable ${C_INFO}LD${C_VERBOSE} set to ${C_RESET}\"${LD}\""
   else
      log_warning "MSVC link.exe not found"
   fi

   local preprocessor
   local searchpath
   local directory

   case "${MULLE_EXECUTABLE_FILE}" in
      /*|~*)
         directory="`dirname -- "${MULLE_EXECUTABLE_FILE}"`"
      ;;

      *)
         directory="${MULLE_EXECUTABLE_PWD}"
      ;;
   esac

   searchpath="${directory}:$PATH"
   preprocessor="`platform::mingw::find_msvc_executable "mulle-mingw-cpp" \
                                                        "preprocessor" \
                                                        "${searchpath}"`"
   if [ ! -z "${preprocessor}" ]
   then
      CPP="${preprocessor}"
      export CPP
      log_verbose "Environment variable ${C_INFO}CPP${C_VERBOSE} set to ${C_RESET}\"${CPP}\""
   else
      log_warning "mulle-mingw-cpp not found"
   fi
}


#
# mingw32-make can't have sh.exe or in its path, so remove it
# do not use mulle-bashfunctions here
#
platform::mingw::buildpath()
{
   local i
   local buildpath
   local vspath

   IFS=':'
   shell_disable_glob
   for i in $PATH
   do
      IFS="${DEFAULT_IFS}"
      shell_enable_glob

      if [ -x "${i}/sh.exe" ]
      then
         echo "Removed \"$i\" from build PATH because it contains sh" >&2
         continue
      fi

      if [ -z "${buildpath}" ]
      then
         buildpath="${i}"
      else
         buildpath="${buildpath}:${i}"
      fi
   done

   IFS="${DEFAULT_IFS}"
   shell_enable_glob

   echo "link.exe: `PATH="${buildpath}" /usr/bin/which link.exe`" >&2
   echo "Modified PATH: ${buildpath}" >&2
   printf "%s\n" "${buildpath}"
}


#
# mingw likes to put it's stuff in front, obscuring Visual Studio
# executables this function resorts this (used in mulle-tests)
#
platform::mingw::visualstudio_buildpath()
{
   local i
   local buildpath
   local vspath

   IFS=':'
   for i in $PATH
   do
      IFS="${DEFAULT_IFS}"

      case "$i" in
         *"/Microsoft Visual Studio"*)
            if [ -z "${vspath}" ]
            then
               vspath="${i}"
            else
               vspath="${vspath}:${i}"
            fi
         ;;

         *)
            if [ -z "${buildpath}" ]
            then
               buildpath="${i}"
            else
               buildpath="${buildpath}:${i}"
            fi
         ;;
      esac
   done
   IFS="${DEFAULT_IFS}"

   if [ ! -z "${vspath}" ]
   then
      if [ -z "${buildpath}" ]
      then
         buildpath="${vspath}"
      else
         buildpath="${vspath}:${buildpath}"
      fi
   fi

   printf "%s\n" "${buildpath}"
}


platform::mingw32::buildpath()
{
   platform::mingw::buildpath
}

:


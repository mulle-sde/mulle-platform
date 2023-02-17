# shellcheck shell=sh
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
MULLE_PLATFORM_MINGWBOURNE_SH='included'


# DO NOT USE MULLE_BASHFUNCTIONS HERE, DO NOT USE BASH FEATURES
#
# this code is included by "bourne shell" scripts
#
#
# mingw32-make can't have sh.exe or in its path, so remove it
# do not use mulle-bashfunctions here
#
mingw_bitness()
{
   uname | sed -e 's/MINGW\([0-9]*\)_.*/\1/'
}



r_mingw_find_msvc_executable()
{
   DEFAULT_IFS="${IFS}"
   IFS=':'
   set -f

   for i  in ${3:-$PATH}
   do
      case "${i}" in
         /usr/*|/bin)
            continue
         ;;

         *)
            executable="${i}/${1:-cl.exe}"
            if [ -x "${executable}" ]
            then
               # echo "MSVC ${name} found as ${executable}" >&2
               RVAL="${executable}"
               return
            fi
         ;;
      esac
   done

   RVAL=""
   return 1
}


mingw_buildpath()
{
   DEFAULT_IFS="${IFS}"
   IFS=':'
   set -f

   for i in $PATH
   do
      IFS="${DEFAULT_IFS}"
      set +f

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
   set +f

   echo "link.exe: `PATH="${buildpath}" /usr/bin/which link.exe`" >&2
   echo "Modified PATH: ${buildpath}" >&2

   printf "%s\n" "${buildpath}"
}


:


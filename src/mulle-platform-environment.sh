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

MULLE_PLATFORM_ENVIRONMENT_SH="included"


r_mulle_nomangle()
{
   RVAL="$1"
}


# fix for wslpath needing an existing file
r_mulle_wslpath()
{
   if [ ! -e "$1" ]
   then
      r_dirname "$1"
      r_mulle_wslpath "${RVAL}"
      tmp="${RVAL}"

      r_basename "$1"
      RVAL="${tmp}\\${RVAL}"
      return 
   fi

   RVAL="`wslpath -w "$1" `"
}


#
# local _option_frameworkpath
# local _option_libpath
# local _option_link_mode
# local _option_linklib
# local _prefix_framework
# local _prefix_lib
# local _suffix_dynamiclib
# local _suffix_framework
# local _suffix_staticlib
# local _r_path_mangler
#
__platform_get_fix_definitions()
{
   log_entry "__platform_get_fix_definitions" "$@"

   _option_frameworkpath=""
   _option_libpath="-L"
   _option_linklib="-l"
   _prefix_framework=""
   _prefix_lib="lib"
   _option_link_mode="basename,no-suffix"
   _suffix_dynamiclib=".so"
   _suffix_framework=""
   _suffix_staticlib=".a"

   case "${MULLE_UNAME}" in
      darwin)
         _option_frameworkpath="-F"
         _suffix_dynamiclib=".dylib"
         _suffix_framework=".framework"
      ;;

      mingw*|windows)
         _option_libpath="-libpath:" # space is important
         _option_linklib=""
         _prefix_lib=""
         _strip_suffix="NO"
         _suffix_dynamiclib=".dll"
         _suffix_staticlib=".lib"
         _option_link_mode="basename,no-suffix,add-suffix-staticlib"
      ;;
   esac

   case "${MULLE_UNAME}" in
      windows)
         _r_path_mangler=r_mulle_wslpath
      ;;

      *)
         _r_path_mangler=r_mulle_nomangle
      ;;
   esac
}


r_platform_default_whole_archive_format()
{
   log_entry "r_platform_default_whole_archive_format" "$@"

   case "${MULLE_UNAME}" in
      mingw*)
         RVAL="whole-archive-win"
      ;;

      darwin)
         RVAL="force-load"
      ;;

      *)
         RVAL="whole-archive,no-as-needed,export-dynamic"
      ;;
   esac
}

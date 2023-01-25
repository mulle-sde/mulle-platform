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

MULLE_PLATFORM_ENVIRONMENT_SH="included"


platform::environment::r_nomangle()
{
   RVAL="$1"
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
# local _r_path_mangler
#
platform::environment::__get_fix_definitions()
{
   log_entry "platform::environment::__get_fix_definitions" "$@"

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

   case "${MULLE_UNAME}" in
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
         _strip_suffix="NO"
         _suffix_dynamiclib=".dll"
         _suffix_staticlib=".lib"
         _option_link_mode="basename,no-suffix,add-suffix-staticlib"
      ;;
   esac

   case "${MULLE_UNAME}" in
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

   case "${wholearchiveformat}" in
      DEFAULT)
         case "${MULLE_UNAME}" in
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
         case "${MULLE_UNAME}" in
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

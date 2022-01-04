#! /usr/bin/env bash
#
#   Copyright (c) 2021 Nat! - Mulle kybernetiK
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
MULLE_PLATFORM_FLAGS_SH="included"


platform::flags::r_cc_include_dir()
{
   local dir="$1"
   local quote="$2"

   case "${MULLE_UNAME}" in
      windows)
         include "platform::wsl"

         platform::wsl::r_wslpath "${dir}"
         RVAL="/I${quote}${RVAL}${quote}"
      ;;

      *)
         RVAL="-I${quote}${dir}${quote}"
      ;;
   esac
}


platform::flags::r_cc_framework_dir()
{
   local dir="$1"
   local quote="$2"

   case "${MULLE_UNAME}" in
      *)
         RVAL="-F${quote}${dir}${quote}"
      ;;
   esac
}


platform::flags::r_cc_output_object_filename()
{
   local filename="$1"
   local quote="$2"

   case "${MULLE_UNAME}" in
      windows)
         include "platform::wsl"

         platform::wsl::r_wslpath "${filename}"
         RVAL="/Fo${quote}${RVAL}${quote}"
      ;;

      mingw)
         RVAL="-Fo${quote}${filename}${quote}"
      ;;

      *)
         RVAL="-o ${quote}${filename}${quote}"
      ;;
   esac
}


platform::flags::r_cc_output_exe_filename()
{
   local filename="$1"
   local quote="$2"

   case "${MULLE_UNAME}" in
      windows)
         include "platform::wsl"

         platform::wsl::r_wslpath "${filename}"
         RVAL="/Fe${quote}${RVAL}${quote}"
      ;;

      mingw)
         RVAL="-Fe${quote}`"${CYGPATH:-cygpath}" -w "${filename}"`${quote}"
      ;;

      *)
         RVAL="-o ${quote}${filename}${quote}"
      ;;
   esac
}

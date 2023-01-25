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

MULLE_PLATFORM_SEARCHPATH_SH="included"


platform::searchpath::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-searchpath}

   Show the searchpath used on this platform for finding OS libraries.

Notes:
   Works on linux on darwin.

EOF
   exit 1
}


# the Windows SDK is added to our PATH so we scour the path
# and deduce the lib directory from it
platform::searchpath::r_windows_library_filepath()
{
   local directory
   local arch
   local version

   IFS=":"
   for directory in ${PATH}
   do
      IFS="${DEFAULT_IFS}"
      case "${directory}" in 
         *[/\\]Windows\ Kits[/\\]*)
            # either 
            # /mnt/c/Program Files (x86)/Windows Kits/10/bin/10.0.18362.0/x86
            # /mnt/c/Program Files (x86)/Windows Kits/10/bin/x86            
            r_basename "${directory}"
            arch="${RVAL}"
            r_dirname "${directory}" 
            directory="${RVAL}"           
            r_basename "${directory}"
            if [ "${RVAL}" = "bin" ]
            then
               continue
            fi
            version="${RVAL}"

            #  /mnt/c/Program\ Files\ \(x86\)/Windows\ Kits/10/Lib/10.0.18362.0/um/x64            
            r_dirname "${directory}"  # get to ../10
            r_dirname "${RVAL}"  # get to ../10
            RVAL="${RVAL}/Lib/${version}/um/${arch}"
            return 0
         ;;
      esac
   done
   IFS="${DEFAULT_IFS}"

   log_warning "Windows SDK not found in PATH"
   RVAL=
   return 1
}


#
# somewhat dependent on linux to have gcc/clang installed
#
platform::search::r_platform_searchpath()
{
   log_entry "platform::search::r_platform_searchpath" "$@"

   if [ -z "${MULLE_PLATFORM_SEARCHPATH}" ]
   then
      local cc

      cc="${CC}"
      if [ -z "${cc}" ]
      then
         case "${MULLE_UNAME}" in
            'mingw'|'msys'|'windows')
# don't need cc on windows
#               cc="`mudo -f which gcc.exe`"
#               if [ -z "${cc}" ]
#               then
#                  cc="`mudo -f which mulle-clang-cl.exe`"
#               else
#                  if [ -z "${cc}" ]
#                  then
#                     cc="`mudo -f which clang-cl.exe`"
#                  else
#                     if [ -z "${cc}" ]
#                     then
#                        cc="`mudo -f which cl.exe`"
#                     fi
#                  fi
#               fi
            ;;

            *)
               MULLE_PLATFORM_SEARCHPATH="/usr/local/lib:/usr/lib"

               cc="`mudo -f which gcc`"
               if [ -z "${cc}" ]
               then
                  cc="`mudo -f which clang`"
               else
                  if [ -z "${cc}" ]
                  then
                     cc="`mudo -f which mulle-clang`"
                  fi
               fi
            ;;
         esac
      fi

      local filepath

      case "${MULLE_UNAME}" in
         'darwin')
            filepath="`rexekutor xcrun --show-sdk-path`"
            if [ ! -z "${filepath}" ]
            then
               filepath="/usr/local/lib:${filepath}/usr/lib:/usr/lib"
            fi
         ;;

         'windows'|'mingw')
            # it's something like
            #  /mnt/c/Program\ Files\ \(x86\)/Windows\ Kits/10/Lib/10.0.18362.0/um/x64            
            # how do we get this ? well...
            platform::searchpath::r_windows_library_filepath
            filepath="${RVAL}"
         ;;

         # guess msys should to this
         *)
            filepath="`rexekutor "${cc:-cc}" -Xlinker --verbose  2>/dev/null \
                       | sed -n -e 's/SEARCH_DIR("=\?\([^"]\+\)"); */\1\n/gp'  \
                       | grep -E -v '^$' \
                       | sed 's/[ \t]*$//' \
                       | tr '\012' ':' `"
         ;;
      esac

      if [ ! -z "${filepath}" ]
      then
         filepath="${filepath%%:}"
         filepath="${filepath##:}"
         if [ ! -z "${filepath}" ]
         then
            MULLE_PLATFORM_SEARCHPATH="${filepath}"
         fi
      else
         log_warning "Could not figure out system library paths with \"${cc}\", using platform defaults"
      fi
   fi

   RVAL="${MULLE_PLATFORM_SEARCHPATH}"
   log_verbose "Platform library searchpath: ${MULLE_PLATFORM_SEARCHPATH}"
}



platform::searchpath::main()
{
   log_entry "platform::searchpath::main" "$@"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::searchpath::usage
         ;;

         -*)
            platform::searchpath::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac
      shift
   done

   [ $# -eq 0 ] || platform::searchpath::usage "Superflous parameters \"$*\""

   platform::search::r_platform_searchpath
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}

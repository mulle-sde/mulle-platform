# shellcheck shell=bash
#
#   Copyright (c) 2026 Nat! - Mulle kybernetiK
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

MULLE_PLATFORM_CROSSCOMPILER_ROOT_SH='included'


platform::crosscompiler_root::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} crosscompiler-root [options]

   Find the root directory of a cross-compiler toolchain installation.
   Searches /opt for directories matching the pattern:
      /opt/<compiler>-*<platform>/<version>
   
   Returns the directory with the highest version number.
   
   Examples of matching patterns:
      /opt/gcc-windows/11.2.0
      /opt/mulle-clang-project-windows/21.1.8.2

Options:
   --compiler <compiler>  : Compiler name (e.g., gcc, mulle-clang)
   --platform <platform>  : Target platform (e.g., windows, mingw)

Examples:
   mulle-platform crosscompiler-root --compiler gcc --platform windows
   # Might return: /opt/gcc-windows/11.2.0

   mulle-platform crosscompiler-root --compiler mulle-clang --platform windows
   # Might return: /opt/mulle-clang-project-windows/21.1.8.2

EOF
   exit 1
}


platform::crosscompiler_root::r_extract_version()
{
   log_entry "platform::crosscompiler_root::r_extract_version" "$@"

   local filepath="$1"
   local compiler="$2"
   local platform="$3"

   # Extract version from filepath like /opt/gcc-11.2.0-windows
   # Remove /opt/ prefix and compiler- prefix and -platform suffix
   local basename="${filepath#/opt/}"
   local middle="${basename#${compiler}-}"
   local version="${middle%-${platform}}"
   
   RVAL="${version}"
}


platform::crosscompiler_root::r_compare_versions()
{
   log_entry "platform::crosscompiler_root::r_compare_versions" "$@"

   local v1="$1"
   local v2="$2"
   
   # Simple version comparison - split by dots and compare numerically
   # Returns: 1 if v1 > v2, 0 if equal, -1 if v1 < v2
   
   if [ "${v1}" = "${v2}" ]
   then
      RVAL=0
      return
   fi
   
   # Use sort -V (version sort) if available
   if sort --version-sort /dev/null 2>/dev/null
   then
      local sorted
      sorted="$(printf "%s\n%s\n" "${v1}" "${v2}" | sort -V)"
      local first_line="${sorted%%$'\n'*}"
      
      if [ "${first_line}" = "${v2}" ]
      then
         RVAL=1  # v1 > v2
      else
         RVAL=-1  # v1 < v2
      fi
      return
   fi
   
   # Fallback: string comparison (not ideal but better than nothing)
   if [ "${v1}" \> "${v2}" ]
   then
      RVAL=1
   else
      RVAL=-1
   fi
}


platform::crosscompiler_root::find()
{
   log_entry "platform::crosscompiler_root::find" "$@"

   local compiler="$1"
   local platform="$2"
   
   # Pattern: /opt/<compiler>-*<platform>/<version>
   # This matches things like: /opt/mulle-clang-project-windows/21.1.8.2
   local pattern="/opt/${compiler}-*${platform}"
   local best_path=""
   local best_version=""
   
   # Find all matching base directories
   local base_dirs
   base_dirs="$(ls -d ${pattern} 2>/dev/null)"
   
   if [ -z "${base_dirs}" ]
   then
      return 0
   fi
   
   # For each base directory, find version subdirectories
   local base_dir
   local candidates
   local filepath
   local version
   local comparison
   
   while IFS= read -r base_dir
   do
      [ -z "${base_dir}" ] && continue
      [ ! -d "${base_dir}" ] && continue
      
      # Get all version directories in this base
      candidates="$(ls -d ${base_dir}/* 2>/dev/null)"
      
      # Iterate through version directories
      while IFS= read -r filepath
      do
         [ -z "${filepath}" ] && continue
         [ ! -d "${filepath}" ] && continue
         
         # Extract version from filepath (just the basename)
         version="${filepath##*/}"
         
         log_fluff "Found candidate: ${filepath} (version: ${version})"
         
         if [ -z "${best_version}" ]
         then
            best_path="${filepath}"
            best_version="${version}"
         else
            platform::crosscompiler_root::r_compare_versions "${version}" "${best_version}"
            comparison="${RVAL}"
            
            if [ "${comparison}" -gt 0 ]
            then
               best_path="${filepath}"
               best_version="${version}"
            fi
         fi
      done <<< "${candidates}"
   done <<< "${base_dirs}"
   
   if [ ! -z "${best_path}" ]
   then
      echo "${best_path}"
   fi
}


platform::crosscompiler_root::main()
{
   log_entry "platform::crosscompiler_root::main" "$@"

   local OPTION_COMPILER
   local OPTION_PLATFORM

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            platform::crosscompiler_root::usage
         ;;

         --compiler)
            [ $# -eq 1 ] && platform::crosscompiler_root::usage "Missing argument to \"$1\""
            shift
            OPTION_COMPILER="$1"
         ;;

         --platform)
            [ $# -eq 1 ] && platform::crosscompiler_root::usage "Missing argument to \"$1\""
            shift
            OPTION_PLATFORM="$1"
         ;;

         -*)
            platform::crosscompiler_root::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   [ $# -ne 0 ] && platform::crosscompiler_root::usage "Superfluous arguments \"$*\""
   [ -z "${OPTION_COMPILER}" ] && platform::crosscompiler_root::usage "Missing --compiler option"
   [ -z "${OPTION_PLATFORM}" ] && platform::crosscompiler_root::usage "Missing --platform option"

   platform::crosscompiler_root::find "${OPTION_COMPILER}" "${OPTION_PLATFORM}"
}

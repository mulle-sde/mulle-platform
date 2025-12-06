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

MULLE_PLATFORM_PLUGIN_SH='included'


platform::plugin::load_compiler()
{
   log_entry "platform::plugin::load_compiler" "$@"

   local compiler_type="$1"

   if shell_is_function "platform::plugin::compiler::${compiler_type}::get_flags"
   then
      log_debug "Compiler plugin \"${compiler_type}\" already loaded"
      return 0
   fi

   local pluginpath

   pluginpath="${MULLE_PLATFORM_LIBEXEC_DIR}/plugins/compilers/${compiler_type}.sh"
   if [ ! -f "${pluginpath}" ]
   then
      log_fluff "No compiler plugin for \"${compiler_type}\" found"
      return 1
   fi

   . "${pluginpath}" > /dev/null 2>&1

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      local functionname

      functionname="platform::plugin::compiler::${compiler_type}::get_flags"
      if ! shell_is_function "${functionname}"
      then
         _internal_fail "Compiler plugin \"${pluginpath}\" has no \"${functionname}\" function"
      fi
   fi

   log_debug "Compiler plugin for \"${compiler_type}\" loaded"
   return 0
}


platform::plugin::load_platform()
{
   log_entry "platform::plugin::load_platform" "$@"

   local platform_name="$1"

   if shell_is_function "platform::plugin::platform::${platform_name}::check_quirk"
   then
      log_debug "Platform plugin \"${platform_name}\" already loaded"
      return 0
   fi

   local pluginpath

   pluginpath="${MULLE_PLATFORM_LIBEXEC_DIR}/plugins/platforms/${platform_name}.sh"
   if [ ! -f "${pluginpath}" ]
   then
      log_fluff "No platform plugin for \"${platform_name}\" found"
      return 1
   fi

   . "${pluginpath}" > /dev/null 2>&1

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      local functionname

      functionname="platform::plugin::platform::${platform_name}::check_quirk"
      if ! shell_is_function "${functionname}"
      then
         _internal_fail "Platform plugin \"${pluginpath}\" has no \"${functionname}\" function"
      fi
   fi

   log_debug "Platform plugin for \"${platform_name}\" loaded"
   return 0
}


platform::plugin::list_compilers()
{
   log_entry "platform::plugin::list_compilers"

   log_fluff "Listing compiler plugins..."

   local pluginpath
   local pluginname

   .foreachline pluginpath in `dir_list_files "${MULLE_PLATFORM_LIBEXEC_DIR}/plugins/compilers" "*.sh"`
   .do
      r_extensionless_basename "${pluginpath}"
      pluginname="${RVAL}"
      printf "%s\n" "${pluginname}"
   .done
}


platform::plugin::list_platforms()
{
   log_entry "platform::plugin::list_platforms"

   log_fluff "Listing platform plugins..."

   local pluginpath
   local pluginname

   .foreachline pluginpath in `dir_list_files "${MULLE_PLATFORM_LIBEXEC_DIR}/plugins/platforms" "*.sh"`
   .do
      r_extensionless_basename "${pluginpath}"
      pluginname="${RVAL}"
      printf "%s\n" "${pluginname}"
   .done
}

:

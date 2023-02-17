#
# Used to be hardcoded in mulle-sde plugin, now part of the environment.
#
export MULLE_SDK_DIR="${DEPENDENCY_DIR:-${MULLE_VIRTUAL_ROOT}/dependency}/${DEFAULT_SDK}"


#
#
#
export PATH="${MULLE_SDK_DIR%%/}/Debug/bin:${MULLE_SDK_DIR%%/}/Release/bin:${MULLE_SDK_DIR%%/}/bin:${DEPENDENCY_DIR%%/}/bin:${PATH}"



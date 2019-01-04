#
# For documentation and help see:
#    https://github.com/mulle-sde/mulle-project
#
#

generate_brew_formula_build()
{
   local project="$1"
   local name="$2"
   local version="$3"

   generate_script_brew_formula_build
}


generate_script_brew_formula_build()
{
   cat <<EOF
def install
  system "./bin/installer", "#{prefix}"
end
EOF
}


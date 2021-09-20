#!/bin/bash
#
# Aim : Install a small Punch package in the Sublime Text structure. Allows : color highlight, completion, auto build.

RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

read -p 'Do you want to install Punch Sublime Text package (y/n) [n] : ' confirm
[ "$confirm" == "y" ] || exit 10

if [ -z "$(which subl)" -a ! -d "/Applications/Sublime Text.app" ]; then
  echo -e "${RED}[ERROR]${RESET} unable to find Sublime instance. is Sublime Text installed ?"
  exit 127
fi

if [ "$(uname)" == "Linux" ]; then
  SUBLIME_LIB_DIR="$HOME/.config/sublime-text-3/Packages"
else # darwin
  SUBLIME_LIB_DIR="$HOME/Library/Application Support/Sublime Text 3/Packages"
fi

if [ ! -d "$SUBLIME_LIB_DIR" ]; then
  echo -e "${RED}[ERROR]${RESET} unable to find the Sublime Text library directory."
  echo "        expected location: '$SUBLIME_LIB_DIR'"
  exit 126
fi

echo -ne "${GREEN}[INFO]${RESET} Copying raw files..."
if [ ! -d "$SUBLIME_LIB_DIR/User" ]; then
  mkdir -p "$SUBLIME_LIB_DIR/User"
fi
cp -r $(dirname $0)/Punch* "$SUBLIME_LIB_DIR/User/" && echo " OK."

#######################################
## Building build file
#######################################
echo -ne "${GREEN}[INFO]${RESET} Builing path-dependent build file..."
cat > "$SUBLIME_LIB_DIR/User/Punch.sublime-build" << EOF
{
    "cmd": ["punchplatform-puncher.sh", "-p", "\$file"],
    "selector": "source.punch",
    "target": "ansi_color_build",
    "path": "$PATH",
    "env": {
EOF

# Adding some env vars:
env | grep "PUNCH" | sed 's/^\(.*\)=\(.*\)/      "\1": "\2",/' >> "$SUBLIME_LIB_DIR/User/Punch.sublime-build"
env | grep "JAVA" | sed 's/^\(.*\)=\(.*\)/      "\1": "\2",/' >> "$SUBLIME_LIB_DIR/User/Punch.sublime-build"
echo '      "BUILDER": "punch"' >> "$SUBLIME_LIB_DIR/User/Punch.sublime-build"

cat >> "$SUBLIME_LIB_DIR/User/Punch.sublime-build" << EOF
    },
    "syntax": "Packages/ANSIescape/ANSI.tmLanguage"
}
EOF

echo " OK."

######################################
## ANSIescape installation
######################################

# for linux
if [ ! -d "$SUBLIME_LIB_DIR/ANSIescape" ]; then
  echo -e "${GREEN}[INFO]${RESET} Installing ANSIescape plugin..."
  if [ -z "$(which git)" ]; then
    echo -e "${RED}[ERROR]${RESET} The ANSIescape plugin is missing but it cannot be installed."
    echo -e "${RED}[ERROR]${RESET} Please, first install the 'git' command tool, then relaunch the installation"
    exit 127
  fi
  git clone "https://github.com/aziz/SublimeANSI.git" "$SUBLIME_LIB_DIR/ANSIescape"
else
  echo -e "${GREEN}[INFO]${RESET} Plugin ANSIescape already installed."
fi

echo
echo -e "${GREEN}[INFO]${RESET} The PunchPlatform SublimeText plugin is now installed!"

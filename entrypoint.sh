#!/bin/bash

#
# Support arguments (this recommend but not required):
#   -f <file>               Execute file on host, print the result and exit
#   -c <command>            [Not recommended to use] Execute command on host, print the result and exit
#   -C <command in base64>  Execute command on host, print the result and exit
#   -v <level>              Verbose mode: 1 - verbose, 2 - super verbose
#   -e <NAME=B64> -e ...    Environement variables (B64 is base64 encoded string)
#   -b <BASE64> -b ...      Base64 encoded bash command
#   -H <HOME path>          HOME path. Will be $HOME on the host.
#   -X <XDG path>           XDG_* path (https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
#

while getopts f:c:C:v:e:b:H:X: option
do
case "${option}"
in
f) EXECUTE_FILE=${OPTARG};;
c) EXECUTE_COMMAND=${OPTARG};;
C) EXECUTE_COMMAND_B64=${OPTARG};;
v) VERBOSE=${OPTARG};;
e) ENV+=("$OPTARG");;
b) EBASH+=("$OPTARG");;
H) HOMEPATH=${OPTARG};;
X) XDGPATH=${OPTARG};;
esac
done

if [[ $VERBOSE != '' ]]; then
  export XXH_VERBOSE=$VERBOSE
fi

if [[ $EXECUTE_COMMAND ]]; then
  if [[ $XXH_VERBOSE == '1' || $XXH_VERBOSE == '2' ]]; then
    echo Execute command: $EXECUTE_COMMAND
  fi

  EXECUTE_COMMAND=(-c "${EXECUTE_COMMAND}")
fi

if [[ $EXECUTE_COMMAND_B64 ]]; then
  EXECUTE_COMMAND=`echo $EXECUTE_COMMAND_B64 | base64 -d`
  if [[ $XXH_VERBOSE == '1' || $XXH_VERBOSE == '2' ]]; then
    echo Execute command base64: $EXECUTE_COMMAND_B64
    echo Execute command: $EXECUTE_COMMAND
  fi

  EXECUTE_COMMAND=(-c "${EXECUTE_COMMAND}")
fi

if [[ $EXECUTE_FILE ]]; then
  EXECUTE_COMMAND=""
fi

for env in "${ENV[@]}"; do
  # If the env does not look like name=val, let's skip it
  if [[ $env != *"="* ]]; then
    continue
  fi
  name="$( cut -d '=' -f 1 <<< "$env" )";
  val="$( cut -d '=' -f 2- <<< "$env" )";
  val=`echo $val | base64 -d`

  if [[ $XXH_VERBOSE == '1' || $XXH_VERBOSE == '2' ]]; then
    echo Entrypoint env: raw="$env", name=$name, value=$val
  fi

  export $name="$val"
done

for eb in "${EBASH[@]}"; do
  bash_command=`echo $eb | base64 -d`

  if [[ $XXH_VERBOSE == '1' || $XXH_VERBOSE == '2' ]]; then
    echo Entrypoint bash execute: $bash_command
  fi
  eval $bash_command
done

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd $CURRENT_DIR

elvish_bin=$CURRENT_DIR/bin/elvish
# Check
if [[ ! -f .entrypoint-check-done ]]; then
  check_result=`$elvish_bin -version 2>&1`
  if [[ $check_result != *"v"* ]]; then
    echo "Something went wrong while running fish on host:"
    echo $check_result
  else
    echo $check_result > .entrypoint-check-done
  fi
fi

export XXH_HOME=$CURRENT_DIR/../../../..
export PATH=$CURRENT_DIR/bin:$PATH
export USER_HOME=$HOME

if [[ $HOMEPATH != '' ]]; then
  homerealpath=$HOMEPATH
  if [[ -d $homerealpath ]]; then
    export HOME=$homerealpath
  else
    echo "Home path not found: $homerealpath"
    echo "Set HOME to $XXH_HOME"
    export HOME=$XXH_HOME
  fi
else
  export HOME=$XXH_HOME
fi

if [[ $XDGPATH != '' ]]; then
  xdgrealpath=$XDGPATH
  if [[ ! -d $xdgrealpath ]]; then
    echo "XDG path not found: $xdgrealpath"
    echo "Set XDG path to $XXH_HOME"
    export XDGPATH=$XXH_HOME
  fi
else
  export XDGPATH=$XXH_HOME
fi

export XXH_SHELL=fish
export XDG_CONFIG_HOME=$XDGPATH/.config
export XDG_DATA_HOME=$XDGPATH/.local/share
export XDG_CACHE_HOME=$XDGPATH/.cache

if [ -x "$(command -v getent)" ]; then
  export XAUTHORITY=$( getent passwd | grep -m 1 -E "^$USER\:.*" | cut -d\: -f 6 )/.Xauthority
else
  export XAUTHORITY=$USER_HOME/.Xauthority
fi

for pluginrc_file in $(find $CURRENT_DIR/../../../plugins/xxh-plugin-*/build -type f -name '*prerun.sh' -printf '%f\t%p\n' 2>/dev/null | sort -k1 | cut -f2); do
  if [[ -f $pluginrc_file ]]; then
    if [[ $XXH_VERBOSE == '1' || $XXH_VERBOSE == '2' ]]; then
      echo Load plugin $pluginrc_file
    fi
    #cd $(dirname $pluginrc_file)
    source $pluginrc_file
  fi
done

cd $HOME
# TODO: get elvish to load plugins, just use rc.elv? Except for file execute which is a noninteractive context :(
$elvish_bin "${EXECUTE_COMMAND[@]}" $EXECUTE_FILE
#$fish_bin --interactive --init-command="source $XXH_HOME/.xxh/shells/xxh-shell-fish/build/xxh-config.fish" "${EXECUTE_COMMAND[@]}"  $EXECUTE_FILE

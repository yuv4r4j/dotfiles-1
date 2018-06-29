#!/usr/bin/env bash
#set -x
set -e

syntax() {
    echo "Syntax: $0 <path> [perm]"
    echo "    [perm] defaults to 'o+r' for files"
    echo "    'o+x' added to directories recursively"
}

if [ "$#" -gt 2 ]; then
    syntax
    exit -1
fi

PERM="o+r"

if [ "$#" -eq 2 ]; then
    PERM="$2"
fi

if [ "$#" -eq 0 ]; then
    syntax
    exit -1
fi

chmod -R ${PERM} "$1"
find "$1" -type d -exec chmod o+x {} \;

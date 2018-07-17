#!/usr/bin/env bash
set -e
#set -x

SCRIPTPATH=""
SCRIPTARGS=""
CONDAENV=""
CWD=""

CMD=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
    -s|--script)
        SCRIPTPATH="$2"
        shift 2
        ;;
    -a|--args)
        SCRIPTARGS="$2"
        shift 2
        ;;
    c|--conda)
        CONDAENV="$2"
        shift 2
        ;;
    -w|--cwd)
        CWD="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Ignoring unknown wrapper argument: \"$1\""
        shift
        ;;
    esac
done

if [ "$#" -lt "1" ]; then
    echo "Script path is not specified"
    exit -1
fi
SCRIPTPATH="$1"
shift
SCRIPTARGS="$@"

# validate launchable script is specified
if [ -z "${SCRIPTPATH}" -o ! -f "${SCRIPTPATH}" ]; then
    echo "Valid script must be specified with -s|--script key"
    exit -1
fi

CMD="${SCRIPTPATH}"

if [ ! -z "${SCRIPTARGS}" ]; then
    CMD="${CMD} ${SCRIPTARGS}"
fi

export CUDA_VISIBLE_DEVICES="$(ls -rt /tmp/lock-gpu*/info.txt | xargs grep -h  $(whoami) | awk '{print $2}' | paste -sd "," -)"
echo ======= ENV ========
export
echo ======= ENV ========
echo Starting on: `date`
sync

if [ ! -z "${CONDAENV}" ]; then
    echo "Activating conda environment: ${CONDAENV}"
    source activate "${CONDAENV}"
fi

if [ -d "${CWD}/.git" ]; then
    echo "Repository snapshot info:"
    git remote -v
    git branch -v
fi

echo "About to execute: '${CMD}' from '${CWD}'"
mkdir -p "${CWD}" && cd "${CWD}"
exec ${CMD}

echo Finished at: `date`

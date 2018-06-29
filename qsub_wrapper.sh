#!/usr/bin/env bash
set -e
#set -x

help() {
    echo "Wrapper around SGE 'qsub' command, takes care of BIWI-specific"
    echo "command line options, helps to check job status and log file shortly"
    echo "after job start. Refer to BIWI wiki for details. Command line options:"
    echo "  -s|--script      : a valid script path accessible from SGE"
    echo "  [-a|--args]      : script arguments in one quoted line"
    echo "  [-q|--queue]=0   : id of queue, 0 (short), 1 (mid), 2 (long)"
    echo "  [-n|--numgpus]=1 : number of GPUs to request"
    echo "  [-m|--mem]=8G    : hard limit of host memory"
    echo "  [-c|--conda]     : conda env to activate prior to running script"
    echo "  [-w|--cwd]       : execution cwd, defaults to script directory"
}

SCRIPTPATH=""
SCRIPTARGS=""
GPUQUEUEID=0
NGPUS=1
VMEM=8G
CONDAENV=""
CWD=""

CMD="qsub"
# Otherwise CSH will be used
CMD="${CMD} -S /bin/bash"
# Show error message and reject job with invalid requests
CMD="${CMD} -w e"
# Inherit the current shell environment to the job
CMD="${CMD} -V"

POSITIONAL=()
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
    -q|--queue)
        GPUQUEUEID="$2"
        shift 2
        ;;
    -n|--numgpus)
        NGPUS="$2"
        shift 2
        ;;
    -m|--mem)
        VMEM="$2"
        shift 2
        ;;
    -c|--conda)
        CONDAENV="$2"
        shift 2
        ;;
    -w|--cwd)
        CWD="$2"
        shift 2
        ;;
    -h|--help)
        help
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *) # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# validate launchable script is specified
if [ -z "${SCRIPTPATH}" -o ! -f "${SCRIPTPATH}" ]; then
    echo "Valid script must be specified with -s|--script key"
    exit -1
fi

# Worldwide permissions to make SGE happy
chmod 0777 ${SCRIPTPATH}

if [ ! -z "${CONDAENV}" -a ! "$(head -c 14 ${SCRIPTPATH})" == '#!/usr/bin/env' ]; then
    echo "Expected script shebang with conda environment is '#!/usr/bin/env'"
    exit -1
elif [ ! "$(head -c 2 ${SCRIPTPATH})" == '#!' ]; then
    echo "Expected any shebang in the script, none found"
    exit -1
fi

SCRIPTNAMEEXT=${SCRIPTPATH##*/}
SCRIPTNAME=${SCRIPTNAMEEXT%.*}
DIRNAME=${SCRIPTPATH%/*}

if [ -z "${CWD}" ]; then
    CWD="${DIRNAME}"
fi

# Name of the job
CMD="${CMD} -N ${SCRIPTNAME}"

GPUQUEUE=""
case ${GPUQUEUEID} in
0)
    GPUQUEUE="gpu.short.q@*"
    ;;
1)
    GPUQUEUE="gpu.middle.q@*"
    ;;
2)
    GPUQUEUE="gpu.long.q@*"
    ;;
*) # unknown option
    echo "Invalid -q|--queue enum, can be one of 0,1,2"
    exit -1
    ;;
esac

# Dispatch GPU queue
CMD="${CMD} -q ${GPUQUEUE}"

if [ "${NGPUS}" -lt "0" -o "${NGPUS}" -gt "6" ]; then
    echo "Invalid -n|--numgpus number, can be between 0 and 6"
    exit -1
fi

# Dispatch GPU queue
CMD="${CMD} -l gpu=${NGPUS}"

# Host memory limit
CMD="${CMD} -l h_vmem=${VMEM}"

echo "Preparing job '${SCRIPTNAME}' to run in queue '${GPUQUEUE}' on '${NGPUS}' GPUs with ${VMEM} of host mem"

LOGSROOT="${HOME}/logs"
DATE=`date '+%Y-%m-%d'`
TIME=`date '+%H-%M-%S'`
LOGSDIR="${LOGSROOT}/${DATE}"
mkdir -p ${LOGSDIR}
LOGSPATH="${LOGSDIR}/${SCRIPTNAME}_${TIME}.txt"

echo "LOGS  : ${LOGSPATH}"

# Join STDERR and STDOUT
CMD="${CMD} -j y"

# Make qsub output only job id in case of success
CMD="${CMD} -terse"

# Redirect STDOUT
CMD="${CMD} -o ${LOGSPATH}"

ENV_SCRIPT="${HOME}/code/env/env_cluster.sh"
ENV_ARGS="-s ${SCRIPTPATH}"
if [ ! -z "${SCRIPTARGS}" ]; then
    ENV_ARGS="${ENV_ARGS} -a \"${SCRIPTARGS}\""
fi
if [ ! -z "${CONDAENV}" ]; then
    ENV_ARGS="${ENV_ARGS} -c ${CONDAENV}"
fi
CMD="${CMD} ${ENV_SCRIPT} ${ENV_ARGS} -w ${CWD}"

#echo "About to execute: '${CMD}'"
JOBID=$(${CMD})

echo "JOB ID: ${JOBID}"

# Start polling job status
#watch -n 0.5 qstat -j ${JOBID}

explain_qstat_state() {
    case "${JOBSTATE}" in
    "qw")
        echo "WAITING"
        ;;
    "r")
        echo "RUNNING"
        ;;
    "Eqw")
        echo "ERROR"
        ;;
    "Rq"|"Rr")
        echo "RESTARTED"
        ;;
    "t")
        echo "ASSIGNING FOR EXECUTION"
        ;;
    *)
        echo "${JOBSTATE}"
        ;;
    esac
}

# Start following job output
WAITMSG="\rWaiting for log file."
while [ ! -f ${LOGSPATH} ]; do
    JOBSTATE=$(qstat -u $(whoami) | grep ${JOBID} | awk '{print $5}')
    OUTMSG="${WAITMSG}"
    if [ ! -z "${JOBSTATE}" ]; then
        OUTMSG="${OUTMSG} Job state: $(explain_qstat_state ${JOBSTATE})"
    fi
    echo -ne "\033[2K${OUTMSG}" # \033[2K sequence to clear one terminal line
    WAITMSG="${WAITMSG}."
    sleep 1
done
echo
echo ===== LOG FILE =====
tail -f -n +1 ${LOGSPATH}

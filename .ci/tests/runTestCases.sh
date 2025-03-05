#!/bin/sh

help()
{
  echo "./runTestCases.sh as_host working_dir [options] [-- <hostenv.sh options>]"
  echo "  as_host                   First argument must be the host configuration to use for environment loading"
  echo "  working_dir               Second argument must be the working dir to immediate cd to"
  echo "  -c <folder>               Directory for specific core built"
  echo "  -g <type>                 Type of test to run"
  echo "  -r <folder>               Directory to run in using mkdir and symlinking -c <folder> for each namelist"
  echo "  -b <exec>                 Binary executable for MPAS"
  echo "  -f <folder>               Directory to look for input files in"
  echo "  -n                        Use double precision"
  echo "  -d <device>               Device to use"
  echo "  -q <interval>             Restart interval"
  echo "  -y <time>                 Restart time"
  echo "  -z <duration>             Run duration"
  echo "  -w <interval>             Output interval"
  echo "  -p <mpirun cmd>           Parallel launch command (MPI), e.g. mpirun, mpiexec_mpt, mpiexec -np 8 --oversubscribe"
  echo "  -t <toolchain>               toolchain for the test"
  echo "  -k <diff exec>            Diff executable"
  echo "  -s <folder>               Save result data to prefix location, full path for run constructed as <work>/<thisfolder>/<namelist>/"
  echo "  -i <folder>               Folder for bitwise-identical results, full path for run constructed as <work>/<thisfolder>/<namelist>/"
  echo "  -e <varA=val,varB,...>    Environment variables in comma-delimited list, e.g. var=1,foo,bar=0"
  echo "  -- <hostenv.sh options>   Directly pass options to hostenv.sh, equivalent to hostenv.sh <options>"
  echo "  -h                        Print this message"
  echo ""
  echo "If you wish to use an env var in your arg such as '-c \$SERIAL -e SERIAL=32', you must"
  echo "you will need to do '-c \\\$SERIAL -e SERIAL=32' to delay shell expansion when input from shell/CLI"
  echo ""
  echo "If -i <folder> is provided, bitwise-identical checks are performed as part of checks"
}

cwd=$(dirname "$0")

. $cwd/utils.sh

echo "Input arguments:"
echo "$*"

AS_HOST=$1
shift
if [ $AS_HOST = "-h" ]; then
  help
  exit 0
fi


workingDirectory=$1
shift

cd $workingDirectory || exit

# default precision is single
precision="single"

# Get some helper functions
. .ci/env/helpers.sh

while getopts c:g:r:b:f:d:q:y:z:w:p:t:k:s:i:e:nh opt; do
  case $opt in
    c)
      testcase="$OPTARG"
    ;;
    g)
      testType="$OPTARG"
    ;;
    r)
      rootDir="$OPTARG"
    ;;
    b)
      mpasExecutable="$OPTARG"
    ;;
    f)
      caseInputDir="$OPTARG"
    ;;
    n)
      precision="double"
    ;;
    d)
      device="$OPTARG"
    ;;
    q)
      restartInterval="$OPTARG"
    ;;
    y)
      restartTime="$OPTARG"
    ;;
    z)
      runDuration="$OPTARG"
    ;;
    w)
      outputInterval="$OPTARG"
    ;;
    p)
      parallelExec="$OPTARG"
    ;;
    t)
      toolchain="$OPTARG"
    ;;
    k)
      diffExec="$OPTARG"
    ;;
    e)
      envVars="$envVars,$OPTARG"
    ;;
    h)  help; exit 0 ;;
    *)  help; exit 1 ;;
    :)  help; exit 1 ;;
    \?) help; exit 1 ;;
  esac
done

shift "$((OPTIND - 1))"

# Everything else goes to our env setup
. .ci/env/hostenv.sh $*

# Now evaluate env vars in case it pulls from hostenv.sh
if [ ! -z $envVars ]; then
  setenvStr "$envVars"
fi

# Check if testcase is valid
if [ "$testcase" != "jw" ] && [ "$testcase" != "conus" ] && [ "$testcase" != "aquaplanet" ]; then
    echo "Error: Invalid testcase '$testcase'. Must be one of 'jw', 'conus', or 'aquaplanet'."
    exit 1
fi

# Check if testType is valid
if [ "$testType" != "base" ] && [ "$testType" != "refgen" ] && 
   [ "$testType" != "restart" ] && [ "$testType" != "mpi" ] && [ "$testType" != "multinode" ] &&
   [ "$testType" != "multigpu" ] && [ "$testType" != "omp" ] &&
   [ "$testType" != "perfgen" ] && [ "$testType" != "perfcmp" ]; then  
    echo "Error: Invalid testType '$testType'. Must be one of 'base', 'refgen', 'restart', 'mpi', 'multigpu', 'omp', 'perfgen', or 'perfcmp'."
    exit 1
fi

# Check if toolchain is valid
if [ "$toolchain" != "gnu" ] && [ "$toolchain" != "nvhpc" ] && [ "$toolchain" != "intel" ]; then
    echo "Error: Invalid toolchain '$toolchain'. Must be one of 'gnu', 'nvhpc', or 'intel'."
    exit 1
fi

# Check if device is valid
if [ "$device" != "cpu" ] && [ "$device" != "gpu" ]; then
    echo "Error: Invalid device '$device'. Must be one of 'cpu' or 'gpu'."
    exit 1
fi


runDir=${testcase}_${toolchain}_${testType}_${device}_${precision}

baserunDir=${testcase}_${toolchain}_base_${device}_${precision}

TESTNAME="${testcase} ${toolchain} ${testType} ${device} ${precision}"
echo "TEST : $TESTNAME"

# from https://ncar-hpc-docs.readthedocs.io/en/latest/pbs/job-scripts/#derecho
CI_NNODES=$(cat ${PBS_NODEFILE} | sort | uniq | wc -l)
CI_NTASKS=$(cat ${PBS_NODEFILE} | sort | wc -l)
CI_TASKS_PER_NODE=$((${CI_NTASKS} / ${CI_NNODES}))

echo "CI_NNODES: $CI_NNODES , CI_NTASKS: $CI_NTASKS , CI_TASKS_PER_NODE: $CI_TASKS_PER_NODE"


log_file="log.atmosphere.0000.out"

# Re-evaluate input values for delayed expansion
eval "rootDir=\$( realpath \"$rootDir\" )"
eval "caseInputDir=\$( realpath \"$caseInputDir\" )"
eval "parallelExec=\"$parallelExec\""
eval "runDir=\"$runDir\""
eval "baserunDir=\"$baserunDir\""

# Now set to realpath since it exists 
runDir=$( realpath $runDir )
baserunDir=$( realpath $baserunDir )

rm -rf $runDir
mkdir -p $runDir

ln -sf $workingDirectory/$mpasExecutable $runDir/$mpasExecutable

eval "mpasExecutable=\$( realpath \"$runDir/$mpasExecutable\" )"

echo "mpas executable: $mpasExecutable"

# Check our paths
if [ ! -x "${mpasExecutable}" ]; then
    echo "No mpas executable found"
    exit 1
fi

if [ ! -d "${caseInputDir}" ]; then
    echo "No valid Case Input Directory provided"
    exit 1
fi

################################################################################
#
# Things done only once
# Go to core dir to make sure it exists
cd $workingDirectory || exit $?

#eval "repo_id=\$( git describe --abbrev=20 )"
eval "repo_id=\$( git rev-parse --short=20 HEAD )"  # github actions doesn't fetch tags yet
eval "repo_id_short=\$( git rev-parse --short=10 HEAD )"  # github actions doesn't fetch tags yet
eval "repo_timestamp=\$( git show --no-patch --format=%ci )"

# Go to run location now - We only operate here from now on
cd $runDir || exit $?
# TODO: Clean up previous runs


# Copy namelist
echo "Setting $caseInputDir/namelist.atmosphere  as namelist.atmosphere "
# TODO: remove old namelist.input which may be a symlink in which case this would have failed
#rm namelist.input
cp $caseInputDir/namelist.atmosphere namelist.atmosphere || exit $?
cp $caseInputDir/streams.atmosphere streams.atmosphere || exit $?
cp $caseInputDir/stream_list.atmosphere.output stream_list.atmosphere.output || exit $?


if [ -n "$restartInterval" ]; then
  #nml_replace "restart_interval" "$restartInterval" namelist.atmosphere
  stream_replace "restart" "output_interval" "$restartInterval" streams.atmosphere
fi

if [ -n "$outputInterval" ]; then
  stream_replace "output" "output_interval" "$outputInterval" streams.atmosphere
fi


if [ "$testType" = "restart" ]; then
    nml_replace "config_do_restart" "true" namelist.atmosphere
    nml_replace_quotes "config_run_duration" "$runDuration" namelist.atmosphere
    nml_replace_quotes "config_start_time" "$restartTime" namelist.atmosphere
    if [ -n "$restartTime" ]; then
        restartTime_modified=$(echo "$restartTime" | tr ':' '.')
        echo "trying to link $baserunDir/restart.$restartTime_modified.nc"
        ln -sf $baserunDir/restart.$restartTime_modified.nc .
        #ln -sf $workingDirectory/test_base/restart.$restartTime.nc $workingDirectory/$runDir/restart.$restartTime.nc
    fi  
fi

if [ -n "$restartInterval" ]; then
  #nml_replace "restart_interval" "$restartInterval" namelist.atmosphere
  stream_replace "restart" "output_interval" "$restartInterval" streams.atmosphere
fi

if [ "$testType" = "perf" ]; then
  nml_replace_quotes "config_run_duration" "$runDuration" namelist.atmosphere
  stream_replace "restart" "output_interval" "none" streams.atmosphere
  stream_replace "output" "output_interval" "none" streams.atmosphere
fi


# Link in data in here
if [ "$testcase" = "jw" ]; then
    grid_file="x1.40962.grid.nc"
    init_file="x1.40962.init.nc"
    part_prefix="x1.40962.graph.info.part."
    restart_compare_time='0000-01-01_02.00.00'
elif [ "$testcase" = "conus" ]; then
    init_file="conus.init.nc"
    part_prefix="conus.graph.info.part."
    lbc_prefix='lbc.'
    restart_compare_time='2019-09-01_00.20.00'
    cp $caseInputDir/stream_list.atmosphere.diagnostics . || exit $?
    cp $caseInputDir/stream_list.atmosphere.surface . || exit $?
    ln -sf $workingDirectory/*.TBL . || exit $?
    ln -sf $workingDirectory/*.DBL . || exit $?
    ln -sf $caseInputDir/*.DBL . || exit $?
    ln -sf $workingDirectory/*_DATA . || exit $?
fi


#ln -sf $caseInputDir/$grid_file .   || exit $?
ln -sf $caseInputDir/$init_file .    || exit $?
ln -sf $caseInputDir/${part_prefix}* .   || exit $?

if [ -n "$lbc_prefix" ]; then
    ln -sf $caseInputDir/${lbc_prefix}* .   || exit $?
fi

#
################################################################################


################################################################################
#

# Since we might fail or succeed on certain namelists, make a running set of failures
errorMsg=""


banner 42 "START MPAS"

# run MPAS
echo "Running $parallelExec $mpasExecutable"

#eval "$parallelExec $mpasExecutable | tee mpas.print.out"
eval "$parallelExec $mpasExecutable"
result=$?
if [ -n "$parallelExec" ]; then
  # Output the log files
  cat $( ls ./log.atmosphere.* | sort | head -n 1 )
fi



if [ "$result" -eq 0 ]; then
    banner 42 "TEST RUN: $TESTNAME FINISHED SUCCESSFULLY"
else
    banner 42 "TEST RUN: $TESTNAME FAILED "
    exit 1
fi

  

if [ "$testType" = "restart" ] || [ "$testType" = "mpi" ] || [ "$testType" = "multigpu" ] || [ "$testType" = "omp" ]; then

    diff_output $runDir/restart.${restart_compare_time}.nc $baserunDir/restart.${restart_compare_time}.nc
    result=$?

elif [ "$testType" = "base" ]; then

    head_sha=$( cat $caseInputDir/reference/head_${toolchain}_${device}_${precision} ) || exit $?
    echo "Comparing base with reference SHA: $head_sha"
    echo "Restart file: $caseInputDir/reference/restart.${restart_compare_time}_${head_sha}_${toolchain}_${device}.nc"
    diff_output $runDir/restart.${restart_compare_time}.nc "$caseInputDir/reference/restart.${restart_compare_time}_${head_sha}_${toolchain}_${device}_${precision}.nc"
    result=$?

elif [ "$testType" = "refgen" ]; then
  
    mv "$runDir/restart.${restart_compare_time}.nc" "$caseInputDir/reference/restart.${restart_compare_time}_${repo_id_short}_${toolchain}_${device}_${precision}.nc" || exit $?
    
    echo "${repo_id_short}" > $caseInputDir/reference/head_${toolchain}_${device}_${precision} || exit $?

elif [ "$testType" = "perfgen" ] || [ "$testType" = "perfcmp" ]; then

    log_file_path=$runDir/$log_file

    #eval "totaltime_1=\$( sed -n '/timer_name/,/-------/p'  $log_file_path | awk '{print \$4}' | head -2 | tail -1 )"
    extract_totaltime $log_file_path
    result=$?
    totaltime_1=$totaltime
    echo "Total time: $totaltime_1"

    # If the testType is perf, run the code four more times

    for i in {2..5}; do
      eval "$parallelExec $mpasExecutable"
      extract_totaltime $log_file_path
      eval "totaltime_$i=$totaltime"
      #echo "Total time: $totaltime_$i"
      eval "echo "Total time: \$totaltime_$i""
    done

    db_file="/glade/campaign/mmm/wmr/mpas_ci/test2.db"

    machine="derecho"

    if [ "$testType" = "perfgen" ]; then
        eval "python $workingDirectory/.ci/tests/perf_stats.py $db_file $testcase $machine $device $toolchain $repo_id $totaltime_1,$totaltime_2,$totaltime_3,$totaltime_4,$totaltime_5"
    elif [ "$testType" = "perfcmp" ]; then
        eval "python $workingDirectory/.ci/tests/query_perf_db.py compare_to_ref $db_file $testcase $machine $device $toolchain $totaltime_1,$totaltime_2,$totaltime_3,$totaltime_4,$totaltime_5"
    fi
    result=$?

fi


if [ "$result" -eq 0 ]; then
    echo "TEST $TESTNAME PASS"
    echo "TEST $(basename $0) PASS"
else
    echo "TEST $TESTNAME FAIL"
    exit 1
fi




#if [ -z "$errorMsg" ]; then
# Unlink everything we linked in
#ls $data/ | xargs -I{} rm {}

# Clean up once more since we passed

# We passed!
#echo "TEST $(basename $0) PASS"
#else
#printf "%b" "$errorMsg"
#exit 1
#fi

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
  echo "  -n <namelists>            Namelists to use"
  echo "  -d <device>               Device to use"
  echo "  -q <interval>             Restart interval"
  echo "  -y <time>                 Restart time"
  echo "  -z <duration>             Run duration"
  echo "  -w <interval>             Output interval"
  echo "  -p <mpirun cmd>           Parallel launch command (MPI), e.g. mpirun, mpiexec_mpt, mpiexec -np 8 --oversubscribe"
  echo "  -t <target>               Target for the test"
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

source $cwd/utils.sh

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

cd $workingDirectory


# Get some helper functions
. .ci/env/helpers.sh

while getopts c:g:r:b:f:n:d:q:y:z:w:p:t:k:s:i:e:h opt; do
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
      namelists="$OPTARG"
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
      target="$OPTARG"
    ;;
    k)
      diffExec="$OPTARG"
    ;;
    s)
      moveFolder="$OPTARG"
    ;;
    i)
      identicalFolder="$OPTARG"
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
if [[ "$testcase" != "jw" && "$testcase" != "conus" && "$testcase" != "aquaplanet" ]]; then
  echo "Error: Invalid testcase '$testcase'. Must be one of 'jw', 'conus', or 'aquaplanet'."
  exit 1
fi


# Check if testType is valid
if [[ "$testType" != "base" && "$testType" != "restart" && "$testType" != "mpi" && "$testType" != "multigpu" && "$testType" != "omp" && "$testType" != "perf" ]]; then
  echo "Error: Invalid testType '$testType'. Must be one of 'base', 'restart', 'mpi', or 'omp'."
  exit 1
fi
runDir=${testcase}_${target}_${testType}_${device}

baserunDir=${testcase}_${target}_base_${device}

TESTNAME="${testcase} ${target} ${testType} ${device}"
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
eval "namelists=\"$namelists\""
#eval "data=\$( realpath \"$data\" )"
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
#wrf=$( realpath $( find $runDir -type f -name wrf -o -name wrf.exe | head -n 1 ) )
#rd_12_norm=$( realpath .ci/tests/SCRIPTS/rd_l2_norm.py )

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
#cd $rootDir || exit $?
cd $workingDirectory || exit $?

#eval "repo_id=\$( git describe --abbrev=20 )"
eval "repo_id=\$( git rev-parse --short=20 HEAD )"  # github actions doesn't fetch tags yet
eval "repo_timestamp=\$( git show --no-patch --format=%ci )"

# Clean up previous runs
# rm wrfinput_d* wrfbdy_d* wrfout_d* wrfchemi_d* wrf_chem_input_d* rsl* real.print.out* wrf.print.out* wrf_d0*_runstats.out qr_acr_qg_V4.dat fort.98 fort.88 -rf


# Go to run location now - We only operate here from now on
cd $runDir || exit $?
# Clean up previous runs
# rm wrfinput_d* wrfbdy_d* wrfout_d* wrfchemi_d* wrf_chem_input_d* rsl* real.print.out* wrf.print.out* wrf_d0*_runstats.out qr_acr_qg_V4.dat fort.98 fort.88 -rf


# Copy namelist
echo "Setting $caseInputDir/namelist.atmosphere  as namelist.atmosphere "
# remove old namelist.input which may be a symlink in which case this would have failed
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

if [[ "$testType" == "restart" ]]; then
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

if [[ "$testType" == "perf" ]]; then
  nml_replace_quotes "config_run_duration" "$runDuration" namelist.atmosphere
  stream_replace "restart" "output_interval" "none" streams.atmosphere
  stream_replace "output" "output_interval" "none" streams.atmosphere
fi


# Link in data in here
if [[ "$testcase" == "jw" ]]; then
    grid_file="x1.40962.grid.nc"
    init_file="x1.40962.init.nc"
    part_prefix="x1.40962.graph.info.part."
    restart_compare_time='0000-01-01_02.00.00'
elif  [[ "$testcase" == "conus" ]]; then
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

  

if [[ "$testType" != "perf" ]]; then
  diff_output $runDir/restart.${restart_compare_time}.nc $baserunDir/restart.${restart_compare_time}.nc
  result=$?

  cd $workingDirectory
  #rm -rf test_$testType

  if [ "$result" -eq 0 ]; then
    echo "TEST $TESTNAME PASS"
    exit 0
  else
    echo "TEST $TESTNAME FAIL"
    exit 1
  fi
else

log_file_path=$runDir/$log_file

#eval "totaltime_1=\$( sed -n '/timer_name/,/-------/p'  $log_file_path | awk '{print \$4}' | head -2 | tail -1 )"
extract_totaltime $log_file_path
totaltime_1=$totaltime
echo "Total time: $totaltime_1"

# If the testType is perf, run the code two more times and calculate the average time

for i in {2..5}; do
  eval "$parallelExec $mpasExecutable"
  extract_totaltime $log_file_path
  eval "totaltime_$i=$totaltime"
  #echo "Total time: $totaltime_$i"
  eval "echo "Total time: \$totaltime_$i""
done

db_file="/glade/campaign/mmm/wmr/mpas_ci/test2.db"

machine="derecho"

eval "python $workingDirectory/.ci/tests/perf_stats.py $db_file $testcase $machine $device $target $repo_id $totaltime_1,$totaltime_2,$totaltime_3,$totaltime_4,$totaltime_5"

#eval "python $workingDirectory/.ci/tests/query_perf_db.py compare_to_ref $db_file $testcase $machine $device $target $totaltime_1,$totaltime_2,$totaltime_3,$totaltime_4,$totaltime_5"

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

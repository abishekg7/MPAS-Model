#!/bin/sh
help()
{
  echo "./runTestCases.sh as_host working_dir test_type [options] [-- <hostenv.sh options>]"
  echo "  as_host                   First argument must be the host configuration to use for environment loading"
  echo "  working_dir               Second argument must be the working dir to immediate cd to"
  echo "  test_type                 Third argument must be the working dir to immediate cd to"
  echo "  -c <folder>               Directory for specific core built"
  echo "  -r <folder>               Directory to run in using mkdir and symlinking -c <folder> for each namelist"
  echo "  -b <exec>                 Binary executable for MPAS"
  echo "  -f <folder>               Directory to look for input files in"
  echo "  -d <folder>               Data directory to link into run directory"
  echo "  -ri <time>               Restart interval"
  echo "  -oi <time>               Output interval"
  echo "  -p <mpirun cmd>           Parallel launch command (MPI), e.g. mpirun, mpiexec_mpt, mpiexec -np 8 --oversubscribe"

  echo "  -s <folder>               Save result data to prefix location, full path for run constructed as <work>/<thisfolder>/<namelist>/ "
  echo "  -i <folder>               Folder for bitwise-identical results, full path for run constructed as <work>/<thisfolder>/<namelist>/ "
  echo "  -e <varA=val,varB,...>    environment variables in comma-delimited list, e.g. var=1,foo,bar=0"
  echo "  -- <hostenv.sh options>   Directly pass options to hostenv.sh, equivalent to hostenv.sh <options>"
  echo "  -h                  Print this message"
  echo ""
  echo "If you wish to use an env var in your arg such as '-c \$SERIAL -e SERIAL=32', you must"
  echo "you will need to do '-c \\\$SERIAL -e SERIAL=32' to delay shell expansion when input from shell/CLI"
  echo ""
  echo "If -i <folder> is provided, bitwise-identical checks are performed as part of checks"
}

nml_replace(){
    PARAM=$1
    VALUE=$2
    FILE=$3
    if grep -q '^[[:space:]]*'${PARAM}'[[:space:]]*=' ${FILE}; then
        sed 's/\(^\s*'$PARAM'\s*=\s*\).*$/\1'${VALUE}'/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${PARAM} not found in ${FILE}"
        exit 1
    fi
}


stream_replace(){
    FILETYPE=$1
    PARAM=$2
    VALUE=$3
    FILE=$4
    if grep -q '<[A-Za-z_]*stream name="'${FILETYPE}'"' ${FILE}; then
        sed '/<.*stream name="'$FILETYPE'"/,/\/>/s/\('$PARAM'="\)[^"]*\(".*\)/\1'$VALUE'\2/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${FILETYPE} not found in ${FILE}"
        exit 1
    fi
}


function diff_output
{
    
    FILE_TEST=$1
    FILE_REF=$2

    module load cdo
    which cdo
    
    # status variable that is evaluated after the function call
    STATUS=0
    
    if [ -f "$FILE_TEST" ] && [ -f "$FILE_REF" ]; then
      echo "Comparing $FILE_TEST and $FILE_REF"
      #DIFF_FILE="cdo_diffn_${DEXP1}_${DEXP2}_${TYPE}_${DATE}_${TEMP_SUFFIX}.out"
      cdo diffv ${FILE_TEST} ${FILE_REF} #> ${DIFF_FILE}
      STATUS=$?
      if [ $STATUS == 0 ]; then
            banner 42 "The experiments are bit-identical"
      else
            banner 42 "The experiments are NOT bit-identical"
      fi
		else
		    echo "File(s) for $TYPE not found:"
		    if ! [ -f  "$FILE_TEST" ]; then echo "FILE_TEST does not exist: $FILE_TEST"; fi
		    if ! [ -f  "$FILE_REF" ]; then echo "FILE_REF does not exist: $FILE_REF"; fi
		fi
}



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
      namelistFolder="$OPTARG"
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


# Check if testType is valid
if [[ "$testType" != "base" && "$testType" != "restart" && "$testType" != "mpi" && "$testType" != "omp" ]]; then
  echo "Error: Invalid testType '$testType'. Must be one of 'base', 'restart', 'mpi', or 'omp'."
  exit 1
fi
runDir=${testcase}_${target}_${testType}_${device}

baserunDir=${testcase}_${target}_base_${device}

echo "TESTNAME : $TESTNAME"


# Re-evaluate input values for delayed expansion
eval "rootDir=\$( realpath \"$rootDir\" )"
eval "namelistFolder=\$( realpath \"$namelistFolder\" )"
eval "namelists=\"$namelists\""
#eval "data=\$( realpath \"$data\" )"
eval "parallelExec=\"$parallelExec\""
eval "moveFolder=\"$moveFolder\""
eval "identicalFolder=\"$identicalFolder\""

eval "runDir=\"$runDir\""

# Now set to realpath since it exists 
runDir=$( realpath $runDir )

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

if [ ! -d "${namelistFolder}" ]; then
  echo "No valid namelist folder provided"
  exit 1
fi



################################################################################
#
# Things done only once
# Go to core dir to make sure it exists
cd $rootDir || exit $?

# Clean up previous runs
# rm wrfinput_d* wrfbdy_d* wrfout_d* wrfchemi_d* wrf_chem_input_d* rsl* real.print.out* wrf.print.out* wrf_d0*_runstats.out qr_acr_qg_V4.dat fort.98 fort.88 -rf


# Go to run location now - We only operate here from now on
cd $runDir || exit $?
# Clean up previous runs
# rm wrfinput_d* wrfbdy_d* wrfout_d* wrfchemi_d* wrf_chem_input_d* rsl* real.print.out* wrf.print.out* wrf_d0*_runstats.out qr_acr_qg_V4.dat fort.98 fort.88 -rf


# Copy namelist
echo "Setting $namelistFolder/namelist.atmosphere  as namelist.atmosphere "
# remove old namelist.input which may be a symlink in which case this would have failed
#rm namelist.input
cp $namelistFolder/namelist.atmosphere namelist.atmosphere || exit $?
cp $namelistFolder/streams.atmosphere streams.atmosphere || exit $?
cp $namelistFolder/stream_list.atmosphere.output stream_list.atmosphere.output || exit $?


if [ -n "$restartInterval" ]; then
  #nml_replace "restart_interval" "$restartInterval" namelist.atmosphere
  stream_replace "restart" "output_interval" "$restartInterval" streams.atmosphere
fi

if [ -n "$outputInterval" ]; then
  stream_replace "output" "output_interval" "$outputInterval" streams.atmosphere
fi

if [[ "$testType" == "restart" ]]; then
  nml_replace "config_do_restart" "true" namelist.atmosphere
  nml_replace "config_run_duration" "$runDuration" namelist.atmosphere
  nml_replace "config_start_time" "$restartTime" namelist.atmosphere
  if [ -n "$restartTime" ]; then
      restartTime_modified=$(echo "$restartTime" | tr ':' '.')
      echo "trying to link $workingDirectory/test_base/restart.$restartTime_modified.nc"
      ln -sf $workingDirectory/test_base/restart.$restartTime_modified.nc .
      #ln -sf $workingDirectory/test_base/restart.$restartTime.nc $workingDirectory/$runDir/restart.$restartTime.nc
  fi  
fi

if [ -n "$restartInterval" ]; then
  #nml_replace "restart_interval" "$restartInterval" namelist.atmosphere
  stream_replace "restart" "output_interval" "$restartInterval" streams.atmosphere
fi

# Link in data in here
ln -sf $namelistFolder/x1.40962.grid.nc .
ln -sf $namelistFolder/x1.40962.init.nc .
ln -sf $namelistFolder/x1.40962.graph.info.part.* .

#
################################################################################


################################################################################
#

# Since we might fail or succeed on certain namelists, make a running set of failures
errorMsg=""


banner 42 "START MPAS"

# run MPAS
echo "Running $parallelExecToUse $mpasExecutable"

eval "$parallelExecToUse $mpasExecutable | tee mpas.print.out"
result=$?
if [ -n "$parallelExecToUse" ]; then
  # Output the rsl. output
  cat $( ls ./log.atmosphere.* | sort | head -n 1 )
fi



if [ "$result" -eq 0 ]; then
    banner 42 "TEST RUN: $testType FINISHED SUCCESSFULLY"
else
    banner 42 "TEST RUN: $testType FAILED "
    exit 1
fi

  

# If we passed, clean up after ourselves
if [[ "$testType" != "base" ]]; then
  diff_output $workingDirectory/$runDir/restart.0000-01-01_02.00.00.nc $workingDirectory/$baserunDir/restart.0000-01-01_02.00.00.nc 
  result=$?

  cd $workingDirectory
  rm -rf test_$testType

  if [ "$result" -eq 0 ]; then
    echo "TEST $(basename $0) PASS"
  else
    echo "TEST $(basename $0) FAIL"
    exit 1
  fi
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

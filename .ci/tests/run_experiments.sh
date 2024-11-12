#!/bin/sh

create_run_directory() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    echo "Directory $1 created."
  else
    echo "Directory $1 already exists."
  fi

  pushd "$1"

  ln -sf ../../atmosphere_model . 
  echo "Symbolic link to compiled program created in $testDirectory"

  ln -s /glade/derecho/scratch/agopal/jw_input/x1.40962.init.nc .
  ln -s /glade/derecho/scratch/agopal/jw_input/x1.40962.grid.nc .
  ln -s /glade/derecho/scratch/agopal/jw_input/x1.40962.graph.info.part.* .

  cp /glade/derecho/scratch/agopal/jw_input/stream_list.atmosphere.output .
  cp /glade/derecho/scratch/agopal/jw_input/streams.atmosphere .
  cp /glade/derecho/scratch/agopal/jw_input/namelist.atmosphere .

  popd  
}


nml_replace(){
    KEY=$1
    VALUE=$2
    FILE=$3
    if grep -q '^[[:space:]]*'${KEY}'[[:space:]]*=' ${FILE}; then
        sed 's/\('$KEY'\s*=\s*\).*/\1'"$VALUE"'/' < ${FILE} > ${FILE}.out
        mv ${FILE}.out ${FILE}
    else
        echo "$0:${FUNCNAME}: ERROR parameter ${PARAM} not found in ${FILE}"
        exit 1
    fi
}

stream_replace(){
    STREAM_BEGIN=$1
    STREAM_END=$2
    KEY=$3
    VALUE=$4
    FILE=$5

    #if grep -q '^[[:space:]]*'${KEY}'[[:space:]]*=' ${FILE}; then
        sed '/'$STREAM_BEGIN'/,/'$STREAM_END'/s/\('$KEY'="\)[^"]*\(".*\)/\1'"$VALUE"'\2/' < ${FILE} > ${FILE}.out
    #    mv ${FILE}.out ${FILE}
    #else
    #    echo "$0:${FUNCNAME}: ERROR parameter ${PARAM} not found in ${FILE}"
    #    exit 1
    #fi
}

compare_netcdf_files() {
  local file1=$1
  local file2=$2

  # Use cdo diffv to compare the two NetCDF files
  cdo diffv "$file1" "$file2"
  local diff_result=$?

  if [ $diff_result -eq 0 ]; then
    echo "No differences found between $file1 and $file2"
    return 0
  else
    echo "Differences found between $file1 and $file2"
    return 1
  fi
}

write_pbs_script() {
  local job_name=$1
  local walltime=$2
  local nodes=$3
  local ppn=$4
  local script_file=$5

  cat <<EOF > $script_file
#!/bin/bash
#PBS -A NMMM0013
#PBS -q develop
#PBS -l job_priority=premium
#PBS -N $job_name
#PBS -l walltime=$walltime
#PBS -l select=$nodes:ncpus=64:mpiprocs=$ppn
##PBS -l nodes=$nodes:ppn=$ppn

module --force purge
ml ncarenv/23.09
ml craype
ml nvhpc
ml ncarcompilers
ml cray-mpich
ml parallel-netcdf
ml cuda

which nsys
echo \$PATH

cd \$PBS_O_WORKDIR

mpiexec -n $ppn ./atmosphere_model 
EOF

  echo "PBS job script written to $script_file"
}


submit_and_check_pbs_job() {
  local script_file=$1

  # Submit the PBS job and capture the job ID
  job_id=$(qsub $script_file)
  if [ $? -ne 0 ]; then
    echo "Failed to submit PBS job"
    exit 1
  fi

  echo "PBS job submitted with job ID: $job_id"
  sleep 10

  # Monitor the job status
  while true; do
    job_status=$(qstat -f "$job_id" | grep job_state | awk '{print $3}')
    if [ "$job_status" = "E" ] || [ -z "$job_status" ]; then
      break
    fi
    sleep 1
  done

  # Check the exit status
  exit_status=$(qstat -fx "$job_id" | grep Exit_status | awk '{print $3}')
  echo "$exit_status"
  #exit_status="${exit_status//[$'\t\r\n ']}"
  if [ "$exit_status" -ne 0 ]; then
    echo "PBS job failed with exit status: $exit_status"
    exit 1
  fi

  echo "PBS job completed successfully"
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


run_base_exp(){
  create_run_directory base
  pushd base

  new_name="output_base.nc"
  # Use sed to find <stream name="output"> and replace the value of filename_template
  sed -i '/<stream name="output"/,/<\/stream>/s/\(filename_template="\)[^"]*\(".*\)/\1'"$new_name"'\2/' streams.atmosphere
  #sed '/'$STREAM_BEGIN'/,/'$STREAM_END'/s/\('$KEY'="\)[^"]*\(".*\)/\1'"$VALUE"'\2/' < ${FILE} > ${FILE}.out


  rest_interval="01:00:00"
  sed -i '/<immutable_stream name="restart"/,/<\/>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$rest_interval"'\2/' streams.atmosphere

  out_interval="02:00:00"
  sed -i '/<stream name="output"/,/<\/stream>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$out_interval"'\2/' streams.atmosphere


  write_pbs_script "my_job" "02:00:00" 1 16 "job_script.pbs"

  submit_and_check_pbs_job "job_script.pbs"

  run_result=$?

  if [ $run_result -ne 0 ]; then
    echo "Failed to run the base simulation"
    exit 1
  fi

  popd

}

run_parallel_test(){
  create_run_directory parallel
  pushd parallel

  new_name="output_restart.nc"
  # Use sed to find <stream name="output"> and replace the value of filename_template
  sed -i '/<stream name="output"/,/<\/stream>/s/\(filename_template="\)[^"]*\(".*\)/\1'"$new_name"'\2/' streams.atmosphere
  #sed '/'$STREAM_BEGIN'/,/'$STREAM_END'/s/\('$KEY'="\)[^"]*\(".*\)/\1'"$VALUE"'\2/' < ${FILE} > ${FILE}.out


  rest_interval="02:00:00"
  sed -i '/<immutable_stream name="restart"/,/<\/>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$rest_interval"'\2/' streams.atmosphere

  out_interval="02:00:00"
  sed -i '/<stream name="output"/,/<\/stream>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$out_interval"'\2/' streams.atmosphere


  write_pbs_script "my_job" "02:00:00" 1 24 "job_script.pbs"

  submit_and_check_pbs_job "job_script.pbs"

  run_result=$?

  if [ $run_result -ne 0 ]; then
    echo "Failed to run the parallel simulation"
    exit 1
  fi

  popd
  compare_netcdf_files "base/restart.0000-01-01_02.00.00.nc" "parallel/restart.0000-01-01_02.00.00.nc"
  echo "TEST $(basename $0) PASS"

}

run_restart_test()
{
  create_run_directory restart
  pushd restart

  ln -s ../base/restart.0000-01-01_01.00.00.nc .

  new_start_time='0000-01-01_01:00:00'
  nml_replace 'config_start_time' "$new_start_time" namelist.atmosphere
  new_run_duration='01:00:00'
  nml_replace 'config_run_duration' "$new_run_duration" namelist.atmosphere
  do_restart='true'
  nml_replace 'config_do_restart' "$do_restart" namelist.atmosphere
  
  rest_interval="01:00:00"
  sed -i '/<immutable_stream name="restart"/,/<\/>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$rest_interval"'\2/' streams.atmosphere

  out_interval="02:00:00"
  sed -i '/<stream name="output"/,/<\/stream>/s/\(output_interval="\)[^"]*\(".*\)/\1'"$out_interval"'\2/' streams.atmosphere

  new_name="output_rest.nc"
  sed -i '/<stream name="output"/,/<\/stream>/s/\(filename_template="\)[^"]*\(".*\)/\1'"$new_name"'\2/' streams.atmosphere


  write_pbs_script "my_job" "02:00:00" 1 16 "job_script.pbs"
  submit_and_check_pbs_job "job_script.pbs"
  run_result=$?
  if [ $run_result -ne 0 ]; then
    echo "Failed to run the compiled program"
    exit 1
  fi

  popd
  compare_netcdf_files "base/restart.0000-01-01_02.00.00.nc" "restart/restart.0000-01-01_02.00.00.nc"
  echo "TEST $(basename $0) PASS"

}



help()
{
  echo "./run_experiments.sh as_host workingdir [options] [-- <hostenv.sh options>]"
  echo "  as_host                   First argument must be the host configuration to use for environment loading"
  echo "  workingdir                Second argument must be the working dir to immediate cd to"
  echo "  -e                        environment variables in comma-delimited list, e.g. var=1,foo,bar=0"
  echo "  -- <hostenv.sh options>   Directly pass options to hostenv.sh, equivalent to hostenv.sh <options>"
  echo "  -h                  Print this message"
  echo ""
  echo "If you wish to use an env var in your arg such as '-b core=\$CORE -e CORE=atmosphere', you must"
  echo "you will need to do '-b \\\$CORE -e CORE=atmosphere' to delay shell expansion"
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

# Get some helper functions, AS_HOST must be set by this point to work
. .ci/env/helpers.sh

while getopts e:h opt; do
  case $opt in
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

# Everything else goes to our env setup, POSIX does not specify how to pass in
# arguments to sourced script, but all args are already shifted. This is left for
# posterity to "show" what is happening and the assumption of the remaining args
. .ci/env/hostenv.sh $*

# Now evaluate env vars in case it pulls from hostenv.sh
if [ ! -z "$envVars" ]; then
  setenvStr "$envVars"
fi

testDirectory="$workingDirectory"/test
#create_run_directory "$testDirectory"
mkdir -p "$testDirectory"
pushd "$testDirectory"

run_base_exp

run_restart_test

run_parallel_test

echo "TEST $(basename $0) PASS"


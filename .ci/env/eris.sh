#!/bin/sh

echo "Setting up ERIS environment"
workingDirectory=$PWD

ulimit -s unlimited

source /nfs/coe-sw/lmod/8.7/init/bash

#module use /home/agopal/software/modules
# Overwriting the system value of MODULEPATH to include our own modules
export MODULEPATH=/home/agopal/software/modules/compilers:/home/agopal/software/modules/cdep

echo "Loading modules : $*"
cmd="module --force purge"
echo $cmd && eval "${cmd}"

# We should be handed in the modules to load
while [ $# -gt 0 ]; do 
  cmd="module load $1"
  echo $cmd && eval "${cmd}"
  shift
done

#  Go back to working directory if for unknown reason HPC config changing your directory on you
if [ "$workingDirectory" != "$PWD" ]; then
  echo "Eris module loading changed working directory"
  echo "  Moving back to $workingDirectory"
  cd $workingDirectory
fi

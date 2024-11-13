#!/usr/bin/env python3
import os
import shutil
import glob
import subprocess
import sys
import xml.etree.ElementTree as ET
import time
import re


def match_regex(pattern, string):
    # Search for the pattern in the string
    match = re.search(pattern, string)
    if match:
        # Extract the state
        output = match.group(1)
        return output
    else:
        return None

def update_stream_node(file_path, node_name, attr_name, new_value):
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Find the immutable_stream node with name="restart"
    for node in root.findall(".//*[@name='"+node_name+"']"):
        node.set(attr_name, new_value)
        break

    # Write the changes back to the file
    tree.write(file_path)

def nml_replace(param, value, file):
    with open(file, 'r') as f:
        lines = f.readlines()
    with open(file, 'w') as f:
        for line in lines:
            if line.strip().startswith(param):
                f.write(f"{param} = {value}\n")
            else:
                f.write(line)

def write_pbs_script(job_name, walltime, nodes, ppn, script_file):
    with open(script_file, 'w') as f:
        f.write(f"""#!/bin/bash
#PBS -A NMMM0013
#PBS -q develop
#PBS -l job_priority=premium
#PBS -N {job_name}
#PBS -l walltime={walltime}
#PBS -l select={nodes}:ncpus=64:mpiprocs={ppn}

module --force purge
ml ncarenv/23.09
ml craype
ml nvhpc
ml ncarcompilers
ml cray-mpich
ml parallel-netcdf
ml cuda

which nsys
echo $PATH

cd $PBS_O_WORKDIR

mpiexec -n {ppn} ./atmosphere_model
""")
    print(f"PBS job script written to {script_file}")

def submit_and_check_pbs_job(script_file):
    result = subprocess.run(['qsub', script_file], capture_output=True, text=True)
    if result.returncode != 0:
        print("Failed to submit PBS job")
        sys.exit(1)
    job_id = result.stdout.strip()
    print(f"PBS job submitted with job ID: {job_id}")
    return job_id

def monitor_job(job_id):
    time.sleep(10)
    while True:
        result = subprocess.run(['qstat', '-fx', job_id], capture_output=True, text=True)
        #p1 = subprocess.Popen(['qstat', '-f', job_id], stdout=subprocess.PIPE)
        #p2 = subprocess.Popen(["grep", "job_state"], stdin=p1.stdout, stdout=subprocess.PIPE)
        #result = subprocess.run(["awk", "'{print $3}'"], stdin=p2.stdout,  capture_output=True, text=True)
        job_state = match_regex(r'job_state = (\w)',result.stdout)
        if job_state:
            print(f"Job state found: {job_state}")
        else:
            print("Job state not found")
        if 'E' in job_state:# or result.stdout.strip() == '':
            break
        time.sleep(1)
    
    exit_cmd = subprocess.run(['qstat', '-fx', job_id], capture_output=True, text=True)
    exit_status = match_regex(r'Exit_status = ([0-9]+)',exit_cmd.stdout)
    if exit_status:
        if exit_status.strip() != '0':
            print(f"Job {job_id} failed with exit status {exit_status}")
            sys.exit(1)
        else:
            print(f"Successfully completed job {job_id}")
            return 0
    else:
        print("Exit state not found")

def compare_netcdf_files(file1, file2):
    result = subprocess.run(['cdo', 'diffv', file1, file2], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"No differences found between {file1} and {file2}")
    else:
        print(f"Differences found between {file1} and {file2}")
        sys.exit(1)

def create_directory(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)
        print(f"Directory {directory} created.")
    else:
        print(f"Directory {directory} already exists.")



def create_run_directory(directory):
    create_directory(directory)
    os.chdir(directory)

    # Create symbolic links
    os.symlink('../../atmosphere_model', 'atmosphere_model')
    print(f"Symbolic link to compiled program created in {directory}")

    os.symlink('/glade/derecho/scratch/agopal/jw_input/x1.40962.init.nc', 'x1.40962.init.nc')
    os.symlink('/glade/derecho/scratch/agopal/jw_input/x1.40962.grid.nc', 'x1.40962.grid.nc')
    
    for file in glob.glob('/glade/derecho/scratch/agopal/jw_input/x1.40962.graph.info.part.*'):
        os.symlink(file, os.path.basename(file))

    # Copy files
    shutil.copy('/glade/derecho/scratch/agopal/jw_input/stream_list.atmosphere.output', 'stream_list.atmosphere.output')
    shutil.copy('/glade/derecho/scratch/agopal/jw_input/streams.atmosphere', 'streams.atmosphere')
    shutil.copy('/glade/derecho/scratch/agopal/jw_input/namelist.atmosphere', 'namelist.atmosphere')

    os.chdir('..')


def run_base_exp():
    create_run_directory('base')
    os.chdir('base')

    file_path = 'streams.atmosphere'
    rest_interval = "01:00:00"
    update_stream_node(file_path, node_name="restart", attr_name="output_interval", new_value=rest_interval)

    out_interval = "02:00:00"
    update_stream_node(file_path, node_name="output", attr_name="output_interval", new_value=out_interval)

    new_name = "output_base.nc"
    update_stream_node(file_path, node_name="output", attr_name="filename_template", new_value=new_name)

    write_pbs_script("test_base", "02:00:00", 1, 16, "job_script.pbs")
    job_id = submit_and_check_pbs_job("job_script.pbs")
    monitor_job(job_id)

    os.chdir('..')

    

def run_restart_exp():
    create_run_directory('restart')
    os.chdir('restart')

    os.symlink('../base/restart.0000-01-01_01.00.00.nc', 'restart.0000-01-01_01.00.00.nc')

    nml_replace('config_start_time', '0000-01-01_01:00:00', 'namelist.atmosphere')
    nml_replace('config_run_duration', '01:00:00', 'namelist.atmosphere')
    nml_replace('config_do_restart', 'true', 'namelist.atmosphere')

    file_path = 'streams.atmosphere'
    rest_interval = "01:00:00"
    update_stream_node(file_path, node_name="restart", attr_name="output_interval", new_value=rest_interval)

    out_interval = "02:00:00"
    update_stream_node(file_path, node_name="output", attr_name="output_interval", new_value=out_interval)

    new_name = "output_rest.nc"
    update_stream_node(file_path, node_name="output", attr_name="filename_template", new_value=new_name)

    write_pbs_script("test_restart", "02:00:00", 1, 16, "job_script.pbs")
    job_id = submit_and_check_pbs_job("job_script.pbs")
    monitor_job(job_id)

    os.chdir('..')

    compare_netcdf_files("base/restart.0000-01-01_02.00.00.nc", "restart/restart.0000-01-01_02.00.00.nc")
    print(f"TEST {os.path.basename(__file__)} PASS")


def nml_replace(key, value, file):
    with open(file, 'r') as f:
        lines = f.readlines()
    with open(file, 'w') as f:
        for line in lines:
            if line.strip().startswith(key):
                f.write(f"{key} = {value}\n")
            else:
                f.write(line)



def main():
    create_directory('test')
    os.chdir('test')

    run_base_exp()
    run_restart_exp()

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
import os
import shutil
import glob
import subprocess
import sys
import xml.etree.ElementTree as ET
import time
import re
import yaml


def match_regex(pattern, string):
    """
    Matches a regex pattern in the given text and returns the first group.

    Args:
        pattern (str): The regex pattern to match.
        text (str): The text to search within.

    Returns:
        str: The matched group or None if no match is found.
    """
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
    """
    Monitors the status of a PBS job until it completes.

    Args:
        job_id (str): The ID of the PBS job to monitor.

    Returns:
        int: 0 if the job completes successfully, exits with status 1 if the job fails.
    """
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
    """
    Compares two NetCDF files using the cdo diffv command.

    Args:
        file1 (str): The path to the first NetCDF file.
        file2 (str): The path to the second NetCDF file.

    Returns:
        int: 0 if no differences are found, exits with status 1 if differences are found.
    """
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


def create_run_directory(directory, inputs):
    create_directory(directory)
    os.chdir(directory)

    # Create symbolic links
    os.symlink(inputs['model'], os.path.basename(inputs['model']))
    print(f"Symbolic link to compiled program created in {directory}")

    os.symlink(inputs['grid'], os.path.basename(inputs['grid']))
    os.symlink(inputs['init'], os.path.basename(inputs['init']))
    
    for file in glob.glob(inputs['partition']):
        os.symlink(file, os.path.basename(file))

    # Copy files
    shutil.copy(inputs['nml'], os.path.basename(inputs['nml']))
    shutil.copy(inputs['stream'], os.path.basename(inputs['stream']))
    shutil.copy(inputs['stream_out'], os.path.basename(inputs['stream_out']))
    
    os.chdir('..')


def run_exp(case, step_content, inputs):
    create_run_directory(case, inputs)
    os.chdir(case)

    stream_name = os.path.basename(inputs['stream'])
    nml_name = os.path.basename(inputs['nml'])
    
    print(f"Step: {case}")
    for child in step_content:
        print(f"  {child}: {step_content[child]}")
        if child == 'symlink':
            os.symlink(step_content[child], os.path.basename(step_content[child]))
        if child == 'update_nml':
            for key, value in step_content[child].items():
                print(f"      {key}: {value}")
                nml_replace(key, value, nml_name)
        if child == 'update_stream':
            for node, rest in step_content[child].items():
                print(f"      {node}: {rest}")
                for attr,val in rest.items():
                    print(f"      {attr}: {val}")
                    update_stream_node(stream_name, node, attr, val)

    write_pbs_script("test_base", "02:00:00", 1, 16, "job_script.pbs")
    job_id = submit_and_check_pbs_job("job_script.pbs")
    monitor_job(job_id)

    os.chdir('..')

    if 'restart' in case:
        compare_netcdf_files("base/restart.0000-01-01_02.00.00.nc", f"{case}/restart.0000-01-01_02.00.00.nc")


def main():
    
    yaml_file = '.ci/tests/exp.yaml'
    # Read the YAML file
    with open(yaml_file, 'r') as file:
        data = yaml.safe_load(file)
    
    create_directory('test')
    os.chdir('test')

    # Loop through tests and steps in each test
    for test in data.get('tests', []):
        inputs = test.get('inputs', {})
        steps = test.get('steps', {})
        for step_name, step_content in steps.items():
            run_exp(step_name, step_content, inputs)
    


if __name__ == "__main__":
    main()
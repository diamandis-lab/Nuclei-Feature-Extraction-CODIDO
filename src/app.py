import os
import argparse
import subprocess

import zipfile
import glob
import boto3

import time
import psutil
from pathlib import Path
from run_hover_net import run_hover_net
from get_mask import generate_mask

img_formats = ['jpg', 'png', 'tiff']


def prepare_codido_input(args,input_folder_path):

    if args.codido == 'True':
        
        s3 = boto3.client('s3')

        # downloads codido input file into the folder specified by input_folder_path
        input_file_path = os.path.join(input_folder_path, args.input.split('_SPLIT_')[-1])
        s3.download_file(os.environ['S3_BUCKET'], args.input, input_file_path)

        file = glob.glob(os.path.join(input_folder_path, '*'))[0]
        print(f"File name is ${file}", Path(file).suffix[1:])
        if Path(file).suffix[1:] == "zip":
            with zipfile.ZipFile(input_file_path, 'r') as zip_ref:
                zip_ref.extractall(input_folder_path)
            os.remove(input_file_path) # remove the zip file

    return True

def prepare_codido_output(args,output_folder_path):
    if args.codido == 'True':
    # create zip with all the saved outputs
        s3 = boto3.client('s3')

        zip_name = output_folder_path + '.zip'
        with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
            for folder_name, subfolders, filenames in os.walk(output_folder_path):
                for filename in filenames:
                    file_path = os.path.join(folder_name, filename)
                    zip_ref.write(file_path, arcname=os.path.relpath(file_path, output_folder_path))

        # upload
        s3.upload_file(zip_name, os.environ['S3_BUCKET'], args.output)

    raise SystemExit

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", help="input file will be downloaded from AWS")
    parser.add_argument("--output", help="output will be upload from AWS to ")
    parser.add_argument("--codido", help="running on codido", default= 'False')

    args = parser.parse_args()

    input_folder_path = os.path.join(os.sep, 'app/src', 'inputs')
    output_folder_path = os.path.join(os.sep, 'app/src', 'outputs')
    mask_folder_path = os.path.join(os.sep, 'app/src/outputs', 'mask')
    temp_folder_path = os.path.join(os.sep, 'app/src', 'temp')

    os.makedirs(input_folder_path, exist_ok=True)
    os.makedirs(output_folder_path, exist_ok=True)
    os.makedirs(temp_folder_path, exist_ok=True)
    os.makedirs(mask_folder_path, exist_ok=True)

    if(prepare_codido_input(args,input_folder_path)):

        pid = os.getpid()
        p = psutil.Process(pid)
        info_start = p.memory_full_info().uss/1024/1024
        start_time = time.time()

        # Run hover net
        run_hover_net()

        input_files_path = glob.glob(os.path.join(input_folder_path, '*'))
        for file in input_files_path:
            if (Path(file).suffix[1:] in (img_formats)):
                # Generate masks for all image 
                generate_mask(file)

        subprocess.run(["cellprofiler", "-c", "-r", "-p", "pipeline_v2.cppipe", "-i", "temp", "-o", "outputs"])

        over_time = time.time()
        info_end = p.memory_full_info().uss/1024/1024
        total_time = over_time - start_time
        

        prepare_codido_output(args,output_folder_path)

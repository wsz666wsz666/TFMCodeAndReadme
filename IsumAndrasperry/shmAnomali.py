#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on July 2024
@author: Dr. Guillermo Azuara and shengzhu wu
"""

import subprocess
import time
import os
import signal
import shutil
import numpy as np
import socket

def run_command():
    """Run the specified command to initiate ISUM test."""
    command = ['./shm_project', '-x', 'shm.xclbin', '-t', 'simple', '-b', '1', '-P', 'tests_iot', '-C', '1'] # Simple test command
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print("Output:", result.stdout.decode())
        print("Errors:", result.stderr.decode())
    except subprocess.CalledProcessError as e:
        print("The command failed with the following error:", e.stderr.decode())

def clean_directory(directory='./tests_iot'):
    """Clean the specified directory by removing all its contents."""
    if os.path.exists(directory):
        shutil.rmtree(directory)
    os.makedirs(directory)

def manage_files(directory='./tests_iot'):
    """Ensure the directory contains no more than two files by deleting the oldest ones."""
    files = sorted(os.listdir(directory), key=lambda x: os.path.getctime(os.path.join(directory, x)))
    while len(files) > 2:
        os.remove(os.path.join(directory, files.pop(0)))

def read_and_reshape(file_path):
    """Read binary data from the file and reshape it to the desired dimensions."""
    with open(file_path, 'rb') as file:
        content = file.read()
        data = np.frombuffer(content, dtype=np.int16)
        data = data.reshape((8, 16384))
    return data

def load_isum_files(folder_path):
    """Load the most recent and the second most recent ISUM files from the specified folder."""
    files = [f for f in os.listdir(folder_path) if f.endswith('.bin')]
    if len(files) < 2:
        raise ValueError("La carpeta debe contener al menos dos archivos .bin")

    files = sorted(files, key=lambda x: os.path.getctime(os.path.join(folder_path, x)))
    file_new = os.path.join(folder_path, files[-1])  # Assume the most recent file is the last
    file_old = os.path.join(folder_path, files[-2])  # Assume the second most recent file is the second last

    data_new = read_and_reshape(file_new)
    data_old = read_and_reshape(file_old)

    return data_new, data_old, file_new, file_old

def signal_handler(sig, frame):
    """Handle the signal interrupt to clean up and exit the program."""
    print('Cleaning up and exiting...')
    clean_directory()
    exit(0)

def calculate_statistics(data):
    """Calculate and return statistical metrics for the given data."""
    stats = {
        'Mean': np.mean(data),
        'Median': np.median(data),
        'Std Dev': np.std(data),
        'Variance': np.var(data)
    }
    return stats

def compute_statistics(data_new, data_old):
    """Compute and return statistics for new and old data."""
    stats = {
        'New File': {
            'Channel 1': calculate_statistics(data_new[0]),
            'Channel 2': calculate_statistics(data_new[1])
        },
        'Old File': {
            'Channel 1': calculate_statistics(data_old[0]),
            'Channel 2': calculate_statistics(data_old[1])
        }
    }
    return stats

def compare_statistics(stats):
    """Compare and return differences in statistics between new and old data."""
    differences = {'Channel 1': {}, 'Channel 2': {}}
    for channel in ['Channel 1', 'Channel 2']:
        for metric in ['Mean', 'Median', 'Std Dev', 'Variance']:
            new_value = stats['New File'][channel][metric]
            old_value = stats['Old File'][channel][metric]
            if new_value != old_value:
                differences[channel][metric] = (old_value, new_value)
    return differences

def perform_fft(data):
    """Perform FFT on the data and return the frequencies and amplitudes."""
    N = data.shape[0]
    fft_data = np.fft.fft(data)
    fft_freq = np.fft.fftfreq(N)
    return fft_freq, np.abs(fft_data)

def compare_fft(data_new, data_old):
    """Compare FFT results between new and old data."""
    differences = {'Channel 1': {}, 'Channel 2': {}}
    for idx, channel in enumerate(['Channel 1', 'Channel 2']):
        new_freq, new_ampl = perform_fft(data_new[idx])
        old_freq, old_ampl = perform_fft(data_old[idx])
        
        differences[channel] = {
            'New Frequency': new_freq,
            'New Amplitude': new_ampl,
            'Old Frequency': old_freq,
            'Old Amplitude': old_ampl
        }
    return differences

def detect_anomalies(stats):
    """Detect anomalies in the data based on statistical thresholds."""
    anomalies = {'Channel 1': {}, 'Channel 2': {}}
    for channel in ['Channel 1', 'Channel 2']:
        mean_new = stats['New File'][channel]['Mean']
        std_dev_new = stats['New File'][channel]['Std Dev']
        mean_old = stats['Old File'][channel]['Mean']
        std_dev_old = stats['Old File'][channel]['Std Dev']

        # Detect significant deviations in mean and std deviation
        if abs(mean_new - mean_old) > 2 * std_dev_old:
            anomalies[channel]['Mean'] = (mean_old, mean_new)
        if abs(std_dev_new - std_dev_old) > 2 * std_dev_old:
            anomalies[channel]['Std Dev'] = (std_dev_old, std_dev_new)

        # Add more checks for other statistics if necessary
        for metric in ['Median', 'Variance']:
            new_value = stats['New File'][channel][metric]
            old_value = stats['Old File'][channel][metric]
            if abs(new_value - old_value) > 2 * std_dev_old:
                anomalies[channel][metric] = (old_value, new_value)

    return anomalies

def start_server():
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind(('0.0.0.0', 12345))  # Escucha en todas las interfaces, puerto 12345
    server_socket.listen(1)
    print('Servidor esperando conexiones...')

    conn, addr = server_socket.accept()
    print(f'Conexion establecida con {addr}')

    signal.signal(signal.SIGINT, signal_handler)
    
    counter = 0
    clean_directory()  # Ensure the directory is clean before starting
    
    previous_new_stats = None  # Variable to store stats of new file for comparison

    while True:
        counter += 1
        run_command()
        print(f'Test #{counter} done!!')
        manage_files()
        
        # Load the ISUM data files
        try:
            data_new, data_old, file_new, file_old = load_isum_files('./tests_iot')
            print(f"Datos cargados de: {file_new} y {file_old}")
            print(f"Forma de los datos nuevos: {data_new.shape}")
            print(f"Forma de los datos antiguos: {data_old.shape}")
            
            # Calculate and display statistical metrics
            stats = compute_statistics(data_new, data_old)
            for file_key, channels in stats.items():
                print(f"\n{file_key}:")
                for channel_key, metrics in channels.items():
                    print(f"  {channel_key}:")
                    for metric, value in metrics.items():
                        print(f"    {metric}: {value}")

            # Compare statistics and display significant differences
            differences = compare_statistics(stats)
            for channel, metrics in differences.items():
                print(f"\nDiferencias significativas en {channel}:")
                for metric, values in metrics.items():
                    old_value, new_value = values
                    print(f"  {metric}: Old = {old_value}, New = {new_value}")

            # Perform and compare frequency analysis
            fft_differences = compare_fft(data_new, data_old)
            for channel, metrics in fft_differences.items():
                print(f"\nComponentes frecuenciales en {channel}:")
                print(f"  New Frequencies: {metrics['New Frequency']}")
                print(f"  New Amplitudes: {metrics['New Amplitude']}")
                print(f"  Old Frequencies: {metrics['Old Frequency']}")
                print(f"  Old Amplitudes: {metrics['Old Amplitude']}")

            # Detect anomalies based on thresholds
            anomalies = detect_anomalies(stats)
            anomalies_detected = False
            for channel, metrics in anomalies.items():
                if metrics:
                    anomalies_detected = True
                    print(f"\nAnomalias en {channel}:")
                    for metric, values in metrics.items():
                        old_value, new_value = values
                        print(f"  {metric}: Old = {old_value}, New = {new_value} (fuera del rango)")
            
            # Enviar estadísticas y diferencias al cliente
            conn.sendall(f"Stats: {stats}\nDifferences: {differences}\n".encode())

            # Enviar anomalías si se detectan
            if anomalies_detected:
                conn.sendall(f"Anomalies: {anomalies}\n".encode())

            # Verify that the old file statistics match the new file statistics from the previous round
            if previous_new_stats:
                for channel_key, new_metrics in previous_new_stats.items():
                    old_metrics = stats['Old File'][channel_key]
                    for metric in new_metrics:
                        if old_metrics[metric] != new_metrics[metric]:
                            print(f"Anomaly detected in {metric} of {channel_key}: {old_metrics[metric]} != {new_metrics[metric]}")
            
            # Save the new file statistics for the next comparison
            previous_new_stats = stats['New File']
                        
        except ValueError as e:
            print(e)
        
        time.sleep(10)




if __name__ == '__main__':
    start_server()

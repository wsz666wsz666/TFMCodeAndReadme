This folder contains two MATLAB scripts, umbral.m and shm.m, designed for processing and analyzing signals obtained from structures with and without damage. Both scripts work with binary files (.bin) containing multiple data channels and apply various preprocessing, filtering, frequency analysis, and signal classification techniques.
Included Files
1. umbral.m
Functionality:

Determines a threshold to classify signals into two categories:
Class A: Signals from healthy structures.
Class B: Signals from damaged structures.
Applies preprocessing and filtering to the signals.
Computes the Fast Fourier Transform (FFT) and obtains magnitude spectra.
Estimates the correlation between signals within the same class and between different classes.
Calculates the correlation difference between classes and defines an optimal threshold based on two methods:
Mean averaging.
Minimization of classification error.
2. shm.m
Functionality:

Structural analysis of signals obtained from two data sets.
Classification of new signals based on spectral similarities.
Calculation of time-domain statistics.
Comparison of correlation in both time and frequency domains.
Application of a band-pass filter (10-100 Hz) to evaluate energy in the frequency domain.
Generation of reports and visualization of results.
System Requirements
Software: MATLAB R2020a or later.

Utilizes standard MATLAB functions.
Expected Folder Structure:
C:\nodamage\ → Binary files of healthy structures.
C:\damage\ → Binary files of damaged structures.
C:\2023-2024\s1\ → Binary files of new signals to classify.


Note: These are two simple scripts for calculating threshold values for different variables. It is only necessary to add the desired values within the threshold determination function.
%% SHM Analysis: Análisis y Clasificación de Señales SHM a partir de Archivos .bin
% Este script procesa señales de 8 canales (se extrae el Canal 1) de dos clases:
%   - Clase A: Estructuras saludables.
%   - Clase B: Estructuras posiblemente dañadas.
%
% Se realizan las siguientes tareas:
%  1. Lectura de archivos de dos carpetas.
%  2. Preprocesamiento: eliminación del 5% de muestras al inicio y final.
%  3. Filtrado con un filtro Butterworth para eliminar ruido de baja y alta frecuencia.
%  4. Cálculo de estadísticas en el dominio del tiempo.
%  5. Cálculo de la FFT y graficación del espectro.
%  6. Comparación entre señales (correlación en tiempo y frecuencia).
%  7. Clasificación de nuevas señales según similitud espectral.
%  8. Aplicación de un filtro pasa banda (10-100 Hz) para comparar energía.
%  9. Generación de reportes y visualización de resultados.

%% Inicialización
clear; clc; close all;

% Parámetros generales
fs = 1000;                   % Frecuencia de muestreo (Hz)
numChannels = 8;             % Número total de canales en los archivos
channelToAnalyze = 1;        % Canal a extraer (se usa el Canal 1)
removePercent = 0.05;        % Porcentaje de muestras a eliminar al inicio y final

% Parámetros del filtro Butterworth para preprocesamiento (ajustables)
lowCut_preproc = 0.5;        % Frecuencia de corte baja (Hz)
highCut_preproc = 200;       % Frecuencia de corte alta (Hz)

% Parámetros para el filtro de diferencias (Paso 8: pasa banda 10-100 Hz)
lowCut_band = 10;            % Frecuencia de corte baja para filtro de energía
highCut_band = 100;          % Frecuencia de corte alta para filtro de energía

% Rutas de las carpetas (modificar según corresponda)
folderA   = 'C:\nodamage';      % Carpeta con señales de Clase A
folderB   = 'C:\damage';      % Carpeta con señales de Clase B
folderNew = 'C:\2023-2024\s1';   % Carpeta con señales a clasificar

%% 1️⃣ Lectura de Archivos de Carpeta A y Carpeta B
signalsA = readSignalsFromFolder(folderA, numChannels, channelToAnalyze);
signalsB = readSignalsFromFolder(folderB, numChannels, channelToAnalyze);

%% 2️⃣ Preprocesamiento y 3️⃣ Filtrado de las Señales
% Para cada archivo se elimina el 5% inicial y final y se filtra la señal.
for i = 1:length(signalsA)
    signal = signalsA{i};
    % Eliminar 5% de las muestras al inicio y final
    signal = preprocessSignal(signal, removePercent);
    % Aplicar filtro Butterworth para eliminar ruido
    signalsA{i} = butterworthFilter(signal, fs, lowCut_preproc, highCut_preproc);
end

for i = 1:length(signalsB)
    signal = signalsB{i};
    signal = preprocessSignal(signal, removePercent);
    signalsB{i} = butterworthFilter(signal, fs, lowCut_preproc, highCut_preproc);
end

%% 4️⃣ Análisis en el Dominio del Tiempo: Cálculo de Estadísticas
disp('--- Estadísticas para Señales de Clase A ---');
statsA = cell(length(signalsA),1);
for i = 1:length(signalsA)
    statsA{i} = analyzeSignal(signalsA{i});
    disp(['Archivo Clase A ', num2str(i), ':']);
    disp(statsA{i});
end

disp('--- Estadísticas para Señales de Clase B ---');
statsB = cell(length(signalsB),1);
for i = 1:length(signalsB)
    statsB{i} = analyzeSignal(signalsB{i});
    disp(['Archivo Clase B ', num2str(i), ':']);
    disp(statsB{i});
end

%% 5️⃣ Transformada de Fourier (FFT) y Visualización del Espectro
% Graficar el espectro para cada archivo de Clase A
figure('Name','Espectro FFT - Clase A');
for i = 1:length(signalsA)
    subplot(2,ceil(length(signalsA)/2),i);
    [freq, spectrum] = computeFFT(signalsA{i}, fs);
    plot(freq, abs(spectrum));
    title(['Clase A - Archivo ', num2str(i)]);
    xlabel('Frecuencia (Hz)'); ylabel('Magnitud');
end

% Graficar el espectro para cada archivo de Clase B
figure('Name','Espectro FFT - Clase B');
for i = 1:length(signalsB)
    subplot(2,ceil(length(signalsB)/2),i);
    [freq, spectrum] = computeFFT(signalsB{i}, fs);
    plot(freq, abs(spectrum));
    title(['Clase B - Archivo ', num2str(i)]);
    xlabel('Frecuencia (Hz)'); ylabel('Magnitud');
end

%% 6️⃣ Comparación de Señales (Correlación en Tiempo y Frecuencia)
% Se construyen matrices de correlación entre cada señal de Clase A y Clase B.
correlationMatrixTime = zeros(length(signalsA), length(signalsB));
correlationMatrixFreq = zeros(length(signalsA), length(signalsB));

for i = 1:length(signalsA)
    for j = 1:length(signalsB)
        % Correlación en el dominio del tiempo (coeficiente de correlación)
        corrTime = corrcoef(signalsA{i}, signalsB{j});
        correlationMatrixTime(i,j) = corrTime(1,2);
        
        % Correlación en el dominio de la frecuencia (usando la magnitud del FFT)
        [~, spectrumA] = computeFFT(signalsA{i}, fs);
        [~, spectrumB] = computeFFT(signalsB{j}, fs);
        specA = abs(spectrumA);
        specB = abs(spectrumB);
        corrFreq = corrcoef(specA, specB);
        correlationMatrixFreq(i,j) = corrFreq(1,2);
    end
end

disp('Matriz de Correlación en Dominio del Tiempo (Clase A vs. Clase B):');
disp(correlationMatrixTime);
disp('Matriz de Correlación en Dominio de la Frecuencia (Clase A vs. Clase B):');
disp(correlationMatrixFreq);

%% 7️⃣ Clasificación de Nuevas Señales
% Se compara la nueva señal con las señales de Clase A y B usando correlación espectral.
newFiles = dir(fullfile(folderNew, '*.bin'));
classificationResults = cell(length(newFiles),1);

for i = 1:length(newFiles)
    % Leer la nueva señal
    filePath = fullfile(folderNew, newFiles(i).name);
    newSignal = readBinaryFile(filePath, numChannels, channelToAnalyze);
    newSignal = preprocessSignal(newSignal, removePercent);
    newSignal = butterworthFilter(newSignal, fs, lowCut_preproc, highCut_preproc);
    
    % Calcular FFT de la nueva señal
    [~, spectrumNew] = computeFFT(newSignal, fs);
    specNew = abs(spectrumNew);
    
    % Calcular correlación espectral con señales de Clase A y B
    corrA = zeros(length(signalsA),1);
    corrB = zeros(length(signalsB),1);
    for k = 1:length(signalsA)
        [~, specA] = computeFFT(signalsA{k}, fs);
        corrTemp = corrcoef(specNew, abs(specA));
        corrA(k) = corrTemp(1,2);
    end
    for k = 1:length(signalsB)
        [~, specB] = computeFFT(signalsB{k}, fs);
        corrTemp = corrcoef(specNew, abs(specB));
        corrB(k) = corrTemp(1,2);
    end
    
    meanCorrA = mean(corrA);
    meanCorrB = mean(corrB);
    
    if meanCorrA > meanCorrB
        classification = 'Clase A';
    else
        classification = 'Clase B';
    end
    
    classificationResults{i} = {newFiles(i).name, classification, meanCorrA, meanCorrB};
    disp(['Archivo ', newFiles(i).name, ' clasificado como ', classification]);
end

%% 8️⃣ Filtro de Diferencias: Análisis de Energía en Banda (10-100 Hz)
energyA = zeros(length(signalsA),1);
for i = 1:length(signalsA)
    energyA(i) = bandEnergy(signalsA{i}, fs, lowCut_band, highCut_band);
end

energyB = zeros(length(signalsB),1);
for i = 1:length(signalsB)
    energyB(i) = bandEnergy(signalsB{i}, fs, lowCut_band, highCut_band);
end

disp('Energía en banda 10-100 Hz:');
disp('Clase A:');
disp(energyA);
disp('Clase B:');
disp(energyB);

%% 9️⃣ Generación de Reportes y Visualización
% Guardar los resultados de clasificación en un archivo CSV.
resultTable = cell2table(vertcat(classificationResults{:}), 'VariableNames', {'Archivo', 'Clasificacion', 'CorrClaseA', 'CorrClaseB'});


% Visualización adicional: Comparar el espectro promedio de cada clase
avgFFT_A = zeros(length(freq),1);
for i = 1:length(signalsA)
    [freq, spectrumA] = computeFFT(signalsA{i}, fs);
    avgFFT_A = avgFFT_A + abs(spectrumA(:));
end
avgFFT_A = avgFFT_A / length(signalsA);

avgFFT_B = zeros(length(freq),1);
for i = 1:length(signalsB)
    [freq, spectrumB] = computeFFT(signalsB{i}, fs);
    avgFFT_B = avgFFT_B + abs(spectrumB(:));
end
avgFFT_B = avgFFT_B / length(signalsB);

figure('Name','Espectro Promedio Comparado');
plot(freq, avgFFT_A, 'b', 'LineWidth',1.5); hold on;
plot(freq, avgFFT_B, 'r', 'LineWidth',1.5);
xlabel('Frecuencia (Hz)'); ylabel('Magnitud Promedio');
legend('Clase A','Clase B');
title('Comparación del Espectro Promedio entre Clases');
grid on;

%% Funciones Auxiliares

function signals = readSignalsFromFolder(folderPath, numChannels, channelToExtract)
    % Lee todos los archivos .bin de la carpeta y extrae el canal indicado.
    files = dir(fullfile(folderPath, '*.bin'));
    signals = cell(length(files),1);
    for i = 1:length(files)
        filePath = fullfile(folderPath, files(i).name);
        signals{i} = readBinaryFile(filePath, numChannels, channelToExtract);
    end
end

function signal = readBinaryFile(filePath, numChannels, channelToExtract)
    % Abre y lee un archivo binario .bin, convierte los datos a int16 y extrae el canal deseado.
    fid = fopen(filePath, 'rb');
    if fid == -1
        error(['No se pudo abrir el archivo: ', filePath]);
    end
    data = fread(fid, 'int16');
    fclose(fid);
    
    % Determinar el número de muestras (se asume que los datos están intercalados)
    numSamples = floor(length(data) / numChannels);
    data = data(1:numSamples*numChannels); % Asegurar que la longitud es múltiplo de numChannels
    data = reshape(data, numChannels, numSamples);
    
    % Extraer el canal indicado y convertir a double para facilitar el procesamiento y la visualización
    fullSignal = double(data(channelToExtract, :));
    
    % Calcular la cantidad de muestras que corresponden al 25%
    numSamples25 = floor(length(fullSignal) * 0.25);
    
    %% Opción 1: Extraer el primer 25% de las muestras
    signal = fullSignal(1:numSamples25);
end

function processedSignal = preprocessSignal(signal, removePercent)
    % Elimina el 5% de las muestras al inicio y al final de la señal.
    N = length(signal);
    removeSamples = floor(N * removePercent);
    processedSignal = signal(removeSamples+1 : end-removeSamples);
end

function filteredSignal = butterworthFilter(signal, fs, lowCut, highCut)
    % Aplica un filtro Butterworth pasa banda para eliminar ruido de baja y alta frecuencia.
    nyq = fs/2;
    Wn = [lowCut highCut] / nyq;  % Frecuencias normalizadas
    order = 4;  % Orden del filtro
    [b,a] = butter(order, Wn, 'bandpass');
    filteredSignal = filtfilt(b, a, signal);
end

function stats = analyzeSignal(signal)
    % Calcula estadísticas básicas en el dominio del tiempo.
    stats.mean   = mean(signal);
    stats.std    = std(signal);
    stats.min    = min(signal);
    stats.max    = max(signal);
    stats.energy = sum(signal.^2);
end

function [freq, spectrum] = computeFFT(signal, fs)
    % Calcula la FFT de la señal y retorna el vector de frecuencias y el espectro.
    N = length(signal);
    spectrum = fft(signal);
    freq = (0:N-1)*(fs/N);
    % Opcional: para graficar solo la parte positiva del espectro, descomentar:
    % halfN = ceil(N/2);
    % freq = freq(1:halfN);
    % spectrum = spectrum(1:halfN);
end

function energy = bandEnergy(signal, fs, lowCut, highCut)
    % Calcula la energía de la señal en una banda de frecuencia dada aplicando un filtro.
    filtered = butterworthFilter(signal, fs, lowCut, highCut);
    energy = sum(filtered.^2);
end

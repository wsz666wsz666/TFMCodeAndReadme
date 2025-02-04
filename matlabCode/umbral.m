%% Script para Determinar el Umbral a partir de Datos Etiquetados
% Se asume que:
% - Las señales de Clase A (saludables) están en folderA.
% - Las señales de Clase B (dañadas) están en folderB.
% - Cada archivo es .bin con 8 canales; se extrae el Canal 1 y solo los 2 señales.
% - Se realizan preprocesamiento (eliminación del 5% de muestras al inicio y final)
%   y filtrado con un Butterworth (0.5 a 200 Hz).

clear; clc; close all;

%% 1. Parámetros Generales y de Filtro
fs = 1000;                   % Frecuencia de muestreo (Hz)
numChannels = 8;             % Número de canales en cada archivo
channelToAnalyze = 1;        % Canal a extraer
removePercent = 0.05;        % Porcentaje de muestras a eliminar (inicio y final)

% Parámetros del filtro Butterworth para preprocesamiento
lowCut_preproc = 0.5;        % Frecuencia de corte baja (Hz)
highCut_preproc = 200;       % Frecuencia de corte alta (Hz)

%% 2. Rutas de las Carpetas (modifica según tu estructura)
folderA = 'C:\nodamage';     % Carpeta para Clase A (saludable)
folderB = 'C:\damage';       % Carpeta para Clase B (dañada)

%% 3. Lectura de Señales y Preprocesamiento
% Se leen y preprocesan (eliminación de extremos y filtrado) las señales de cada carpeta.
signalsA = readSignalsFromFolder(folderA, numChannels, channelToAnalyze);
signalsB = readSignalsFromFolder(folderB, numChannels, channelToAnalyze);

% Preprocesamiento y filtrado para Clase A:
for i = 1:length(signalsA)
    s = preprocessSignal(signalsA{i}, removePercent);
    signalsA{i} = butterworthFilter(s, fs, lowCut_preproc, highCut_preproc);
end

% Preprocesamiento y filtrado para Clase B:
for i = 1:length(signalsB)
    s = preprocessSignal(signalsB{i}, removePercent);
    signalsB{i} = butterworthFilter(s, fs, lowCut_preproc, highCut_preproc);
end

%% 4. Cálculo de la FFT y Almacenamiento de las Magnitudes
% Para cada señal se calcula la FFT y se guarda la magnitud.
magA = cell(length(signalsA), 1);
for i = 1:length(signalsA)
    [freq, spectrum] = computeFFT(signalsA{i}, fs);
    magA{i} = abs(spectrum);
end

magB = cell(length(signalsB), 1);
for i = 1:length(signalsB)
    [~, spectrum] = computeFFT(signalsB{i}, fs);
    magB{i} = abs(spectrum);
end

%% 5. Cálculo del Valor "diff" para Cada Señal
% Para cada señal en Clase A, se calcula:
%   - meanCorr_same: correlación promedio con las demás señales de Clase A.
%   - meanCorr_other: correlación promedio con todas las señales de Clase B.
% Y se define: diff = meanCorr_same - meanCorr_other.
diffA = zeros(length(signalsA), 1);
for i = 1:length(signalsA)
    % Correlación con otras señales de Clase A (excluyendo la misma señal)
    corr_same = [];
    for j = 1:length(signalsA)
        if j ~= i
            R = corrcoef(magA{i}, magA{j});
            corr_same(end+1) = R(1,2);
        end
    end
    meanCorr_same = mean(corr_same);
    
    % Correlación con señales de Clase B
    corr_other = zeros(length(signalsB),1);
    for j = 1:length(signalsB)
        R = corrcoef(magA{i}, magB{j});
        corr_other(j) = R(1,2);
    end
    meanCorr_other = mean(corr_other);
    
    diffA(i) = meanCorr_same - meanCorr_other;
end

% Para cada señal en Clase B, se calcula:
%   - meanCorr_other: correlación promedio con las señales de Clase A.
%   - meanCorr_same: correlación promedio con las demás señales de Clase B.
% Y se define: diff = meanCorr_other - meanCorr_same.
diffB = zeros(length(signalsB), 1);
for i = 1:length(signalsB)
    % Correlación con señales de Clase A
    corr_other = zeros(length(signalsA),1);
    for j = 1:length(signalsA)
        R = corrcoef(magB{i}, magA{j});
        corr_other(j) = R(1,2);
    end
    meanCorr_other = mean(corr_other);
    
    % Correlación con otras señales de Clase B (excluyendo la misma señal)
    corr_same = [];
    for j = 1:length(signalsB)
        if j ~= i
            R = corrcoef(magB{i}, magB{j});
            corr_same(end+1) = R(1,2);
        end
    end
    meanCorr_same = mean(corr_same);
    
    diffB(i) = meanCorr_other - meanCorr_same;
end

%% 6. Combinación de Valores "diff" y Etiquetado
% Se asigna etiqueta 1 para Clase A y 0 para Clase B.
diffAll = [diffA; diffB];
labels = [ones(length(diffA),1); zeros(length(diffB),1)];

%% 7. Determinación del Umbral
% Se aplican dos métodos para estimar el umbral.

% Método 1: Umbral como Promedio de las Medias de diff para cada clase.
meanDiff_A = mean(diffA);
meanDiff_B = mean(diffB);
threshold_avg = (meanDiff_A + meanDiff_B) / 2;
fprintf('Umbral (método promedio): %.4f\n', threshold_avg);

% Método 2: Selección del umbral que minimice el error de clasificación
candidateThresholds = sort(unique(diffAll));
minError = Inf;
bestThreshold = candidateThresholds(1);
for t = candidateThresholds'
    % Se clasifica: si diff > t se asigna Clase A (1), sino Clase B (0)
    predictions = diffAll > t;
    error = sum(predictions ~= labels);
    if error < minError
        minError = error;
        bestThreshold = t;
    end
end
fprintf('Umbral (minimización de error): %.4f, con %d errores de %d muestras\n', ...
    bestThreshold, minError, length(labels));

%% 8. Visualización de la Distribución de "diff"
figure;
histogram(diffA, 'FaceColor','b', 'FaceAlpha',0.5);
hold on;
histogram(diffB, 'FaceColor','r', 'FaceAlpha',0.5);
xlabel('Valor diff (meanCorr_{same} - meanCorr_{other})');
ylabel('Número de señales');
legend('Clase A (Saludable)','Clase B (Dañada)');
title('Distribución de los valores diff para cada clase');
grid on;

%% Funciones Auxiliares
% Se asume que ya dispones de estas funciones (defínelas en archivos separados
% o al final de este script):

% --- Función: readSignalsFromFolder ---
function signals = readSignalsFromFolder(folderPath, numChannels, channelToExtract)
    % Lee todos los archivos .bin de la carpeta y extrae el canal indicado.
    files = dir(fullfile(folderPath, '*.bin'));
    signals = cell(length(files),1);
    for i = 1:length(files)
        filePath = fullfile(folderPath, files(i).name);
        signals{i} = readBinaryFile(filePath, numChannels, channelToExtract);
    end
end

% --- Función: readBinaryFile ---
function signal = readBinaryFile(filePath, numChannels, channelToExtract)
    % Abre y lee un archivo binario .bin, convierte los datos a int16 y extrae el canal.
    fid = fopen(filePath, 'rb');
    if fid == -1
        error(['No se pudo abrir el archivo: ', filePath]);
    end
    data = fread(fid, 'int16');
    fclose(fid);
    
    % Asegura que la longitud sea múltiplo de numChannels y reorganiza los datos
    numSamples = floor(length(data) / numChannels);
    data = data(1:numSamples*numChannels);
    data = reshape(data, numChannels, numSamples);
    
    % Extrae el canal y lo convierte a double
    fullSignal = double(data(channelToExtract, :));
    
    % Opcional: se puede elegir extraer solo una parte (por ejemplo, el primer 25%)
    numSamples25 = floor(length(fullSignal) * 0.25);
    signal = fullSignal(1:numSamples25);
end

% --- Función: preprocessSignal ---
function processedSignal = preprocessSignal(signal, removePercent)
    % Elimina el porcentaje de muestras indicado al inicio y al final.
    N = length(signal);
    removeSamples = floor(N * removePercent);
    processedSignal = signal(removeSamples+1:end-removeSamples);
end

% --- Función: butterworthFilter ---
function filteredSignal = butterworthFilter(signal, fs, lowCut, highCut)
    % Aplica un filtro Butterworth pasa banda.
    nyq = fs / 2;
    Wn = [lowCut highCut] / nyq;
    order = 4;
    [b, a] = butter(order, Wn, 'bandpass');
    filteredSignal = filtfilt(b, a, signal);
end

% --- Función: computeFFT ---
function [freq, spectrum] = computeFFT(signal, fs)
    % Calcula la FFT de la señal.
    N = length(signal);
    spectrum = fft(signal);
    freq = (0:N-1) * (fs / N);
end

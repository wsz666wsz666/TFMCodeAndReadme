
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import ast

def fetch_isum_data(host: str, port: int, buffer_size: int = 4096) -> dict:
    

    # Diccionario donde guardamos lo que llegue del servidor
    result = {
        'Stats': None,
        'Differences': None,
        'Anomalies': None
    }

    # 1) Crear socket y conectar
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client_socket.connect((host, port))

    # 2) Recibir datos hasta que el servidor cierre la conexion
    data_buffer = ""
    while True:
        chunk = client_socket.recv(buffer_size)
        if not chunk:
            # Si no hay mas datos, el servidor cerro la conexion
            break
        data_buffer += chunk.decode()

    client_socket.close()

   
    lines = data_buffer.split('\n')

    for line in lines:
        line = line.strip()
        if not line:
            continue 

        # Verificamos que tipo de mensaje es
        if line.startswith("Stats:"):
            dict_str = line[len("Stats:"):].strip()  # extraemos el texto
            try:
                result['Stats'] = ast.literal_eval(dict_str)
            except:
                result['Stats'] = None  # Si falla el parseo

        elif line.startswith("Differences:"):
            dict_str = line[len("Differences:"):].strip()
            try:
                result['Differences'] = ast.literal_eval(dict_str)
            except:
                result['Differences'] = None

        elif line.startswith("Anomalies:"):
            dict_str = line[len("Anomalies:"):].strip()
            try:
                result['Anomalies'] = ast.literal_eval(dict_str)
            except:
                result['Anomalies'] = None

        else:
            # Si llega otra linea no reconocida, la imprimimos o la ignoramos
            print(f"[INFO] Linea desconocida recibida: {line}")

    return result

def main():
    # Ajusta estos valores a la IP y puerto de tu servidor
    host = "192.168.10.91"
    port = 12345

    print(f"Conectando a servidor {host}:{port} ...")
    data = fetch_isum_data(host, port)

    print("\n--- Datos Recibidos en Diccionario ---")
    print("Stats:", data['Stats'])
    print("Differences:", data['Differences'])
    print("Anomalies:", data['Anomalies'])
    print("--------------------------------------")

    if 'Anomalies' in data and data['Anomalies'] is not None :
       print("Anomalies detect")
    else:
       print("no Anomalies detect")


if __name__ == '__main__':
    main()

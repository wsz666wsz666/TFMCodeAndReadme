#!/usr/bin/env python3
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import serial
import time
import random
from mqtt_send import MQTTClient
import threading
import shm_comunication

def calculate_checksum(data):
    """Calcula el checksum XOR de una secuencia de bytes."""
    checksum = 0
    for byte in data:
        checksum ^= byte
    return checksum

def data_mqtt(data , shm_data):
    broker = "192.168.100.23"
    port = 1883
    username = "lywsz"
    password = "992258"
    
    Alerta = data[0]
    Letter = chr(data[1])
    number = data[2]
    
    new_data= {
       "Alert" : Alerta,
       "position_letter": Letter,
       "position_number": number
    }
    
    client = MQTTClient(broker, port, username, password)
    client.connect()
    data2 = {"key": "value", "temperature": 20}
    final_data = new_data | data2 | shm_data
    
    client.publish("test/topic", final_data)
    client.disconnect()
    

    

def main():
    # Ajusta el puerto y la velocidad (baud rate) 
    # : /dev/ttyS0 a 115200
    ser = serial.Serial('/dev/ttyS0', 115200, timeout=1)

    print("Handshake with STM32: We wait for 0xAA and then send a number. Ctrl+C to exit.")
    

    try:
        while True:
            # 1) Esperar la seal 0xAA del STM32
            byte_in = ser.read(1)
            if len(byte_in) == 1:
                if byte_in[0] == 0xAA:
                    # El STM32 pide un numero
                    host = "192.168.10.91"
                    port = 12345
                    shm_data = shm_comunication.fetch_isum_data(host, port)
                    
                    if shm_data['Anomalies']:
                        print(" Anomalies detected!")
                        number = 1
                    else:
                        print(" No anomalies detected.")
                        number = 0
                   
                    #number = random.randint(1, 100) & 0xFF
                    position_letter = 0x41 + (random.randint(0, 25))
                    position_number = random.randint(0, 100) & 0xFF
                    
                    message = bytes([number, position_letter, position_number])
                    
                    checksum = calculate_checksum(message)
                    message_with_checksum = message + bytes([checksum])
                    
                    
                    ser.write(message_with_checksum)
                    print(f"Enviado: {number} {chr(position_letter)} {position_number} Checksum: {checksum:02X}")
                    data_mqtt(message,shm_data)

                   
                    resp = ser.read(2)
                    if len(resp) == 2 and resp[0]==0x06:
                        print("Confirmacion recibida: ACK (0x06)")
                        time.sleep(0.1)

                    elif len(resp) == 2 and resp[0]==0x06:
                        print("Confirmacion recibida: NACK (0x15), retransmitiendo...")
                        time.sleep(0.1)
                else:
                    # Recibi un byte que no es 0xAA (puede que sea basura o debug)
                    print(f"Recibi un byte inesperado: 0x{byte_in[0]:02X}")
                    time.sleep(0.1)
            else:
                # Timeout de 1s, no llego nada
                pass

            time.sleep(0.5)

    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
        print("Closing serial port.")

if __name__ == '__main__':
    main()

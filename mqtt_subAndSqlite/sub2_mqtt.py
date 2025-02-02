#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import paho.mqtt.client as mqtt
import sqlite3
import json

# Configuracin del broker MQTT
BROKER = "192.168.1.71" 
PORT = 1883  
TOPIC = "test/topic"  
USERNAME = "lywsz"  
PASSWORD = "992258"  

# Conexion a la base de datos SQLite
def init_db():
    conn = sqlite3.connect('Isum.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT NOT NULL,
            payload TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

#  SQLite
def save_to_db(topic, payload):
    conn = sqlite3.connect('Isum.db')
    cursor = conn.cursor()
    cursor.execute('INSERT INTO messages (topic, payload) VALUES (?, ?)', (topic, payload))
    conn.commit()
    conn.close()

#  broker
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Conectado al broker con exito")
        # Suscribirse
        client.subscribe(TOPIC)
        print(f"Suscrito al topico: {TOPIC}")
    else:
        print(f"Error al conectarse, codigo de error: {rc}")

#recibe un mensaje del broker
def on_message(client, userdata, msg):
    try:
        payload = msg.payload.decode('utf-8')
        print(f"Mensaje recibido en el topico {msg.topic}: {payload}")
        
        # Validar si el mensaje es JSON valido
        json_data = json.loads(payload)
        print("Datos JSON validos recibidos:", json_data)
        
        # Guardar en SQLite
        save_to_db(msg.topic, payload)
        print("Datos guardados en la base de datos.")
    except json.JSONDecodeError:
        print("Error: El mensaje recibido no es un JSON valido.")

# Crear una instancia del cliente MQTT
client = mqtt.Client()

# Configurar credenciales de autenticacin
client.username_pw_set(USERNAME, PASSWORD)

# Asignar funciones de callback
client.on_connect = on_connect
client.on_message = on_message

# Inicializar la base de datos
init_db()

# Conectar al broker
try:
    client.connect(BROKER, PORT, keepalive=60)
except Exception as e:
    print(f"No se pudo conectar al broker: {e}")
    exit(1)

# Mantener el cliente ejecutndose para escuchar los mensajes
try:
    print("Esperando mensajes... Presiona Ctrl+C para salir.")
    client.loop_forever()
except KeyboardInterrupt:
    print("Desconectandose del broker...")
    client.disconnect()
    print("Cliente desconectado.")

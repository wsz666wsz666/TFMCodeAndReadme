#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import paho.mqtt.client as mqtt
import json

class MQTTClient:
    def __init__(self, broker, port, username, password):
        
        self.broker = broker
        self.port = port
        self.username = username
        self.password = password

        # Create the MQTT client
        self.client = mqtt.Client()
        self.client.username_pw_set(self.username, self.password)

    def connect(self):
        """
        Connect to the MQTT broker.
        """
        try:
            self.client.connect(self.broker, self.port)
            print(f"Connected to the MQTT broker in {self.broker}:{self.port}")
        except Exception as e:
            print(f"Error connecting to MQTT broker: {e}")

    def publish(self, topic, message):
        
        try:
            if isinstance(message,dict):
               message = json.dumps(message)
            
            result = self.client.publish(topic, message)
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"Message posted to the topic '{topic}': {message}")
            else:
                print(f"Error al enviar el mensaje: {result.rc}")
        except Exception as e:
            print(f"Error sending message: {e}")

    def disconnect(self):
        
        self.client.disconnect()
        print("Disconnected from the MQTT broker")

# Ejemplo de uso (comentado para que la libreria no ejecute codigo directamente si es importada)
if __name__ == "__main__":
     broker = "192.168.1.71"
     port = 1883
     username = "lywsz"
     password = "992258"
     client = MQTTClient(broker, 1883, username, password)
     client.connect()
     data  = {"key": "value", "temperature": 22.5}
     client.publish("test/topic", data)
     client.disconnect()
    

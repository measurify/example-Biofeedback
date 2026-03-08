#define USE_ARDUINO_INTERRUPTS false
#include <PulseSensorPlayground.h>           // Libreria PulseSensorPlayground (dedicata al Pulse Sensor);

#ifndef PULSE_SENSOR_H  
#define PULSE_SENSOR_H  
#endif // PULSE_SENSOR_H     

/************************************************************
 *                  INCLUSIONI LIBRERIE
 ************************************************************/
#include <Arduino.h>                         // Inclusione funzioni di Arduino;
#include <PulseSensorPlayground.h>           // Libreria PulseSensorPlayground (dedicata al Pulse Sensor);
#include "config.h"                          // Inclusione file di configurazione progetto.


// Dichiarazione esterna dell'istanza globale definita in PulseSensor.cpp:
extern PulseSensorPlayground pulseSensor;    // Oggetto globale PulseSensor usato dal progetto.

// Funzione di inizializzazione del Pulse Sensor:
void initPulseSensor();

// Funzione di lettura del sensore:
bool readPulseSensor(int &signal, int &bpm, unsigned long &beatTime);  // Ritorna true se rilevato un nuovo battito e modifica le variabili in ingresso.

                 

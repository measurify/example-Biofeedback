#include "BLE.h"                                                     // Inclusione libreria personalizzata.

#ifdef USE_BLE 

// Servizi:                                                    
BLEService BLEManager::sensorService(SERVICE_UUID);

// Caratteristiche (float = 4 bytes):
#ifdef USE_PULSE_SENSOR
BLECharacteristic BLEManager::pulseChar(PULSE_UUID, BLERead | BLENotify, sizeof(float));        // Pulse Sensor;

BLECharacteristic BLEManager::bpmChar(BPM_UUID, BLERead | BLENotify, sizeof(uint16_t));

#endif // USE_PULSE_SENSOR
#ifdef USE_GSR_SENSOR
BLECharacteristic BLEManager::gsrChar(GSR_UUID, BLERead | BLENotify, sizeof(float));            // GSR Sensor;
BLECharacteristic BLEManager::tonChar(TON_UUID, BLERead | BLENotify, sizeof(float));
BLECharacteristic BLEManager::fasChar(FAS_UUID, BLERead | BLENotify, sizeof(float));
#endif // USE_GSR_SENSOR

#ifdef USE_HRV
BLECharacteristic BLEManager::hrvSdrrChar(HRV_SDRR_UUID, BLERead | BLENotify, sizeof(float));   // SDRR;
BLECharacteristic BLEManager::hrvRmssdChar(HRV_RMSSD_UUID, BLERead | BLENotify, sizeof(float)); // RMSSD;
BLECharacteristic BLEManager::hrvPnn50Char(HRV_PNN50_UUID, BLERead | BLENotify, sizeof(float)); // pNN50.
#endif // USE_HRV


// Caratteristica Status (1 byte):
BLEByteCharacteristic BLEManager::statusChar(STATUS_UUID, BLERead | BLENotify);

// Caratteristica CTRL (1 byte) per comando da Flutter:
BLEByteCharacteristic BLEManager::ctrlChar(CTRL_UUID, BLEWrite | BLEWriteWithoutResponse);

// Inizializzazione dell'aggiornamento rate-limit dei sensori:
#ifdef USE_PULSE_SENSOR
unsigned long BLEManager::lastPulseUpdate = 0;
unsigned long BLEManager::lastBPMUpdate = 0;
#endif // USE_PULSE_SENSOR
#ifdef USE_GSR_SENSOR
unsigned long BLEManager::lastGsrUpdate   = 0;
unsigned long BLEManager::lastTonUpdate   = 0;
unsigned long BLEManager::lastFasUpdate   = 0;
#endif // USE_GSR_SENSOR
#ifdef USE_HRV
unsigned long BLEManager::lastHrvUpdate = 0;
#endif // USE_HRV

// Inizializzazione dei flag:
volatile bool BLEManager::streamingEnabled = false;                   
volatile bool BLEManager::connectedFlag = false;                      
// Funzione che inizializza il modulo BLE:
bool BLEManager::begin()
{
    if (!BLE.begin())
    {
        // Se BLE non parte:
        Serial.println("ERRORE! Inizializzazione BLE fallita.");
        return false;                                                 
    }
    // Impostazione del nome del dispositivo che verrà mostrato all'app:
    BLE.setLocalName(BLE_DEVICE_NAME);                    
    Serial.println("Impostato nome del dispositivo!");                

    // Pubblicizziamo il servizio BLE:
    BLE.setAdvertisedService(sensorService);

    // Aggiunta delle caratteristiche al servizio:
    #ifdef USE_PULSE_SENSOR
    sensorService.addCharacteristic(pulseChar); 
    sensorService.addCharacteristic(bpmChar);
    #endif // USE_PULSE_SENSOR
    #ifdef USE_GSR_SENSOR                      
    sensorService.addCharacteristic(gsrChar);
    sensorService.addCharacteristic(tonChar); 
    sensorService.addCharacteristic(fasChar);  
    #endif // USE_GSR_SENSOR            

    #ifdef USE_HRV
    sensorService.addCharacteristic(hrvSdrrChar); 
    sensorService.addCharacteristic(hrvRmssdChar);
    sensorService.addCharacteristic(hrvPnn50Char);
    #endif // USE_HRV

    sensorService.addCharacteristic(statusChar);                       
    sensorService.addCharacteristic(ctrlChar);                         
    // Registrazione del servizio nel modulo BLE:
    BLE.addService(sensorService);                                     

    // Impostazione della caratteristica ctrl come gestione delle scritture dall'app:
    ctrlChar.setEventHandler(BLEWritten, BLEManager::onControlWritten); 

    // Inizializzazione dei valori: 
    const float z = 0.0f; 
    const uint16_t b = 0;
    #ifdef USE_PULSE_SENSOR                                          
    pulseChar.writeValue((const uint8_t*)&z, sizeof(float));
    bpmChar.writeValue((const uint8_t*)&b, sizeof(uint16_t));  
    #endif // USE_PULSE_SENSOR
    #ifdef USE_GSR_SENSOR     
    gsrChar.writeValue((const uint8_t*)&z, sizeof(float));
    tonChar.writeValue((const uint8_t*)&z, sizeof(float));  
    fasChar.writeValue((const uint8_t*)&z, sizeof(float));    
    #endif // USE_GSR_SENSOR
    #ifdef USE_HRV
    hrvSdrrChar.writeValue((const uint8_t*)&z, sizeof(float));         
    hrvRmssdChar.writeValue((const uint8_t*)&z, sizeof(float));        
    hrvPnn50Char.writeValue((const uint8_t*)&z, sizeof(float)); 
    #endif // USE_HRV  

    // Status iniziale impostato come IDLE:
    statusChar.writeValue((uint8_t)STATUS_IDLE);
    // Inizializzazione dei flag:
    streamingEnabled = false;        
    connectedFlag = false;  
    // Avvio dell'advertising:
    BLE.advertise();
    Serial.println("BLE Advertising completato!");
    return true;
}
// Centrale attuale. Serve per la gestione degli stati di connessione:
static BLEDevice currentCentral;
// Funzione di Poll BLE e gestione della connessione:
void BLEManager::poll()
{
    BLE.poll(); 

    // Aggiorna la flag di connessione in modo robusto: 
    BLEDevice c = BLE.central();                                       // Legge se una centrale è connessa;
    // Se una centrale è connessa:
    if (c)                                                             
    {
        currentCentral = c;                                            // Salva la centrale in quella attuale;
        connectedFlag = true;                                          // Setta il flag a "connesso";
    }
    // Se risulta connesso:
    if (connectedFlag)                                                 
    {
        // Se il central si disconnette:
        if (!currentCentral || !currentCentral.connected())
        {
            connectedFlag = false;                                     // Reset del flag di connessione;
            streamingEnabled = false;                                  // Disabilitazione dello streaming;
            statusChar.writeValue((uint8_t)STATUS_IDLE);               // Aggiornamento dello stato a IDLE.
        }
    }
}
// Funzione che dice se il dispositivo è connesso:
bool BLEManager::isConnected()
{
    // Serial.print("Il dispositivo è: ");
    // Serial.println(connectedFlag);
    return connectedFlag;                                              // Ritorna il flag di connessione.
}
// Funzione che dice se lo streaming di dati è abilitato:
bool BLEManager::isStreamingEnabled()
{
    Serial.print("Lo streamingEnabled è: ");
    Serial.println(streamingEnabled);
    return streamingEnabled;                                           // Ritorna il flag dello streaming.
}
// Funzione che imposta lo Status e le rispettive flag:
void BLEManager::setStatus(DeviceStatus status)
{
    if (status == STATUS_STREAMING) streamingEnabled = true;           // Se streaming: abilita flag di streaming;
    if (status == STATUS_IDLE) streamingEnabled = false;               // Se idle: disabilita flag di streaming;

    statusChar.writeValue((uint8_t)status);                            // Scrive lo Status sulla caratteristica relativa.
}

// Funzioni che controllano le sottoiscrizioni:
bool BLEManager::anySubscribedSensors()
{
    bool subscribed = false;

    #ifdef USE_PULSE_SENSOR
    subscribed |= pulseChar.subscribed();
    subscribed |= bpmChar.subscribed();
    #endif // USE_PULSE_SENSOR
    #ifdef USE_GSR_SENSOR
    subscribed |= gsrChar.subscribed();
    subscribed |= tonChar.subscribed();
    subscribed |= fasChar.subscribed();
    #endif // USE_GSR_SENSOR

    return subscribed;
}
#ifdef USE_HRV
bool BLEManager::anySubscribedHRV()
{
    return hrvSdrrChar.subscribed() || hrvRmssdChar.subscribed() || hrvPnn50Char.subscribed();
}
#endif // USE_HRV


// Funzione per il rate limit:
bool BLEManager::rateLimitOK(unsigned long &lastTs, unsigned long periodMs)
{
    const unsigned long now = millis();
    if (now - lastTs < periodMs) return false;
    lastTs = now;
    return true;
}

// Funzione che aggiorna il valore dei sensori (rate limited):
void BLEManager::updatePulse(float pulse)
{
    if (!connectedFlag || !streamingEnabled) return;
    if (!pulseChar.subscribed()) return;
    if (!rateLimitOK(lastPulseUpdate, BLE_SENSOR_UPDATE_MS)) return;

    pulseChar.writeValue((const uint8_t*)&pulse, sizeof(float));
}

void BLEManager::updateBPM(uint16_t bpm)
{
    if (!connectedFlag || !streamingEnabled) return;
    if (!bpmChar.subscribed()) return;
    if (!rateLimitOK(lastBPMUpdate, BLE_SENSOR_UPDATE_MS)) return;

    bpmChar.writeValue((const uint8_t*)&bpm, sizeof(uint16_t));
}


void BLEManager::updateGSR(float gsr)
{
    if (!connectedFlag || !streamingEnabled) return;
    if (!gsrChar.subscribed()) return;
    if (!rateLimitOK(lastGsrUpdate, BLE_SENSOR_UPDATE_MS)) return;

    gsrChar.writeValue((const uint8_t*)&gsr, sizeof(float));
}

void BLEManager::updateFas(float fas)
{
    if (!connectedFlag || !streamingEnabled) return;
    if (!fasChar.subscribed()) return;
    if (!rateLimitOK(lastFasUpdate, BLE_SENSOR_UPDATE_MS)) return;

    fasChar.writeValue((const uint8_t*)&fas, sizeof(float));
}

void BLEManager::updateTon(float ton)
{
    if (!connectedFlag || !streamingEnabled) return;
    if (!tonChar.subscribed()) return;
    if (!rateLimitOK(lastTonUpdate, BLE_SENSOR_UPDATE_MS)) return;

    tonChar.writeValue((const uint8_t*)&ton, sizeof(float));
}


// Funzione che aggiorna il valore delle metriche HRV:
void BLEManager::updateHRV(float sdrr, float rmssd, float pnn50)
{
    // Se il dispositivo non è connesso e lo streaming è disattivato, esci:
    if (!connectedFlag || !streamingEnabled) return;

    // Debug sulle sottoiscrizioni:
    if (!anySubscribedHRV()) 
    {
        Serial.println ("Nessuna metrica HRV ha la sottoiscrizione");
        return;   
    }  

    if (!rateLimitOK(lastHrvUpdate, BLE_HRV_UPDATE_MS)) return;

    // Si controlla se ci sono le sottoiscrizioni e poi si aggiorna:
    if (hrvSdrrChar.subscribed())
    {
        hrvSdrrChar.writeValue((const uint8_t*)&sdrr, sizeof(float));  
    }   
    if (hrvRmssdChar.subscribed())
    {
        hrvRmssdChar.writeValue((const uint8_t*)&rmssd, sizeof(float));
    }
    if (hrvPnn50Char.subscribed())
    {
        hrvPnn50Char.writeValue((const uint8_t*)&pnn50, sizeof(float));
    }
    Serial.println("HRV aggiornati!");
}

// Funzione che gestisce il comando in arrivo dall'app: 
void BLEManager::onControlWritten(BLEDevice central, BLECharacteristic characteristic)
{
    (void)central;                                                     // Non influisce sul comportamento, cast a void;

    uint8_t cmd = 0;                                                   // Inizializzazione di cmd. ctrl è BLEByteCharacteristic: 1 byte;
    // Se non si riesce a leggere il byte du comando:
    if (!characteristic.readValue(cmd))                               
    {
        Serial.println("Lettura del comando di Flutter fallita"); 
        return; 
    }
    // Interpreta cmd come ControlCommand:
    switch ((ControlCommand)cmd)                                       
    {
        case CMD_START:
            streamingEnabled = true;                                   // Abilita lo streaming;
            statusChar.writeValue((uint8_t)STATUS_STREAMING);          // Modifica lo status in streaming;
            Serial.println("STREAMING"); 
            break;

        case CMD_STOP: 
            streamingEnabled = false;                                  // Disabilita lo streaming;
            statusChar.writeValue((uint8_t)STATUS_IDLE);               // Modifica lo status in idle;
            Serial.println("IDLE"); 
            break;

        case CMD_RESET:                 // Nel modulo BLE lo trattiamo come STOP+IDLE.
            streamingEnabled = false;                                  // Disabilita lo streaming;
            statusChar.writeValue((uint8_t)STATUS_IDLE);               // Modifica lo status in idle;
            Serial.println("RESET");
            break;

        default:                                                       // Nel caso di comando sconosciuto;
            Serial.println("NON CONOSCIUTO");
            break; 
    }
}

#endif // fine USE_BLE

#ifndef NC_BLE_H                                  
#define NC_BLE_H                                  

#include <Arduino.h>                               // Inclusione funzioni di Arduino;
#include <ArduinoBLE.h>                            // Includsione libreria ArduinoBLE;
#include "config.h"                                // Inclusione file di configurazione progetto.

#ifdef USE_BLE

class BLEManager                                   // Classe manager per BLE (statica: non instanzio oggetti);
{
// Metodi/enum pubblici:
public:                                            

    // Stati notificati alla app (STATUS_UUID) di 1 byte:
    enum DeviceStatus : uint8_t
    {
        STATUS_IDLE = 0,                           // Stato: idle;
        STATUS_CONNECTED = 1,                      // Stato: connesso;
        STATUS_STREAMING = 2,                      // Stato: streaming attivo;
        STATUS_ERROR = 3                           // Stato: errore.
    };

    // Comandi ricevuti dalla app (CTRL_UUID) di 1 byte:
    enum ControlCommand : uint8_t
    {
        CMD_NOP   = 0,                             // Nessuna operazione;
        CMD_START = 1,                             // Avvia streaming;
        CMD_STOP  = 2,                             // Ferma streaming;
        CMD_RESET = 3                              // Reset.
    };
    // Funzione che inizializza il BLE:
    static bool begin();           
    // Funzione che realizza il polling del BLE:                
    static void poll();
    // Funzione che ritorna il flag della connessione:
    static bool isConnected(); 
    // Funzione che ritorna il flag dello streaming:
    static bool isStreamingEnabled();
    // Funzione che imposta lo stato:
    static void setStatus(DeviceStatus status);

    // Funzioni che controllano le sottoiscrizioni:
    static bool anySubscribedSensors();
    static bool anySubscribedHRV();

    // Funzioni che aggiornano i valori da condividere.
    static void updatePulse(float pulse);   // Aggiorna i valori Pulse Sensor (float)
    static void updateGSR(float gsr);       // Aggiorna i valori GSR (float)
    static void updateTon(float ton);
    static void updateFas (float fas);
    static void updateHRV(float sdrr, float rmssd, float pnn50);            // Aggiorna i valori HRV (float);

    static void updateBPM (uint16_t bpm);
// Metodi privati:
private:  
    // Funzione che gestisce il comando in arrivo dall'app:                                         
    static void onControlWritten(BLEDevice central, BLECharacteristic characteristic);
// Membri statici privati:
    // Servizio del BLE:
    static BLEService sensorService;

    // Caratteristiche dei sensori:
    static BLECharacteristic pulseChar;            // Caratteristica del Pulse Sensor (float raw);
    static BLECharacteristic gsrChar;              // Caratteristica del GSR Sensor (float);

    // Caratteristica BPM:
    static BLECharacteristic bpmChar; // Caratteristica dei BPM (int);

    // Caratteristiche GSR Plus:
    static BLECharacteristic tonChar;
    static BLECharacteristic fasChar;

    // Caratteristiche di HRV:                       
    static BLECharacteristic hrvSdrrChar;          // Caratteristica di SDRR (float);
    static BLECharacteristic hrvRmssdChar;         // Caratteristica di RMSSD (float);
    static BLECharacteristic hrvPnn50Char;         // Caratteristica di pNN50 (float);


    // Caratteristica dello stato (1 byte):
    static BLEByteCharacteristic statusChar; 

    // Caratteristica del controllo (1 byte):
    static BLEByteCharacteristic ctrlChar;

    static bool rateLimitOK(unsigned long &lastTsn, unsigned long periodMs); // Per temporizzazione aggiornamenti sensori;

    // Tempi di aggiornamento dei sensori:
    static unsigned long lastPulseUpdate;
    static unsigned long lastGsrUpdate;

    // Tempi di aggiornamento delle metriche:
    static unsigned long lastHrvUpdate;
    static unsigned long lastFftUpdate;
    // Tempi di aggiornamento dei BPM:
    static unsigned long lastBPMUpdate;
    //Tempi di aggiornamento di GSR Plus
    static unsigned long lastTonUpdate;
    static unsigned long lastFasUpdate;

    // Flags:
    static volatile bool streamingEnabled;         // Flag per streaming (volatile: accesso in handler/eventi);
    static volatile bool connectedFlag;            // Flag per connessione (volatile);
};

#endif // fine USE_BLE                                  
#endif // BLE_H 

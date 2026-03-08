// Inclusioni file .h:
#include "config.h" // Inclusione del file di configurazione per tutte le macros e le definizioni.

#ifdef USE_PULSE_SENSOR // Se USE_PULSE_SENSOR è attivo, includi il file .h relativo.
#include "PulseSensor.h"
#endif

#ifdef USE_GSR_SENSOR // Se USE_GSR_SENSOR è attivo, includi il file .h relativo.
#include "GSRSensor.h"
#endif

#ifdef USE_HRV // Se USE_HRV è attivo, includi il file .h relativo.
#include "HRV.h"
#endif

#ifdef USE_BLE // Se USE_BLE è attivo, includi il file .h relativo.
#include "BLE.h"
#endif

// Definizione variabili:

unsigned long intervals[NUM_READINGS]; // Buffer degli intervalli RR.
unsigned long timestamps[NUM_READINGS]; // Buffer dei valori di tempo associati agli intervalli per costruire la serie.

int intervalIndex = 0; // Indice per il buffer circolare.
bool bufferFull = false; // Valore che indica se il buffer è pieno.
unsigned long lastBeatTime = 0; // Valore temporale dell’ultimo battito (per calcolare intervallo RR = beatTime - lastBeatTime).
static uint16_t lastBpm = 0;

#ifdef USE_HRV
static HRV_data hrv = {0.0f, 0.0f, 0.0f};  
#endif

#ifdef USE_GSR_SENSOR
GSRSensor gsr(GSR_SENSOR_PIN, SAMPLE_PERIOD);
#endif



void setup()
{
  Serial.begin(115200);
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0 < 3000)) { }  // aspetta fino a 3s
  Serial.println(" ");
  Serial.println("Connessione Seriale Aperta");

  #ifdef USE_PULSE_SENSOR // Se attivo viene inizializzato il "Pulse Sensor" con la funzione definita nel file .h
  initPulseSensor(); 
  #endif

  #ifdef USE_GSR_SENSOR
  Serial.println("Sensore GSR pronto!");
  #endif

  #ifdef USE_BLE // Se attivo viene inizializzato il modulo BLE.
  BLEManager::begin();
  #endif
}

void loop()
{
  // Loop non-bloccante (delay bloccherebbe il loop)
  static unsigned long lastLoopTime = 0; // Valore dello scorso loop. Static: mantiene il valore tra le iterazioni.
  const unsigned long now = millis(); // Valore del loop attuale. Const: il suo valore non può essere più riassegnato.
  if (now - lastLoopTime < MAIN_LOOP_DELAY_MS) // Se
  {
    #ifdef USE_BLE // Anche quando si aspetta, bisogna mantenere BLE attivo.
    BLEManager::poll(); // Viene effettuato il poll del BLE, preso dalla funzione nel file .h.
    #endif // USE_BLE
    return; // Si salta il resto del loop.
  }
  lastLoopTime = now; // Aggiorna riferimento temporale quando fai un giro valido.

  #ifdef USE_BLE // Si fa poll anche nei giri validi.
  BLEManager::poll();

  static bool wasConnected = false; // Variabile che mi memorizza se il dispositivo fosse connesso.
  const bool connected = BLEManager::isConnected(); // Viene letto se attualmente si è connessi oppure no.

  if (connected && !wasConnected) // Se siamo connessi ma prima non lo eravamo:
  {
    BLEManager::setStatus(BLEManager::STATUS_CONNECTED); // Impostiamo lo stato a CONNESSO.
    wasConnected = true; // Aggiorniamo il fatto che siamo connessi.
  }
  else if (!connected && wasConnected) // Se non siamo connessi ma lo eravamo:
  {
    BLEManager::setStatus(BLEManager::STATUS_IDLE); // Impostiamo lo stato a DISCONNECTED.
    wasConnected = false; // Aggiorniamo il fatto che non siamo connessi.
  }
  #endif // end USE_BLE

  #ifdef USE_GSR_SENSOR
  static float gsr_raw = 0.0f;
  static float gsr_med = 0.0f;
  static float gsr_tonic = 0.0f;
  static float gsr_phasic = 0.0f;

  // aggiorna solo ogni SAMPLE_PERIOD (250ms) perché values() fa il rate interno
  if (gsr.values())
  {
    gsr_raw    = gsr.getRaw();
    gsr_med    = gsr.getMedian();
    gsr_tonic  = gsr.getTonic();
    gsr_phasic = gsr.getPhasic();
  }

  float gsrValue = gsr_med;
  float fasValue = gsr_phasic;
  float tonValue = gsr_tonic;
  #endif // end USE_GSR_SENSOR

  #ifdef USE_PULSE_SENSOR
  int signal;               // Segnale grezzo acquisito dal sensore.
  int bpm;                  // Battiti per minuto.
  unsigned long beatTime;   // Valore di tempo nel momento in cui viene riconosciuto un battito.

  if (readPulseSensor(signal, bpm, beatTime)) // Se viene riconosciuto un battito: (proviene dal file .h).
  {
    lastBpm = (uint16_t)bpm;
    if (lastBeatTime > 0) // Ignoriamo il primo battito perchè non avremmo un altro per fare il paragone.
    {
      unsigned long interval = beatTime - lastBeatTime; // L'intervallo è calcolato con il valore di tempo del battito meno quello precedente (in ms).
      if (interval > MIN_RR_INTERVAL_MS && interval < MAX_RR_INTERVAL_MS) // Se l'intervallo è compreso nel range definito: (filtro dei valori accettati).
      {
        intervals[intervalIndex] = interval; // Si salva il valore dell'intervallo nel buffer.
        timestamps[intervalIndex] = beatTime; // Si salva il suo istante nel buffer corrispondente.
        intervalIndex++; // Si aumenta il numero degli intervalli calcolati.

        if (intervalIndex >= NUM_READINGS) // Se il numero degli intervalli calcolati è maggiore del valore definito:
        {
          intervalIndex = 0; // Si resetta l'indice per il buffer circolare.
          bufferFull = true; // Si imposta come vero il valore che indica quando il buffer è pieno.
        }

        int count = bufferFull ? NUM_READINGS : intervalIndex; // Viene contato il numero di intervalli validi presenti nel buffer: se bufferfull è vero alora è NUM_READINGS sennò è intervalIndex
        
        #ifdef USE_HRV // Viene calcolata la HRV sugli intervalli RR validi. 
        hrv = calculateHRV(intervals, count); // Funzione che proviene dal file .h corrispondente.
        Serial.println("Le grandezze HRV sono calcolate!");

        #endif // USE_HRV

        //Serial.print("BPM: "); // Viene stampato il valore dei BPM, sarebbe da mandare pure questo.
        //Serial.println(bpm);
      }
    }

    lastBeatTime = beatTime; // Viene aggiornato il valore dell'ultimo battito
  }
  #endif // USE_PULSE_SENSOR
 // Serial.println("SONO APPENA FUORI DALL'AGGIORNAMENTO DEI SENSORI");

    #ifdef USE_BLE // Invio BLE solo quando lo streaming è stato abilitato via CTRL.
   // Serial.println("SONO DENTRO L'AGGIORNAMENTO DEI SENSORI");
    if (BLEManager::isConnected() && BLEManager::isStreamingEnabled())
    {
      const float pulseValue = (float)signal; 

      #ifdef USE_PULSE_SENSOR
      BLEManager::updatePulse(pulseValue);
      BLEManager::updateBPM(lastBpm);
      #endif // USE_PULSE_SENSOR

      #ifdef USE_HRV
      BLEManager::updateHRV(hrv.SDRR, hrv.RMSSD, hrv.pNN50);
      Serial.println("Mando i valori HRV");
      #endif // USE_HRV

      #ifdef USE_GSR_SENSOR
      BLEManager::updateGSR(gsrValue);
      Serial.println("AGGIORNO FAS");
      BLEManager::updateFas(fasValue);
      Serial.println("AGGIORNO TON");
      BLEManager::updateTon(tonValue);
      #endif // USE_GSR_SENSOR

      Serial.println("Mando i valori dei sensori");
    }
    #endif // USE_BLE

}

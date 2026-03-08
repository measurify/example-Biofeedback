#define PULSE_SENSOR_NO_SERIAL_OUTPUT         ///< Disabilita l'output Serial interno della libreria

#include "PulseSensor.h"                      // Inclusione libreria personalizzata.

// Definizione dell'istanza globale del sensore:
PulseSensorPlayground pulseSensor;            

//struct per soglia adattiva
struct AdaptiveThreshold 
{
  float base = 0.0f;                       // baseline 
  float dev  = 0.0f;                       // deviazione media assoluta
  int   thr  = PULSE_THRESHOLD_DEFAULT;      // soglia corrente
  bool  init = false;
};

static AdaptiveThreshold gat; // Oggetto
static unsigned long gatLastBeatTime = 0;

static inline int clampInt(int v, int lo, int hi) 
{
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static void updateAdaptiveThreshold(int s) 
{
  if (!gat.init) 
  {
    gat.base = (float)s;
    gat.dev  = 0.0f;
    gat.thr  = clampInt(s, THR_MIN, THR_MAX); // iniziale: vicino al segnale
    gat.init = true;
    return;
  }
  //baseline
  gat.base += ALPHA_BASE * ((float)s - gat.base);
  // deviazione
  float err = fabsf((float)s - gat.base);
  gat.dev  += ALPHA_DEV * (err - gat.dev);

  int newThr = (int)(gat.base + K_SIGMA * gat.dev);
  gat.thr = clampInt(newThr, THR_MIN, THR_MAX);
}

// Funzione di inizializzazione del PulseSensor:
void initPulseSensor()                        
{
  pulseSensor.analogInput(PULSE_SENSOR_PIN);  // Imposta il pin analogico da cui leggere il segnale;
  pulseSensor.blinkOnPulse(LED_PIN);          // Fa lampeggiare il LED ad ogni battito rilevato-->fare interfaccia su app con cuore che batte e BPM scritti sotto
  pulseSensor.setThreshold(PULSE_THRESHOLD_DEFAULT);  // Imposta la soglia di rilevamento del battito;
  if (pulseSensor.begin())                    // Avvia la libreria e verifica se pronta:
  {
    Serial.println("PulseSensor pronto!");    // Messaggio diagnostico su Serial;
  }
  else
  {
    Serial.println("ERRORE! PulseSensor non disponibile."); // Messaggio errore su Serial.
  }
  // reset soglia adattiva
  gat = AdaptiveThreshold{};
  gatLastBeatTime = 0;
}

// Funzione di lettura del sensore:
bool readPulseSensor(int &signal, int &bpm, unsigned long &beatTime)
{
  bool newSample = pulseSensor.sawNewSample(); // Verifica che ci sia un nuovo valore, polling senza interrupt;
  signal = pulseSensor.getLatestSample();     // Prende l'ultimo campione disponibile dal sensore;
  if (newSample) 
  {
    updateAdaptiveThreshold(signal);
    pulseSensor.setThreshold(gat.thr);
  }

  if (pulseSensor.sawStartOfBeat())           // Verifica se è iniziato un nuovo battito;
  {
    unsigned long now = millis();
    Serial.println("Battito rilevato!");      // Messaggio diagnostico che segnala rilevamento battito;
    if (gatLastBeatTime != 0 && (now - gatLastBeatTime) < MIN_RR_INTERVAL_MS) 
    {
      return false;
    }
    gatLastBeatTime = now;

    bpm = pulseSensor.getBeatsPerMinute();    // Legge BPM stimati dalla libreria;
    beatTime = millis();                      // Salva il timestamp del battito (tempo corrente);
    return true;                              // Battito rilevato e parametri aggiornati.
  }
  return false;                               // Se non c'è nessun battito rilevato.
}

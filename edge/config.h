#ifndef CONFIG_H
#define CONFIG_H

/************************************************************
 *                  MODULI ABILITABILI
 * Commenta una macro per escludere il relativo modulo
 * dalla compilazione (ottimizzazione memoria/CPU)
 ************************************************************/

#define USE_PULSE_SENSOR     // Abilita il sensore di battito cardiaco (Pulse Sensor);
#define USE_GSR_SENSOR       // Abilita il sensore GSR (Galvanic Skin Response);
#define USE_HRV               // Abilita il calcolo HRV (Heart Rate Variability);
#define USE_BLE               // Abilita comunicazione Bluetooth Low Energy.


/************************************************************
 *                  PIN HARDWARE
 ************************************************************/

#define PULSE_SENSOR_PIN   A0          // Pin analogico collegato al Pulse Sensor;
#define GSR_SENSOR_PIN     A2           // Pin analogico collegato al GSR Sensor;
#define LED_PIN            LED_BUILTIN  // LED integrato sulla scheda (debug / feedback).


/************************************************************
 *                  PARAMETRI PULSE SENSOR
 ************************************************************/

#define PULSE_THRESHOLD_DEFAULT     550   // Soglia di default oltre la quale viene rilevato un battito;
#define MIN_RR_INTERVAL_MS  300   // Intervallo RR minimo valido (≈200 BPM);
#define MAX_RR_INTERVAL_MS  2000  // Intervallo RR massimo valido (≈30 BPM);
#define ALPHA_BASE 0.01f
#define ALPHA_DEV 0.01f
#define K_SIGMA 3.0f
#define THR_MIN 0
#define THR_MAX 1023


/************************************************************
 *                  PARAMETRI GSR SENSOR
 ************************************************************/

#define SAMPLE_PERIOD 250 // Periodo di sampling;
#define MED_WIN 11 // Finestra del filtro a mediana, deve essere dispari;


/************************************************************
 *                  CAMPIONAMENTO & ELABORAZIONE
 ************************************************************/

#define NUM_READINGS          128   // Numero campioni per FFT e interpolazione (potenza di 2);
#define TARGET_SAMPLING_FREQ  4.0   // Frequenza di campionamento target (Hz) dopo interpolazione.


/************************************************************
 *                  TIMING SISTEMA
 ************************************************************/

#define MAIN_LOOP_DELAY_MS    2       // Ritardo del loop principale (ms)
#define BLE_SENSOR_UPDATE_MS  50      // Periodo invio dati BLE sensori (ms)-->20Hz
#define BLE_HRV_UPDATE_MS     1000    // Periodo invio dati BLE HRV (ms)


/************************************************************
 *                  BLUETOOTH LOW ENERGY
 ************************************************************/

#define BLE_DEVICE_NAME "Arduino-BIOFEEDBACK"  // Nome pubblicizzato del dispositivo BLE


/*********************** UUID SERVIZIO ************************/

#define SERVICE_UUID "25a1cabf-b34b-4d86-8252-da0507816360" // UUID servizio BLE principale

/*************************UUID DI CONTROLLO*********************/
#define CTRL_UUID    "618f17cb-b111-470b-8b79-44254ca1f1d6" // UUID caratteristica comando di controllo
#define STATUS_UUID  "1d268694-36cc-4b0b-b37c-fdf54cba9663" // UUID caratteristica stato del sistema


/*********************** UUID SENSORI ************************/

#define PULSE_UUID "ea544b30-84a2-40ff-bf36-5281e428dbbd" // UUID caratteristica Pulse Sensor
#define GSR_UUID   "9929a7e4-ac86-4627-891a-6f9e1f02e843" // UUID caratteristica GSR Sensor

/*********************** UUID BPM ************************/

#define BPM_UUID "f4b858bf-31a1-463c-b2d1-c9b3c68855a4" // UUID caratteristica BPM

/***********************UUID GSR PLUS******************************/
#define TON_UUID   "2d23cbf1-c4ea-480a-bdf7-5cd4ceb56c34" // UUID caratteristica componente Tonica
#define FAS_UUID   "6f8a58a6-78c4-4802-82ea-621b342eb7a2" // UUID caratteristica componente Fasica

/*********************** UUID HRV ************************/

#define HRV_SDRR_UUID  "86990b84-13ca-43ee-9002-24175cd702e4" // UUID caratteristica Deviazione standard RR
#define HRV_RMSSD_UUID "41b0ed34-3874-44e5-88ff-c5e3d36c54e3" // UUID caratteristica RMSSD
#define HRV_PNN50_UUID "d6c35231-fa9a-41d2-b804-e0acd10d7d37" // UUID caratteristica pNN50



/************************************************************
 *                  CONTROLLI DI COMPILAZIONE
 ************************************************************/

// Controllo di coerenza sugli intervalli RR:
#if MIN_RR_INTERVAL_MS >= MAX_RR_INTERVAL_MS
  #error "MIN_RR_INTERVAL_MS deve essere minore di MAX_RR_INTERVAL_MS"
#endif

#endif // CONFIG_H

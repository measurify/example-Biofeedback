#ifndef HRV_H                               // Include guard: evita inclusioni multiple
#define HRV_H                               // Definizione include guard

/************************************************************
 *                  INCLUSIONI LIBRERIE
 ************************************************************/
#include <Arduino.h>                      // Inclusione funzioni di Arduino;
#include "config.h"                       // Inclusione file di configurazione progetto.

#ifdef USE_HRV

// Struttura dati contenente le metriche HRV:
typedef struct {                            
  float SDRR;                               // SDRR (ms): deviazione standard degli intervalli RR;
  float RMSSD;                              // RMSSD (ms): radice media quadratica differenze successive;
  float pNN50;                              // pNN50 (%): % di differenze successive >= 50ms
} HRV_data;           


// Funzione che calcola le metriche HRV:
HRV_data calculateHRV(unsigned long *intervals, int count);

#endif // fine USE_HRV
#endif // HRV_H

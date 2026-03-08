#include "HRV.h"                                              // Inclusione libreria personalizzata.

#ifdef USE_HRV

// Funzione che calcola le metriche HRV:
HRV_data calculateHRV(unsigned long *intervals, int count) 
{
  HRV_data hrv = {0, 0, 0};                        // Inizializzazione dell'oggetto;
  if (count < 2) return hrv;                       // Se ci sono meno di 2 intervalli non si calcola nulla: ritorna {0, 0, 0};
  float mean = 0;                                  // Variabile per media degli intervalli RR;
  // Somma di tutti gli intervalli:
  for (int i = 0; i < count; i++)
  {
    mean += intervals[i];
  }
  mean /= count;                                     // Calcolo della Media = somma / numero di campioni;

  float sumSq = 0;                                   // Somma degli scarti quadratici (per SDNN);
  float sumDiffSq = 0;                               // Somma dei quadrati delle differenze successive (per RMSSD);
  int nn50 = 0;                                      // Conteggio differenze successive >= 50ms (per pNN50).
  // Si parte da 1 perchè serve (i-1) per differenze successive:
  for (int i = 1; i < count; i++)                              
  {
    // Calcoliamo la deviazione dalla media per il calcolo di SDNN:
    float diff = intervals[i] - mean;                          // Scarto dalla media;
    sumSq += diff * diff;                                      // Accumulo quadrato dello scarto;

    // Calcoliamo le differenze successive per il calcolo di RMSSD
    float successiveDiff = (float)intervals[i] - (float)intervals[i - 1];    // Differenza successiva;
    sumDiffSq += successiveDiff * successiveDiff;              // Accumula quadrato della differenza successiva;

    if (fabs(successiveDiff) >= 50.0f)                        // Se il valore assoluto della differenza successiva è >= 50ms;
    {
      nn50++;                                                 // Incrementa NN50.
    }
  }

  hrv.SDRR = sqrt(sumSq / (count - 1));
  hrv.RMSSD = sqrt(sumDiffSq / (count - 1));
  hrv.pNN50 = ((float)nn50 / (count - 1)) * 100.0;

  return hrv;                                            // Ritorna la struttura con le metriche calcolate.
}

#endif // USE_HRV

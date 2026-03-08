#include "GSRSensor.h"

#ifdef USE_GSR_SENSOR

GSRSensor::GSRSensor(uint8_t pin, uint32_t samplePeriod) 
{
    // Assegniamo i parametri passati alle variabili interne
    _samplePeriod = samplePeriod;

    // Inizializziamo lo stato del sensore
    _lastSampleTime = 0;
    medIdx = 0;
    medFilled = false;
    tonic = 0.0f;
    tonicInit = false;
    
    // Possiamo aggiungere anche logica extra se serve
    condRaw = 0.0f;
    phasic = 0.0f;
    medVal = 0.0f;
}


bool GSRSensor::values() 
{
  unsigned long now = millis();
  if (now - _lastSampleTime < _samplePeriod) return false;

  _lastSampleTime += _samplePeriod;

  // 1) Media di 20 letture ADC (oversampling)
  float sum = 0.0f;
  for (int i = 0; i < 20; i++) 
  {
    sum += (float)analogRead(GSR_SENSOR_PIN);
  }
  float gsr_ave = sum / 20.0f;

  // 2) Calcolo Conduttanza (µS)
  float denom = 345.0f - gsr_ave;
  if (fabs(denom) < 1e-3) return false;

  float h_res = ((1024.0f + 2.0f * gsr_ave) * 10000.0f) / denom;
  if (h_res <= 0.0f) return false;

  condRaw = 1000000.0f / h_res;

  // 3) Filtro Mediano
  medBuf[medIdx] = condRaw;
  medIdx++;
  if (medIdx >= MED_WIN) 
  { 
    medIdx = 0; 
    medFilled = true; 
  }

    if (!medFilled) 
    {
      if (!tonicInit) { tonic = condRaw; tonicInit = true; }
      phasic = condRaw - tonic;
      medVal = condRaw; // Fallback se buffer non pieno
  } else 
  {
    medVal = calculateMedian(medBuf);
        
    // 4) Componente Tonica (Low-pass)
    const float alpha = 0.07f;
    if (!tonicInit) { tonic = medVal; tonicInit = true; }
    tonic = (1.0f - alpha) * tonic + alpha * medVal;

    // 5) Componente Fasica
    phasic = condRaw - tonic;
  }
  return true;
}

float GSRSensor::calculateMedian(const float *x) 
{
    float a[MED_WIN];
    for (int i = 0; i < MED_WIN; i++) a[i] = x[i];

    // Insertion sort
    for (int i = 1; i < MED_WIN; i++) 
    {
        float key = a[i];
        int j = i - 1;
        while (j >= 0 && a[j] > key) 
        {
            a[j + 1] = a[j];
            j--;
        }
        a[j + 1] = key;
    }
    return a[MED_WIN / 2];
}
#endif // USE_GSR_SENSOR
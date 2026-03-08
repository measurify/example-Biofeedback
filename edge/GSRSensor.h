#ifndef GSR_SENSOR_H
#define GSR_SENSOR_H

#include <Arduino.h>    ///< Arduino core functions and data types
#include "config.h"     ///< Project configuration and feature flags

#ifdef USE_GSR_SENSOR

class GSRSensor 
{
public:

    GSRSensor(uint8_t pin, uint32_t samplePeriod);
    
    
    // Ritorna true se è avvenuta una nuova lettura
    bool values();

    // Getter per i valori elaborati
    float getRaw() const { return condRaw; }
    float getTonic() const { return tonic; }
    float getPhasic() const { return phasic; }
    float getMedian() const { return medVal; }

private:
    uint32_t _samplePeriod;
    unsigned long _lastSampleTime;

    float medBuf[MED_WIN];
    uint8_t medIdx;
    bool medFilled;
    
    float tonic;
    float phasic;
    float condRaw;
    float medVal;
    bool tonicInit;

    // Funzione interna per il calcolo del mediano
    float calculateMedian(const float *x);
};

#endif // USE_GSR_SENSOR
#endif // GSR_SENSOR_H
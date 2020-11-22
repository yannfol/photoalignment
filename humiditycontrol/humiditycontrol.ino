/******************************************************************************
  HUMIDITY MODULATOR

  The BME280 sensor gives output over I2C once every 2.5 seconds and

  30 seconds it would check for a sensor connection. This makes lets it be hot
  swapped without having to reprogram the arduino or reset it.


  Adapted from: https://forum.arduino.cc/index.php?topic=288234.0
  Forum for serial input basics

  Valid serial commands:
  <<R> will read the values
  <<CO> enables Control of humidity
  <<CF> disables Control of humidity
  <<HO> enables humidifier motor
  <<HF> disables humidifier motor

  Yannick Folwill (yannick.folwill@posteo.eu)
  Sanket B. Shah
*******************************************************************************/
#include <Wire.h>
#include <SparkFunBME280.h>

const byte numChars = 32;
char receivedChars[numChars];
boolean newData = false;
boolean control_on = false; // Overall control toggle, can be set over serial
boolean autosend = false; // by default disable automatic sending of stats

BME280 mySensor;            // Define sensor name
long prev = 0;              // Timing parameter for reading sensor
long sensorCheck = 0;       // Timing parameter for checking sensor connectivity
long pumptime = 100;
long out1 = 0;
long delta = 0;
unsigned long waiting = 3000;
unsigned long cont = 0;
unsigned long h_on = 0;
unsigned long h_off = 0;

// Connected outputs
int valve1 = 4;             // Dry Nitrogen valve
int valve2 = 5;             // Humidified Nitrogen valve
int humidi = 7;             // Humidifier motor
int humcon = 13;            // Humidifier manual switch

float target_RH = 32;       // Default starting value

void setup() {
  // Sensor Paramaters setup
  mySensor.settings.commInterface = I2C_MODE;   // I2C and not SPI
  mySensor.settings.I2CAddress = 0x77;          // 0x77 is default
  mySensor.settings.runMode = 1;                // Sleep or Forced or Normal mode
  mySensor.settings.tStandby = 0;               // Standby time for power saving
  mySensor.settings.filter = 0;                 // FIR filter
  mySensor.settings.humidOverSample = 5;        // Over sample humidity readings

    delay(10);  //Make sure sensor had enough time to turn on. BME280 requires 2ms to start up.
    Serial.begin(57600);

    Serial.print("Starting BME280... result of .begin(): 0x");
    //Calling .begin() causes the settings to be loaded
    Serial.println(mySensor.begin(), HEX);

  // valve control pins set to output
  pinMode(valve1, OUTPUT);
  pinMode(valve2, OUTPUT);
  pinMode(humidi, OUTPUT);
  pinMode(humcon, INPUT);
}

// Repeating functionality
void loop() {
  unsigned long time = millis();      // time since program began in milli seconds
  // Check every 30s since last reconnection to reconnect the sensor
  // Have not figured out a reliable way to do this only if sensor is not connected
//  if (time - sensorCheck > 30000)
//  {
//    mySensor.beginI2C();
//    sensorCheck = time;
//  }
  // every second read the sensor and give out values just if sensor is there
  if (time - out1 > 1000 && mySensor.readFloatHumidity() > 1 && autosend)
  {
    // Serial.print(time);
    // Serial.print(", ");
    Serial.print(mySensor.readFloatHumidity(), 2);
    Serial.print(", ");
    Serial.print(target_RH, 2);
    Serial.print(", ");
    Serial.print(mySensor.readFloatPressure() * 0.01, 2);
    Serial.print(", ");
    Serial.print(mySensor.readTempC(), 2);
    // Serial.print(", ");
    // Serial.print(digitalRead(humidi));
    // Serial.print(", ");
    // Serial.print(h_on);
    // Serial.print(", ");
    // Serial.print(h_off);
    // Serial.print(", ");
    // Serial.print(cont);
    Serial.println();
    out1=time;
  }
//   Humidity control
  readWithMarkers();
  readData();
  // if the control is enabled start controlling the humidity
  if (control_on)
  {
      delta = target_RH - mySensor.readFloatHumidity();
      // Control humidity only if difference is greater than 2%RH (changed from 2.5 %RH)
      // and more than 1 second has passed
      if (abs(delta) > 2 && time - cont > waiting)
      {
        if (abs(delta) > 10)
        {
          pumptime = 20*abs(delta);
          waiting = pumptime + 2500; // changed from 3500
        }
        else if (abs(target_RH - 50) < 20)
        {
          pumptime = 100;
          waiting = 5000; // changed from 10000
        }
        else
        {
          pumptime = 250;
          waiting = pumptime + 3500;
        }
        // Nitrogen if humidity is higher than target
        if (delta < 0)
        {
          digitalWrite(valve1, HIGH);
          delay(pumptime);   // Dry with nitrogen
          digitalWrite(valve1, LOW);
          digitalWrite(humidi, LOW);
        }
        // Humidify if humidity is lower than target
        else
        {
          // Run the humidifier motor automatically if the target is above 60%RH
          if (target_RH > 60)
          {
            if (digitalRead(humcon) == LOW)
            {
              if (time - h_on > 120000)
                {
                  // Turn on humidifier every 2 minutes
                  digitalWrite(humidi, HIGH);    //Turn on humidifier
                  h_on = time;
                }
              else if (time - h_on > 60000)
                {
                  // Turn off humidifier after running 1 minute
                  digitalWrite(humidi, LOW);
        //          h_off = time;
                }
              }
            }
          // Pump in humidified air
          digitalWrite(valve2, HIGH);
          delay(pumptime);   // Humidify with nitrogen
          digitalWrite(valve2, LOW);
        }
      cont = time;
      }
  }


  // Run the humidifier manually with the switch
  if (digitalRead(humcon) == HIGH)
  {
    digitalWrite(humidi, HIGH);
  }
   else if (digitalRead(humcon) == LOW && target_RH < 60)
   {
     digitalWrite(humidi, LOW);
   }
  delay(10);
}

void readWithMarkers() {

    static boolean recvInProgress = false;
    static byte ndx = 0;
    char startMarker = '<';
    char endMarker = '>';
    char rc;

    // Check if serial port is available
    if (Serial.available() > 0)
    {
      rc = Serial.read();
      // Validate if MATLAB is asking to read the value or not
    }
 // if (Serial.available() > 0) {
    while (Serial.available() > 0 && newData == false) {
        rc = Serial.read();

        if (recvInProgress == true) {
            if (rc != endMarker) {
                receivedChars[ndx] = rc;
                ndx++;
                if (ndx >= numChars) {
                    ndx = numChars - 1;
                }
            }
            else {
                receivedChars[ndx] = '\0'; // terminate the string
                recvInProgress = false;
                ndx = 0;
                newData = true;
            }
        }
        else if (rc == startMarker) {
            recvInProgress = true;
        }
    }
}

void readData() {
  if (newData == true) {
    // if received data is R send back the data
    if (receivedChars[0] == 'R')
    {
      Serial.print(mySensor.readFloatHumidity(), 2);
      Serial.print(", ");
      Serial.print(target_RH, 2);
      Serial.print(", ");
      Serial.print(mySensor.readFloatPressure() * 0.01, 2);
      Serial.print(", ");
      Serial.print(mySensor.readTempC(), 2);
      Serial.println();
      newData = false;
    }
    // if received data is CO or CF switch humidity control on or off
    else if (receivedChars[0] == 'C')
    {
      if (receivedChars[1] == 'O')
      {
          control_on = true;
          //Serial.print("control on");
          //Serial.println();
      }
      else if (receivedChars[1] == 'F')
      {
          control_on = false;
          digitalWrite(humidi, LOW); //disable humidifier
          //Serial.print("control off");
          //Serial.println();
      }
      newData = false;
    }
    // if received data is HO or HF en-/disable humidifier motor
    else if (receivedChars[0] == 'H')
    {
      if (receivedChars[1] == 'O')
      {
        digitalWrite(humidi, HIGH);
      }
      else if (receivedChars[1] == 'F')
      {
        digitalWrite(humidi, LOW);
      }
      newData = false;
    }
    // if received data is AO or AF en-/disable autosend
    else if (receivedChars[0] == 'A')
    {
      if (receivedChars[1] == 'O')
      {
        autosend = true;
      }
      else if (receivedChars[1] == 'F')
      {
        autosend = false;
        // Serial.print("autosend off");
        // Serial.println();
      }
      newData = false;
    }
    // if two numerical digits are received, change the target_RH
    else if (isdigit(receivedChars[0]) && isdigit(receivedChars[1]))
    {
      target_RH = atof(receivedChars);
      // Serial.print("New Target Humdity Set to ");
      // Serial.println(target_RH);
      newData = false;
    }
    else
    {
      newData = false;
    }
  }
}

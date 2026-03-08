import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';

import 'default.dart';
Defaults defaults = Defaults(); // Fa riferimento ai parametri in default.dart

class Globals 
{
  String deviceId=defaults.deviceId;
  bool isCollecting = defaults.isCollecting;
  bool option1 = false;
  bool option2 = false;
  bool option3 = false ;
  String measureName = defaults.measureName;
  int savedValue = 0;
  // Array di Array per salvare i valori
  List<List<double>> receivedValues = [];
  List<Map<String, dynamic>> receivedPGJsonValues = [];
  // Parametri backend
  String url = defaults.url;
  String tenantId = defaults.tenantId;
  String deviceToken = defaults.deviceToken;
  String thingName = defaults.thingName;
  String deviceName = defaults.deviceName;
  // Parametri BLE
  String bleServiceId = defaults.bleServiceId;

  String gsrCharacteristicId = defaults.gsrCharacteristicId;
  String pulseCharacteristicId = defaults.pulseCharacteristicId;

  String bpmCharacteristicId = defaults.bpmCharacteristicId;
  String tonCharacteristicId = defaults.tonCharacteristicId;
  String fasCharacteristicId = defaults.fasCharacteristicId;


  String sdrrCharacteristicId = defaults.sdrrCharacteristicId;
  String rmssdCharacteristicId = defaults.rmssdCharacteristicId;
  String pnn50CharacteristicId = defaults.pnn50CharacteristicId;

  String ctrlCharacteristicId = defaults.ctrlCharacteristicId;
  String statusCharacteristicId = defaults.statusCharacteristicId;

   // Salva l' ultimo valore per caratteristica
  final Map<String, Uint8List> lastValuesByCharacteristic = {};

  late SharedPreferences prefs; // SharedPreferences instance


  // Mappe per i nomi
  // Servizi
  final Map<String, String> serviceNames = 
  {
    "25a1cabf-b34b-4d86-8252-da0507816360":
        "Biofeedback-BLE Service",
  };

  // Caratteristiche
  final Map<String, String> characteristicNames = 
  {
    "9929a7e4-ac86-4627-891a-6f9e1f02e843":
        "GALVANIC SKIN RESPONSE SENSOR",
    "ea544b30-84a2-40ff-bf36-5281e428dbbd":
        "PULSE SENSOR",
    "f4b858bf-31a1-463c-b2d1-c9b3c68855a4":
        "BPM",
    "6f8a58a6-78c4-4802-82ea-621b342eb7a2":
        "PHASIC COMPONENT",
    "2d23cbf1-c4ea-480a-bdf7-5cd4ceb56c34":
        "TONIC COMPONENT",
    "86990b84-13ca-43ee-9002-24175cd702e4":
        "SDRR",
    "41b0ed34-3874-44e5-88ff-c5e3d36c54e3":
        "RMSSD",
    "d6c35231-fa9a-41d2-b804-e0acd10d7d37":
        "PNN50",
    '618f17cb-b111-470b-8b79-44254ca1f1d6':
        "CTRL",
    '1d268694-36cc-4b0b-b37c-fdf54cba9663':
        "STATUS",
  };

  // Stream broadcast per eventi BLE
  final StreamController<BleValueEvent> _bleValueController = StreamController<BleValueEvent>.broadcast();

  Stream<BleValueEvent> get bleValues => _bleValueController.stream;

  void emitBleValue(BleValueEvent event) 
  {
    _bleValueController.add(event);
  }
}

class BleValueEvent // Oggetto che incapsula. quale device, quale caratteristica, quale valore
{
  final String deviceId;
  final String characteristicId;
  final Uint8List value;

  BleValueEvent
  (
    {
      required this.deviceId,
      required this.characteristicId,
      required this.value,
    }
  );
}

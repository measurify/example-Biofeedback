class Defaults // Definisce classe contenitore che contiene i valori di default
{
  String deviceId='DeviceA';
  bool isCollecting = false; // Di default non stai collezionando
  bool option1 = false;
  bool option2 = false;
  bool option3 = false;
  String measureName = 'Biofeedback';
  int savedValue = 0;
  // Di default array di array vuoti
  List<List<double>> receivedValues = [];
  List<Map<String, dynamic>> receivedIMUJsonValues = [];
  // Default del backend
  String url = 'https://tracker.elioslab.net/v1/measurements/Biofeedback/timeserie'; // Endpoint base API
  String tenantId = 'Biofeedback'; // Tenant su Measurify
  // Token di autenticazione
  String deviceToken = 'DVC eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2UiOnsiX2lkIjoiRGV2aWNlQSIsImZlYXR1cmVzIjpbIkJpb2ZlZWRiYWNrIl0sInRoaW5ncyI6WyJVc2VyIl0sInZpc2liaWxpdHkiOiJwdWJsaWMiLCJvd25lciI6IjY5OGM1OGJhNGEzYmY4MDAxZWMyNTg3YSJ9LCJ0ZW5hbnQiOnsicGFzc3dvcmRoYXNoIjp0cnVlLCJfaWQiOiJCaW9mZWVkYmFjayIsIm9yZ2FuaXphdGlvbiI6Ik1lYXN1cmlmeSBvcmciLCJhZGRyZXNzIjoiTWVhc3VyaWZ5IFN0cmVldCwgR2Vub3ZhIiwiZW1haWwiOiJtYXR0ZW8uZnJlc3RhQGVkdS51bmlnZS5pdCIsInBob25lIjoiNSIsImRhdGFiYXNlIjoiQmlvZmVlZGJhY2sifSwiaWF0IjoxNzcwODA1NjM5LCJleHAiOjMzMzI4NDA1NjM5fQ.iCGm0mSHB4O_fzRPNmmAGTCEav95JaOhw5-FZjN0tfI';
  String thingName = 'User';
  String deviceName = 'DeviceA';

  String bleServiceId = '25a1cabf-b34b-4d86-8252-da0507816360';

  String gsrCharacteristicId = '9929a7e4-ac86-4627-891a-6f9e1f02e843';
  String pulseCharacteristicId = 'ea544b30-84a2-40ff-bf36-5281e428dbbd';

  String bpmCharacteristicId = "f4b858bf-31a1-463c-b2d1-c9b3c68855a4";

  String tonCharacteristicId = "2d23cbf1-c4ea-480a-bdf7-5cd4ceb56c34";
  String fasCharacteristicId = "6f8a58a6-78c4-4802-82ea-621b342eb7a2";

  String sdrrCharacteristicId = '86990b84-13ca-43ee-9002-24175cd702e4';
  String rmssdCharacteristicId = '41b0ed34-3874-44e5-88ff-c5e3d36c54e3';
  String pnn50CharacteristicId = 'd6c35231-fa9a-41d2-b804-e0acd10d7d37';


  String ctrlCharacteristicId = '618f17cb-b111-470b-8b79-44254ca1f1d6';
  String statusCharacteristicId = '1d268694-36cc-4b0b-b37c-fdf54cba9663';
}
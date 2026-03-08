import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:quick_blue/quick_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'startPage.dart';
import 'globals.dart';

String gssUuid(String code) => '0000$code-0000-1000-8000-00805f9b34fb';

final GSS_SERV__BATTERY = gssUuid('180f');
final GSS_CHAR__BATTERY_LEVEL = gssUuid('2a19');

const WOODEMI_SUFFIX = 'ba5e-f4ee-5ca1-eb1e5e4b1ce0';

const WOODEMI_SERV__COMMAND = '57444d01-$WOODEMI_SUFFIX';
const WOODEMI_CHAR__COMMAND_REQUEST = '57444e02-$WOODEMI_SUFFIX';
const WOODEMI_CHAR__COMMAND_RESPONSE = WOODEMI_CHAR__COMMAND_REQUEST;

const WOODEMI_MTU_WUART = 247;

class PeripheralDetailPage extends StatefulWidget {
  final String deviceId; // Riceve deviceId dallo scan in main.dart

  PeripheralDetailPage(this.deviceId);

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  // Globals condiviso tra pagine
  final Globals globals = Globals();

  bool isConnected = false;
  bool connecting = false;

  @override
  void initState() {
    super.initState();

    globals.deviceId = widget.deviceId;

    QuickBlue.setConnectionHandler(_handleConnectionChange);

    // VALUE HANDLER CENTRALIZZATO (UNICO)
    // Tutte le notifiche BLE vengono inoltrate allo stream globale.
    QuickBlue.setValueHandler(_handleValueChangeCentral);

    // SharedPreferences
    createSharedPreferences();
  }

  @override
  void dispose() {
    // Se questa pagina viene davvero distrutta, puoi pulire gli handler.
    // Non farlo mentre altre pagine sono ancora in uso.
    QuickBlue.setValueHandler(null);
    QuickBlue.setConnectionHandler(null);
    super.dispose();
  }

  Future<void> createSharedPreferences() async {
    globals.prefs = await SharedPreferences.getInstance();
  }

  void _handleConnectionChange(String deviceId, BlueConnectionState state) {
    print('_handleConnectionChange $deviceId, $state');
  }

  // Handler unico per i valori: inoltra allo stream globale
  void _handleValueChangeCentral(
      String deviceId, String characteristicId, Uint8List value) {
    // (opzionale) log raw hex:
    // print('_handleValueChange $deviceId, $characteristicId, ${hex.encode(value)}');

    globals.emitBleValue(
      BleValueEvent(
        deviceId: deviceId,
        characteristicId: characteristicId,
        value: value,
      ),
    );
  }

  // (Questi controller erano nel tuo file; li lascio invariati)
  final serviceUUID = TextEditingController(text: WOODEMI_SERV__COMMAND);
  final characteristicUUID =
      TextEditingController(text: WOODEMI_CHAR__COMMAND_REQUEST);
  final binaryCode = TextEditingController(
    text: hex.encode([0x01, 0x0A, 0x00, 0x00, 0x00, 0x01]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PeripheralDetailPage'),
      ),
      body: Column(
        children: [
          Row(
            // Connect e Disconnect
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                child: Text('connect'),
                onPressed: connecting
                    ? null
                    : () {
                        setState(() {
                          connecting = true;
                        });
                        QuickBlue.connect(widget.deviceId);
                        Future.delayed(Duration(seconds: 2), () {
                          setState(() {
                            isConnected = true;
                            connecting = false;
                          });
                        });
                      },
              ),
              ElevatedButton(
                child: Text('disconnect'),
                onPressed: () {
                  QuickBlue.disconnect(widget.deviceId);
                  setState(() {
                    isConnected = false;
                  });
                },
              ),
            ],
          ),
          Row(
            // Bottone per andare alla pagina successiva
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                child: Text('Go to services page'),
                onPressed: isConnected
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => startPage(globals: globals),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

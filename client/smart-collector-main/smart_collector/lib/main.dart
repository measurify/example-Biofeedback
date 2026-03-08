import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:quick_blue/quick_blue.dart';

import 'PeripheralDetailPage.dart';
import 'package:permission_handler/permission_handler.dart';

void main() 
{
  runApp(MyApp());  // Avvio widget root MyApp
}

class MyApp extends StatefulWidget // Stato dinamico
{
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> 
{
  StreamSubscription<BlueScanResult>? _subscription;  // Riceve i dispsositivi trovati

  @override
  void initState() 
  {
    super.initState();
    if (kDebugMode) 
    {
      QuickBlue.setLogger(Logger('smart_collector'));
    }

    // Ricerca dei devices e sceglie solo quelli con un nome e evita i duplicati. ogni device trovato gebera un BlueScanResult
    _subscription = QuickBlue.scanResultStream.listen((result) 
    {
      if (!_scanResults.any((r) => r.deviceId == result.deviceId)) 
      {
        if(result.name!="")
        {
          setState(() => _scanResults.add(result));
        }
      }
    });
  }

  @override
  void dispose() // Pulisce la subscription BLE e evita memory leak
  {
    super.dispose();
    _subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) // Costruisce tutta la UI
  {
    return MaterialApp(
      home: Scaffold
      (
        appBar: AppBar
        (
          title: const Text('Plugin example app'), // Barra superiore, titolo fisso
        ),
        body: Column  // Layout verticale
        (
          children: 
          [
            FutureBuilder
            (
              future: QuickBlue.isBluetoothAvailable(), // Verifica se il bluetooth è acceso
              builder: (context, snapshot) 
              {
                var available = snapshot.data?.toString() ?? '...';
                return Text('Bluetooth ON: $available');
              },
            ),
            _buildButtons(), // Creazione bottoni di scan
            Divider // Separatore visivo blu
            (
              color: Colors.blue, 
            ),
            _buildListView(), // Lista dinamica di device trovati
            _buildPermissionWarning(), // Mostra avviso e bottone con permessi mancanti
          ], // Children 
        ),
      ),
    );
  }

  Widget _buildButtons() // Start e Stop scan: chiama le funzioni di Quick Blue
  {
    return Row
    (
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>
      [
        ElevatedButton
        (
          child: Text('startScan'),
          onPressed: () 
          {
            QuickBlue.startScan();
          },
        ),
        ElevatedButton
        (
          child: Text('stopScan'),
          onPressed: () 
          {
            QuickBlue.stopScan();
          },
        ),
      ],
    );
  }

  var _scanResults = <BlueScanResult>[]; // Stato locale della scansione

  Widget _buildListView() 
  {
    return Expanded
    (
      child: ListView.separated // Lista scrollabile con separatori automatici
      (
        itemBuilder: (context, index) => ListTile // Ogni riga ha questo
        (
          title: // Nome device e potenza del segnale
          Text('${_scanResults[index].name}(${_scanResults[index].rssi})'),
          subtitle: Text(_scanResults[index].deviceId), // MAC o UUID
          onTap: () 
          {
            QuickBlue.stopScan(); // Stop scan se si clicca su un device
            Navigator.push // Passi il deviceId
            (
              context,
              MaterialPageRoute
              (
                builder: (context) =>
                PeripheralDetailPage(_scanResults[index].deviceId), // La pagina PeripheralDetailPage ottiene il deviceId del dispositivo scelto
              )
            ); // Navigator push
          }, // On tap
        ),
        separatorBuilder: (context, index) => Divider(),
        itemCount: _scanResults.length,
      ),
    );
  }

  // Bottone per i permessi
  Widget _buildPermissionWarning() 
  {
    return FutureBuilder<bool>
    (
      future: _hasBluetoothPermission(),
      builder: (context, snapshot) 
      {
        if (snapshot.hasData) 
        {
          bool hasNoPermission = !(snapshot.data!);
          if (hasNoPermission) // I permessi richiesti solo se necessario
          {
            return Container
            (
              margin: EdgeInsets.symmetric(horizontal: 10),
              child: Column
              (
                children: 
                [
                  // Text('BLUETOOTH_SCAN/ACCESS_FINE_LOCATION needed'),
                  ElevatedButton(
                    child: Text('Request Permissions'),
                    onPressed: () 
                    {
                      _requestBluetoothPermissions();
                    }, // On pressed
                  ),
                ], // Children
              ),
            );
          } // if
        } // if
        return Container();
      }, // builder
    );
  } // widget

  void _requestBluetoothPermissions() async // Richiede i permessi per android
  {
    if (Platform.isAndroid) 
    {
      List<Permission> permissions = 
      [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ];

      Map<Permission, PermissionStatus> permissionStatuses =
      await permissions.request();

      setState(() 
      {
        // Check if permissions were granted
        bool permissionsGranted = permissionStatuses.values
        .every((status) => status == PermissionStatus.granted);

        if (permissionsGranted) 
        {
          // Permissions were granted, perform necessary actions
          // For example, start scanning for Bluetooth devices
          QuickBlue.startScan();
        } else 
        {
          // Permissions were not granted, handle accordingly
          // For example, show an error message
          print('Permissions not granted.');
        }
      }); // setstate
    } // if 
  } // request bluetooth permissions

  Future<bool> _hasBluetoothPermission() async // Gestione permessi per android
  {
    bool isAndroid = Platform.isAndroid;
    bool bluetoothPermission = await hasPermission(Permission.bluetooth);
    bool bluetoothConnectPermission = await hasPermission(Permission.bluetoothConnect);
    bool bluetoothScanPermission = await hasPermission(Permission.bluetoothScan);
    bool locationPermission = await hasPermission(Permission.location);

    return isAndroid && bluetoothPermission && bluetoothConnectPermission && bluetoothScanPermission && locationPermission;
  }

  Future<bool> hasPermission(Permission permission) async 
  {
    PermissionStatus status = await permission.status;
    return status.isGranted;
  }
} // class _MyAppState

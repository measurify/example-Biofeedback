import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:quick_blue/quick_blue.dart';

import 'globals.dart';
import 'SelectedCharacteristicsPage.dart';

class startPage extends StatefulWidget {
  final Globals globals; // Riceve Globals da PeripheralDetailPage.dart
  const startPage({required this.globals, Key? key}) : super(key: key);

  @override
  State<startPage> createState() => _startPageState();
}

class _startPageState extends State<startPage> {
  final List<String> _services = [];
  final Map<String, List<String>> _characteristicsByService = {};
  final Map<String, String> _charToService = {}; // char -> service

  bool _isDiscovering = false;

  bool _showUnknownServices = false;
  bool _showUnknownCharacteristics = false;

  final Map<String, String> _selectedForCharts = <String, String>{};

  bool _isCollecting = false;

  // ---- 2-valori aggregati da 2 caratteristiche (PULSE + GSR) ----
  double? _lastPulse;
  double? _lastGsr;

  // subscription allo stream BLE globale (arriva da Globals)
  StreamSubscription<BleValueEvent>? _bleSub;

  // target “risolti” dalla discovery (non da globals.pulseCharacteristicId)
  String? _pulseCharId;
  String? _pulseServiceId;
  String? _gsrCharId;
  String? _gsrServiceId;

  // -------------------------
  // Batch sending config/state
  // -------------------------
  static const int _defaultBatchSize = 1000; // <-- cambia qui se vuoi
  int _batchSize = _defaultBatchSize;
  bool _isSendingBatch = false;

  // Mapping dei nomi
  String getServiceName(String uuid) =>
      widget.globals.serviceNames[uuid] ?? "Unknown Service";

  String getCharacteristicName(String uuid) =>
      widget.globals.characteristicNames[uuid] ?? "Unknown Characteristic";

  bool isKnownService(String uuid) =>
      widget.globals.serviceNames.containsKey(uuid);

  bool isKnownCharacteristic(String uuid) =>
      widget.globals.characteristicNames.containsKey(uuid);

  IconData getCharacteristicIcon(String charId) {
    final name = getCharacteristicName(charId);

    if (name == 'CTRL') return Icons.download;
    if (name == 'STATUS') return Icons.info_outline;

    if (name.contains('PULSE')) return Icons.monitor_heart_outlined;
    if (name.contains('BPM')) return Icons.favorite_sharp;
    if (name.contains('GALVANIC') || name.contains('GSR') || name.contains('TONIC') || name.contains('PHASIC') ) {
      return Icons.electric_bolt_sharp;
    }

    if (name == 'SDRR' || name == 'RMSSD' || name == 'PNN50') {
      return Icons.accessibility_new_outlined;
    }


    return Icons.sensors;
  }

  // Liste dei servizi conosciuti e sconosciuti
  List<String> get _servicesToShow {
    final list = List<String>.from(_services);
    list.sort((a, b) {
      final ak = isKnownService(a);
      final bk = isKnownService(b);
      if (ak != bk) return ak ? -1 : 1;
      return a.compareTo(b);
    });
    if (_showUnknownServices) return list;
    return list.where(isKnownService).toList();
  }

  int get _hiddenServicesCount =>
      _services.where((s) => !isKnownService(s)).length;

  @override
  void initState() {
    super.initState();

    // NON settiamo QuickBlue.setValueHandler qui.
    // Ascoltiamo solo lo stream globale che viene popolato da PeripheralDetailPage.
    _bleSub = widget.globals.bleValues.listen((event) {
      if (event.deviceId != widget.globals.deviceId) return;
      _onBleEvent(event.characteristicId, event.value);
    });

    // Service discovery per popolare la UI
    QuickBlue.setServiceHandler(_handleServiceDiscovery);

    _discoverServices();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    QuickBlue.setServiceHandler(null);
    super.dispose();
  }

  // -------------------------
  // DOPPIO PARSING (Pulse/Gsr)
  // -------------------------
  double? _parsePulse(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final bd = ByteData.sublistView(bytes);

    if (bytes.length == 8) return bd.getFloat64(0, Endian.little);
    if (bytes.length == 4) return bd.getFloat32(0, Endian.little);
    if (bytes.length == 2) return bd.getInt16(0, Endian.little).toDouble();
    if (bytes.length == 1) return bytes[0].toDouble();

    return null;
  }

  double? _parseGsr(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final bd = ByteData.sublistView(bytes);

    if (bytes.length == 8) return bd.getFloat64(0, Endian.little);
    if (bytes.length == 4) return bd.getFloat32(0, Endian.little);
    if (bytes.length == 2) return bd.getInt16(0, Endian.little).toDouble();
    if (bytes.length == 1) return bytes[0].toDouble();

    return null;
  }

  // -------------------------
  // Resolve target char/service
  // -------------------------
  void _resolveTargetsFromDiscovery() {
    String? p;
    String? g;

    for (final entry in _charToService.entries) {
      final charId = entry.key;
      final name = getCharacteristicName(charId).toUpperCase();

      if (p == null && name.contains('PULSE')) p = charId;

      if (g == null && (name.contains('GALVANIC') || name.contains('GSR'))) {
        g = charId;
      }
    }

    _pulseCharId = p;
    _gsrCharId = g;

    _pulseServiceId = (p == null) ? null : _charToService[p];
    _gsrServiceId = (g == null) ? null : _charToService[g];

    print(
      'Resolved: PULSE=$_pulseCharId svc=$_pulseServiceId | GSR=$_gsrCharId svc=$_gsrServiceId',
    );
  }

  // Scoperta servizi
  void _discoverServices() {
    setState(() {
      _services.clear();
      _characteristicsByService.clear();
      _charToService.clear();
      _isDiscovering = true;

      // reset anche target risolti
      _pulseCharId = null;
      _pulseServiceId = null;
      _gsrCharId = null;
      _gsrServiceId = null;
    });

    QuickBlue.discoverServices(widget.globals.deviceId);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _isDiscovering = false);
    });
  }

  void _handleServiceDiscovery(
      String deviceId, String serviceId, List<String> characteristicIds) {
    if (deviceId != widget.globals.deviceId) return;

    setState(() {
      if (!_services.contains(serviceId)) _services.add(serviceId);
      _characteristicsByService[serviceId] = characteristicIds;

      for (final c in characteristicIds) {
        _charToService[c] = serviceId;
      }
    });

    // ogni volta che arriva discovery, provo a risolvere
    _resolveTargetsFromDiscovery();
  }

  // -------------------------
  // Batch sending logic
  // -------------------------
  void _maybeSendBatch() {
    if (_isSendingBatch) return;
    if (widget.globals.receivedPGJsonValues.length < _batchSize) return;

    // fire-and-forget (gestisce concorrenza internamente)
    _sendBatch(flushAll: false);
  }

  Future<void> _sendBatch({required bool flushAll}) async {
    if (_isSendingBatch) return;

    final g = widget.globals;
    if (g.receivedPGJsonValues.isEmpty) return;

    // Determina quanti inviare
    final int n = flushAll
        ? g.receivedPGJsonValues.length
        : (_batchSize <= g.receivedPGJsonValues.length
            ? _batchSize
            : 0);

    if (n == 0) return;

    _isSendingBatch = true;

    // Congela il batch e rimuovilo subito dal buffer
    final batch = g.receivedPGJsonValues.take(n).toList();
    g.receivedPGJsonValues.removeRange(0, n);

    final endpoint = Uri.parse(widget.globals.url);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': g.deviceToken,
    };

    try {
      final response =
          await http.post(endpoint, headers: headers, body: jsonEncode(batch));

      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;

      if (!ok) {
        // reinserisco il batch IN TESTA per non perdere campioni
        g.receivedPGJsonValues.insertAll(0, batch);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Errore invio (${response.statusCode}): '
                '${response.body.isNotEmpty ? response.body : (response.reasonPhrase ?? 'Unknown error')}',
              ),
            ),
          );
        }
      } else {
        // opzionale: feedback solo su flush o ogni tot
        if (mounted && flushAll) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Inviati ${batch.length} campioni.')),
          );
        }
      }
    } catch (e) {
      // errore rete: rimetti il batch in testa
      g.receivedPGJsonValues.insertAll(0, batch);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore rete: $e")),
        );
      }
    } finally {
      _isSendingBatch = false;

      // Se nel frattempo ho accumulato abbastanza campioni, invio ancora
      if (mounted && !flushAll) {
        _maybeSendBatch();
      }
    }
  }

  Future<void> _flushRemaining() async {
    await _sendBatch(flushAll: true);
  }

  // -------------------------
  // BLE event handler (stream)
  // -------------------------
  void _onBleEvent(String characteristicId, Uint8List value) {
    if (!_isCollecting) return;

    // cache raw
    widget.globals.lastValuesByCharacteristic[characteristicId] = value;

    // se non ho ancora risolto i target, non posso aggregare
    if (_pulseCharId == null || _gsrCharId == null) return;

    if (characteristicId == _pulseCharId) {
      final parsedPulse = _parsePulse(value);
      if (parsedPulse == null) return;
      _lastPulse = parsedPulse;
    } else if (characteristicId == _gsrCharId) {
      final parsedGsr = _parseGsr(value);
      if (parsedGsr == null) return;
      _lastGsr = parsedGsr;
    } else {
      return;
    }

    // Creo una misurazione ad ogni notifica, ma solo dopo che ho entrambi
    if (_lastPulse != null && _lastGsr != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final jsonObj = <String, dynamic>{
        "timestamp": nowMs, // <-- timestamp in ms (int)
        "values": [_lastPulse, _lastGsr],
      };

      widget.globals.receivedPGJsonValues.add(jsonObj);

      // Invio automatico quando raggiungo batchSize
      _maybeSendBatch();
    }
  }

  // Selezione delle caratteristiche per poi vedere i grafici
  void _setSelectedForCharts(String serviceId, String charId, bool selected) {
    setState(() {
      if (selected) {
        _selectedForCharts[charId] = serviceId;
      } else {
        _selectedForCharts.remove(charId);
      }
    });
  }

  // Gestione dati da Arduino
  bool _isControlChar(String charId) => charId == widget.globals.ctrlCharacteristicId;
  bool _isStatusChar(String charId) => charId == widget.globals.statusCharacteristicId;

  Future<void> _startCollectingAll() async {
    if (_charToService.isEmpty) return;

    _lastPulse = null;
    _lastGsr = null;

    // risolvo target “veri” (PULSE/GSR) basandosi su discovery+nomi
    _resolveTargetsFromDiscovery();

    // START su CTRL (0x01) usando service corretto (se lo conosco)
    final ctrlChar = widget.globals.ctrlCharacteristicId;
    final ctrlService = _charToService[ctrlChar];

    final startCmd = Uint8List.fromList([0x01]);
    if (ctrlChar.isNotEmpty && ctrlService != null) {
      try {
        QuickBlue.writeValue(
          widget.globals.deviceId,
          ctrlService,
          ctrlChar,
          startCmd,
          BleOutputProperty.withResponse,
        );
      } catch (_) {}
    }

    // Notify su STATUS usando service corretto (se lo conosco)
    final statusChar = widget.globals.statusCharacteristicId;
    final statusService = _charToService[statusChar];

    if (statusChar.isNotEmpty && statusService != null) {
      try {
        QuickBlue.setNotifiable(
          widget.globals.deviceId,
          statusService,
          statusChar,
          BleInputProperty.notification,
        );
      } catch (_) {}
    }

    // piccolo delay per stabilizzare (come avevi già fatto)
    await Future.delayed(const Duration(milliseconds: 150));

    if (_pulseCharId != null && _pulseServiceId != null) {
      try {
        QuickBlue.setNotifiable(
          widget.globals.deviceId,
          _pulseServiceId!,
          _pulseCharId!,
          BleInputProperty.notification,
        );
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 150));

    if (_gsrCharId != null && _gsrServiceId != null) {
      try {
        QuickBlue.setNotifiable(
          widget.globals.deviceId,
          _gsrServiceId!,
          _gsrCharId!,
          BleInputProperty.notification,
        );
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

  final bpmHrvChars = [
    widget.globals.bpmCharacteristicId,
    widget.globals.sdrrCharacteristicId,
    widget.globals.rmssdCharacteristicId,
    widget.globals.pnn50CharacteristicId,
  ];

  for (final charId in bpmHrvChars) {
    if (charId.isEmpty) continue;
    
    final service = _charToService[charId];
    if (service == null) {
      debugPrint('BPM/HRV char $charId not found in discovery!');
      continue;
    }

    debugPrint('Enabling BPM/HRV: $charId');
    try {
      QuickBlue.setNotifiable(
        widget.globals.deviceId,
        service,
        charId,
        BleInputProperty.notification,
      );
      debugPrint('Enabled');
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
  }
    await Future.delayed(const Duration(milliseconds: 150));

  final gsrComponentChars = [
    widget.globals.tonCharacteristicId,
    widget.globals.fasCharacteristicId,
  ];

  for (final charId in gsrComponentChars) {
    if (charId.isEmpty) continue;
    
    final service = _charToService[charId];
    if (service == null) {
      debugPrint('GSR component char $charId not found in discovery!');
      continue;
    }

    debugPrint('Enabling GSR component: $charId');
    try {
      QuickBlue.setNotifiable(
        widget.globals.deviceId,
        service,
        charId,
        BleInputProperty.notification,
      );
      debugPrint('Enabled');
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
  }
    }

    setState(() {
      _isCollecting = true;
      widget.globals.isCollecting = true;
    });
  }

  Future<void> _stopCollectingAll() async {
    // STOP su CTRL (0x02)
    final ctrlChar = widget.globals.ctrlCharacteristicId;
    final ctrlService = _charToService[ctrlChar];

    final stopCmd = Uint8List.fromList([0x02]);
    if (ctrlChar.isNotEmpty && ctrlService != null) {
      try {
        QuickBlue.writeValue(
          widget.globals.deviceId,
          ctrlService,
          ctrlChar,
          stopCmd,
          BleOutputProperty.withResponse,
        );
      } catch (_) {}
    }

    _lastPulse = null;
    _lastGsr = null;

    setState(() {
      _isCollecting = false;
      widget.globals.isCollecting = false;
    });

    // flush finale: invia anche se < batchSize
    await _flushRemaining();
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = widget.globals.deviceId;
    final servicesToShow = _servicesToShow;

    final canGoSelected = _selectedForCharts.isNotEmpty;
    final canObtain = !_isCollecting && _charToService.isNotEmpty;
    final canStop = _isCollecting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'toggle_unknown_services') {
                  _showUnknownServices = !_showUnknownServices;
                } else if (value == 'toggle_unknown_chars') {
                  _showUnknownCharacteristics = !_showUnknownCharacteristics;
                } else if (value == 'clear_selection') {
                  _selectedForCharts.clear();
                }
              });
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String>(
                value: 'toggle_unknown_services',
                checked: _showUnknownServices,
                child: const Text('Show unknown services'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'toggle_unknown_chars',
                checked: _showUnknownCharacteristics,
                child: const Text('Show unknown characteristics'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'clear_selection',
                child: Text('Clear chart selection'),
              ),
            ],
          ),
          IconButton(
            onPressed: _discoverServices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Connected device:'),
            subtitle: Text(deviceId),
            trailing: ElevatedButton(
              onPressed: canGoSelected
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SelectedCharacteristicsPage(
                            globals: widget.globals,
                            selected: Map<String, String>.from(_selectedForCharts),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Text('Selected (${_selectedForCharts.length})'),
            ),
          ),
          if (!_showUnknownServices && _hiddenServicesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unknown services hidden: $_hiddenServicesCount',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (_isDiscovering)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Discovering services...'),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: servicesToShow.isEmpty
                ? const Center(child: Text('No services found yet. Tap refresh.'))
                : ListView.builder(
                    itemCount: servicesToShow.length,
                    itemBuilder: (context, index) {
                      final serviceId = servicesToShow[index];
                      final allChars =
                          _characteristicsByService[serviceId] ?? const [];
                      final charsToShow = _showUnknownCharacteristics
                          ? allChars
                          : allChars.where(isKnownCharacteristic).toList();

                      return ExpansionTile(
                        leading: Icon(
                          isKnownService(serviceId)
                              ? Icons.bluetooth
                              : Icons.question_mark,
                        ),
                        title: Text(getServiceName(serviceId)),
                        children: [
                          for (final charId in charsToShow)
                            Builder(builder: (context) {
                              final subtitleLines = <Widget>[
                                if (_isControlChar(charId))
                                  const Text(
                                    'Comando per Arduino',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                if (_isStatusChar(charId))
                                  const Text(
                                    'Status di Arduino',
                                    style: TextStyle(fontSize: 12),
                                  ),
                              ];

                              return CheckboxListTile(
                                value: _selectedForCharts.containsKey(charId),
                                onChanged: (v) {
                                  if (v == null) return;
                                  _setSelectedForCharts(serviceId, charId, v);
                                },
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                secondary: Icon(getCharacteristicIcon(charId)),
                                title: Text(getCharacteristicName(charId)),
                                subtitle: subtitleLines.isEmpty
                                    ? null
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: subtitleLines,
                                      ),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              );
                            }),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canObtain
                    ? _startCollectingAll
                    : (canStop ? _stopCollectingAll : null),
                child: Text(
                  _isCollecting
                      ? 'Stop collecting'
                      : 'Obtain all data (batch=$_defaultBatchSize)',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

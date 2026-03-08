import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quick_blue/quick_blue.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/services.dart';

import 'globals.dart';

class _ChartPoint {
  final DateTime t;
  final double v;
  _ChartPoint(this.t, this.v);
}

class ChartCartesianPage extends StatefulWidget {
  final Globals globals;
  final String serviceId;
  final String characteristicId;
  final String title;

    // lista di characteristic da mostrare (se null -> default: [characteristicId])
  final List<String>? chartCharacteristicIds;

  const ChartCartesianPage({
    Key? key,
    required this.globals,
    required this.serviceId,
    required this.characteristicId,
    required this.title,
    this.chartCharacteristicIds, // aggiunta nuova come sopra ..  . .
  }) : super(key: key);

  @override
  State<ChartCartesianPage> createState() => _ChartCartesianPageState();
}

class _ChartCartesianPageState extends State<ChartCartesianPage>
    with SingleTickerProviderStateMixin {
  // Serie multiple
  final Map<String, List<_ChartPoint>> _pointsByChar = <String, List<_ChartPoint>>{};
  final Map<String, ChartSeriesController> _seriesControllersByChar =
      <String, ChartSeriesController>{};

  late final List<String> _chartCharacteristicIds; // sempre lowercase

  StreamSubscription<BleValueEvent>? _sub;
  bool _notifying = false;

  // Orientamento
  bool _isLandscape = false;

  // HRV
  double? _sdrr;
  double? _rmssd;
  double? _pnn50;

  // BPM + cuore
  int? _bpm;
  AnimationController? _heartCtrl;
  late Animation<double> _heartScale;

  // --- Helpers normalize ---
  String _norm(String s) => s.trim().toLowerCase();

  String get _selectedCharId => _norm(widget.characteristicId);
  String get _serviceId => _norm(widget.serviceId);

  String _charName(String charId) =>
      widget.globals.characteristicNames[_norm(charId)] ?? '';

  bool get _isPulseChart {
    final name = _charName(_selectedCharId).toUpperCase();
    return name.contains('PULSE');
  }

  /// FIX: Non basarti sull’uguaglianza UUID (case/format mismatch).
  /// Se la characteristic selezionata è GSR (dal nome), abilita multi-serie.
  bool get _isGsrChart {
    final name = _charName(_selectedCharId).toUpperCase();
    return name.contains('GALVANIC') || name.contains('GSR');
  }

  bool _isHrvChar(String id) {
    final c = _norm(id);
    return c == _norm(widget.globals.sdrrCharacteristicId) ||
        c == _norm(widget.globals.rmssdCharacteristicId) ||
        c == _norm(widget.globals.pnn50CharacteristicId);
  }

  Future<void> _toggleOrientation() async {
    _isLandscape = !_isLandscape;
    if (_isLandscape) {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    } else {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

      debugPrint('=== CHART INIT ===');
      debugPrint('Selected charId: $_selectedCharId');
      debugPrint('Char name: ${_charName(_selectedCharId)}');
      debugPrint('_isPulseChart: $_isPulseChart');
      debugPrint('==================');

      if (_isPulseChart) {
  debugPrint('--- BPM/HRV UUIDs from globals (normalized): ---');
  debugPrint('BPM: ${_norm(widget.globals.bpmCharacteristicId)}');
  debugPrint('SDRR: ${_norm(widget.globals.sdrrCharacteristicId)}');
  debugPrint('RMSSD: ${_norm(widget.globals.rmssdCharacteristicId)}');
  debugPrint('PNN50: ${_norm(widget.globals.pnn50CharacteristicId)}');
}
debugPrint('==================');


    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _heartScale = Tween<double>(begin: 0.90, end: 1.15).animate(
      CurvedAnimation(parent: _heartCtrl!, curve: Curves.easeInOut),
    );

    // --- Decide quali serie mostrare ---
    // FIX: serie multiple per GSR usando ID normalizzati
    _chartCharacteristicIds = _isGsrChart
        ? <String>[
            _norm(widget.globals.gsrCharacteristicId),
            _norm(widget.globals.tonCharacteristicId),
            _norm(widget.globals.fasCharacteristicId),
          ]
        : <String>[_selectedCharId];

    // Inizializza buffer serie
    for (final id in _chartCharacteristicIds) {
      if (id.isEmpty) continue;
      _pointsByChar[id] = <_ChartPoint>[];
    }

    // Debug (puoi togliere dopo)
    // print('Chart ids = $_chartCharacteristicIds  (isGsr=$_isGsrChart)');

    // Stream BLE globale
    _sub = widget.globals.bleValues.listen((event) {
      if (event.deviceId != widget.globals.deviceId) return;

      // FIX: normalizza l’id evento (case mismatch)
      final ch = _norm(event.characteristicId);

      print('📨 BLE event received: char=$ch (original=${event.characteristicId})');

      final value = _parseToDouble(event.value);
if (value == null) return;

debugPrint('📨 BLE event: ch=$ch, value=$value');
debugPrint('   Is in pointsByChar? ${_pointsByChar.containsKey(ch)}');
debugPrint('   Is HRV? ${_isHrvChar(ch)}');
debugPrint('   Is BPM? ${ch == _norm(widget.globals.bpmCharacteristicId)}');

      // A) Aggiorna serie grafiche
      if (_pointsByChar.containsKey(ch)) {
        final now = DateTime.now();
        final seriesPoints = _pointsByChar[ch]!;
        seriesPoints.add(_ChartPoint(now, value));

        int? removedIndex;
        if (seriesPoints.length > 300) {
          seriesPoints.removeAt(0);
          removedIndex = 0;
        }

        final ctrl = _seriesControllersByChar[ch];
        if (ctrl != null) {
          final addedIndex = seriesPoints.length - 1;
          if (removedIndex != null) {
            ctrl.updateDataSource(
              addedDataIndex: addedIndex,
              removedDataIndex: removedIndex,
            );
          } else {
            ctrl.updateDataSource(addedDataIndex: addedIndex);
          }
        }

        if (!mounted) return;
        setState(() {});
        return;
      }

      // B) Se sto guardando PULSE, aggiorno HRV e BPM live
      if (_isPulseChart) {
        if (_isHrvChar(ch)) {
          print('HRV char detected: $ch, value=$value');
          if (!mounted) return;
          setState(() {
            if (ch == _norm(widget.globals.sdrrCharacteristicId)) {
              _sdrr = value;
              print('SDRR updated: $_sdrr');
            } else if (ch == _norm(widget.globals.rmssdCharacteristicId)) {
              _rmssd = value;
              print('RMSSD updated: $_rmssd');
            } else if (ch == _norm(widget.globals.pnn50CharacteristicId)) {
              _pnn50 = value;
              print('PNN50 updated: $_pnn50');
            }
          });
          return;
        }

        if (ch == _norm(widget.globals.bpmCharacteristicId)) {
          print('BPM char detected: $ch, value=${value.round()}');
          _setBpm(value.round());
          
          return;
        }
      }
    });

    // Abilita notifiche quando entri
    _setNotify(true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _setNotify(false);

    _heartCtrl?.dispose();

    // Ripristina portrait
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );

    super.dispose();
  }

  void _setNotify(bool enabled) {
      print('_setNotify called: enabled=$enabled, _isPulseChart=$_isPulseChart');
      print('_serviceId (normalized) = $_serviceId');
    try {
      for (final charId in _chartCharacteristicIds) {
        if (charId.isEmpty) continue;
        print('Setting notify on CHART char: service=$_serviceId, char=$charId');
        try {
          QuickBlue.setNotifiable(
            widget.globals.deviceId,
            _serviceId,
            charId,
            enabled ? BleInputProperty.notification : BleInputProperty.disabled,
          );
          print('Notify set successfully for $charId');
        } catch (_) {
          print('ERROR setting notify for $charId');
        }
      }

      // Se sto guardando PULSE, abilito/disabilito anche BPM+HRV (sempre stesso service)
      if (_isPulseChart) {
        final extraChars = <String>[
          _norm(widget.globals.bpmCharacteristicId),
          _norm(widget.globals.sdrrCharacteristicId),
          _norm(widget.globals.rmssdCharacteristicId),
          _norm(widget.globals.pnn50CharacteristicId),
        ];
         print('Enabling extra chars for PULSE (BPM+HRV): $extraChars');
        for (final charId in extraChars) {
          if (charId.isEmpty) continue;
          print('Setting notify on EXTRA char: service=$_serviceId, char=$charId');
          try {
            QuickBlue.setNotifiable(
              widget.globals.deviceId,
              _serviceId,
              charId,
              enabled ? BleInputProperty.notification : BleInputProperty.disabled,
            );
            print('Notify set successfully for EXTRA $charId');
          } catch (_) {
            print('ERROR setting notify for EXTRA $charId');
          }
        }
      }

      if (!mounted) return;
      setState(() => _notifying = enabled);
    } catch (_) {
          print('OUTER ERROR in _setNotify:');
    }
  }

  void _setBpm(int bpm) {
    final clamped = bpm.clamp(30, 220);

    if (_bpm == clamped) return;
    _bpm = clamped;

    final halfBeatMs = (60000 / clamped / 2).round();
    _heartCtrl!.duration = Duration(milliseconds: halfBeatMs);

    _heartCtrl!
      ..stop()
      ..reset()
      ..repeat(reverse: true);

    if (mounted) setState(() {});
  }

  // Parser generico (come il tuo)
  double? _parseToDouble(Uint8List bytes) {
    if (bytes.isEmpty) return null;

    final bd = ByteData.sublistView(bytes);
    if (bytes.length == 8) return bd.getFloat64(0, Endian.little);
    if (bytes.length == 4) return bd.getFloat32(0, Endian.little);
    if (bytes.length == 2) return bd.getInt16(0, Endian.little).toDouble();
    if (bytes.length == 1) return bytes[0].toDouble();

    return null;
  }

  Widget _buildChart() {
    final hasAnyData = _pointsByChar.values.any((p) => p.isNotEmpty);
    if (!hasAnyData) {
      return const Center(child: Text('No data yet. Waiting for notifications...'));
    }

    final series = <LineSeries<_ChartPoint, DateTime>>[];

    for (final charId in _chartCharacteristicIds) {
      final pts = _pointsByChar[charId] ?? const <_ChartPoint>[];
      if (pts.isEmpty) continue;

      final seriesName =
          widget.globals.characteristicNames[charId] ?? widget.globals.characteristicNames[charId.toLowerCase()] ?? charId;

      series.add(
        LineSeries<_ChartPoint, DateTime>(
          name: seriesName,
          dataSource: pts,
          xValueMapper: (_ChartPoint p, _) => p.t,
          yValueMapper: (_ChartPoint p, _) => p.v,
          onRendererCreated: (controller) => _seriesControllersByChar[charId] = controller,
        ),
      );
    }

    return SfCartesianChart(
      legend: Legend(isVisible: series.length > 1),
      primaryXAxis: DateTimeAxis(
        autoScrollingMode: AutoScrollingMode.end,
        autoScrollingDelta: 2,
        autoScrollingDeltaType: DateTimeIntervalType.seconds,
        intervalType: DateTimeIntervalType.seconds,
      ),
      primaryYAxis: NumericAxis(),
      series: series,
    );
  }

  Widget _buildHrvPanel() {
  String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HRV metrics:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('SDRR:'), Text(fmt(_sdrr))],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('RMSSD:'), Text(fmt(_rmssd))],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('PNN50:'), Text(fmt(_pnn50))],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmPanel() {
    final bpmText = (_bpm == null) ? '—' : '$_bpm';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('BPM:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ScaleTransition(
              scale: _heartScale,
              child: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 56,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              bpmText,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartWidget = _buildChart();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(widget.title)],
        ),
        actions: [
          IconButton(
            tooltip: _isLandscape ? 'Portrait' : 'Landscape',
            icon: Icon(_isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: _notifying ? 'Stop notify' : 'Start notify',
            icon: Icon(_notifying ? Icons.stop_circle_outlined : Icons.play_arrow),
            onPressed: () => _setNotify(!_notifying),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _isPulseChart
            ? Column(
                children: [
                  Expanded(child: chartWidget),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildHrvPanel()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildBpmPanel()),
                    ],
                  ),
                ],
              )
            : chartWidget,
      ),
    );
  }
}

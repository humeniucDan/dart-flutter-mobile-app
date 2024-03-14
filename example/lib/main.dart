import 'dart:ffi';

import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _bluetoothClassicPlugin = BluetoothClassic();
  List<Device> _devices = [];
  List<Device> _discoveredDevices = [];
  bool _scanning = false;
  int _deviceStatus = Device.disconnected;
  Uint8List _data = Uint8List(100);
  // Uint8List _allData = Uint8List(0);
  static const int bufferSize = 50, sensNr = 5;
  List<int> _allData = List.empty(growable: true), showVals = List.generate(sensNr, (index) => 0), dangerVals = [200, 150, 675, 200, 0];
  int position = 0, dataToShow = 0, co = 0, ch4 = 0, alch = 0, fs1 = 0, fs2 = 0, curSens = 0, curVal = 0;
  double data = 0;
  Device? arduModule;
  List<List<int>> _lastSecVals = List.generate(sensNr, (index) => List.generate(bufferSize, (index) => 0));
  bool haveToParseNr = false, percent = false;
  static const Color neutColor = Colors.lightBlue, warnColor = Colors.red;
  List<Color> curCols = List<Color>.generate(5, (index) => neutColor);

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _bluetoothClassicPlugin.initPermissions();
    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((event) {
      setState(() {
        _deviceStatus = event;
      });
    });
    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      setState(() {
        Uint8List _curData = Uint8List(0);
        _curData = Uint8List.fromList([..._curData, ...event]);

        for(int i = 0; i < _curData.length; i++){
          if(_curData[i] == 13) {
            haveToParseNr = true;
            break;
          }
          _allData.add(_curData[i]);
        }

        if(haveToParseNr){
          haveToParseNr = false;

          curSens = _allData[0]-48;
          curVal = valFromStr(_allData);
          // log('$_allData');
          _allData.clear();
          // log('$_allData');

          showVals[curSens] = curVal;

          log('$showVals');
          position = (position+1) % bufferSize;

          // showVals[2] = 300;
          // for(int i = 0; i < dangerVals.length; i++) {
          //   if(showVals[i] > dangerVals[i]) {
          //     curCols[i] = warnColor;
          //   } else {
          //     curCols[i] = warnColor;
          //   }
          // }
          co = showVals[0];
          ch4 = showVals[1];
          alch = showVals[2];
          fs1 = showVals[3];
          fs2 = showVals[4];

          for(int i = 0; i < showVals.length; i++) {
            if(showVals[i] > dangerVals[i]) {
              curCols[i] = warnColor;
            } else {
              curCols[i] = neutColor;
            }
          }

          // if(procent){
          //   co = (showVals[0] - freeTerm[0]
          // }
        }

      });
    });
  }

  int valFromStr(List<int> str){
    int v = 0;

    for(int i = 1; i < str.length; i++){
      v = v * 10 + str[i] - 48;
    }

    return v;
  }

  int avg(List<int> a){
    int m = 0;
    for(int i = 0; i < a.length; i++){
      m += a[i];
    }
    m = m ~/ bufferSize;

    return m;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _bluetoothClassicPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return
        setState(() {
          _platformVersion = platformVersion;
        });
    }
  }

  Future<void> _getDevices() async {
    var res = await _bluetoothClassicPlugin.getPairedDevices();
    setState(() async {
      for(int i = 0; i < res.length; i++){
        if(res[i].name == "HC-06") {
          // _devices.add(res[i]);
          // arduModule = res[i];
          await _bluetoothClassicPlugin.connect(res[i].address,
                "00001101-0000-1000-8000-00805f9b34fb");
            setState(() {
              _discoveredDevices = [];
              _devices = [];
            });
        }
      }

      //_devices = res;
    });
  }

  Future<void> _scan() async {
    if (_scanning) {
      await _bluetoothClassicPlugin.stopScan();
      setState(() {
        _scanning = false;
      });
    } else {
      await _bluetoothClassicPlugin.startScan();
      _bluetoothClassicPlugin.onDeviceDiscovered().listen(
        (event) {
          setState(() {
            _discoveredDevices = [..._discoveredDevices, event];
          });
        },
      );
      setState(() {
        _scanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('METRICS'),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                  Text("Stat: $_deviceStatus"),
                  TextButton(
                    onPressed: () async {
                      await _bluetoothClassicPlugin.initPermissions();
                    },
                    child: const Text("Allow"),
                  ),
                  TextButton(
                    onPressed: _getDevices,
                    child: const Text("Connect"),
                  ),
                  ...[
                    for (var device in _devices)
                      TextButton(
                          onPressed: () async {
                            await _bluetoothClassicPlugin.connect(device.address,
                                "00001101-0000-1000-8000-00805f9b34fb");
                            setState(() {
                              _discoveredDevices = [];
                              _devices = [];
                            });
                          },
                          child: Text(device.name ?? device.address))
                  ],
                ]
              ),
              Column(
                // mainAxisSize: MainAxisSize.max,
                // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    padding: const EdgeInsets.all(5.0),
                    color: curCols[0],
                    child: Row(children: [
                      Image.asset('assets/butane.png', scale: 5),
                      Text('$co', textAlign: TextAlign.center, style: TextStyle(fontSize: 30),),
                    ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    padding: const EdgeInsets.all(5.0),
                    color: curCols[1],
                    child: Row( children:[
                      Image.asset('assets/methane.png', scale: 5),
                      Text('$ch4', textAlign: TextAlign.center, style: TextStyle(fontSize: 30),),
                    ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    padding: const EdgeInsets.all(5.0),
                    color: curCols[2],
                    child: Row( children: [
                      Image.asset('assets/ethanol.png', scale: 5),
                      Text('$alch', textAlign: TextAlign.center, style: TextStyle(fontSize: 30),),
                    ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    padding: const EdgeInsets.all(5),
                    color: curCols[3],
                    child: Row( children: [
                      Image.asset('assets/deathly-subs.png', scale: 5),
                      Text('$fs1', textAlign: TextAlign.center, style: TextStyle(fontSize: 30),),
                    ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

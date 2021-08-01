import 'dart:developer';
import 'dart:io';

import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool startedBroadcast = false;
  bool startedScanning = false;

  static const String uuid = '39ED98FF-2900-441A-802F-9C398FC199D2';
  static const int majorId = 1;
  static const int minorId = 100;
  static const int transmissionPower = -59;
  static const String identifier = 'com.example.myDeviceRegion';
  static const AdvertiseMode advertiseMode = AdvertiseMode.lowPower;
  static const int manufacturerId = 0x0118;
  static const List<int> extraData = [100];
  BeaconBroadcast beaconBroadcast = BeaconBroadcast();

  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<String> items = [];

  @override
  void initState() {
    super.initState();
    initBroadcaster();
  }

  void initBroadcaster() async {
    await flutterBeacon.initializeAndCheckScanning;
    await flutterBeacon
        .setLocationAuthorizationTypeDefault(AuthorizationStatus.always);
  }

  void startBroadcast() async {
    flutterBeacon.startBroadcast(BeaconBroadcast(
        proximityUUID: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E1",
        major: 1,
        minor: 100));
    setState(() {
      startedBroadcast = true;
    });
  }

  void stopBroadcast() async {
    flutterBeacon.stopBroadcast();
    setState(() {
      startedBroadcast = false;
    });
  }

  void startScanning() async {
    flutterBlue.startScan(timeout: Duration(seconds: 20));
    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        print('${r.device.name} found! rssi: ${r.rssi}');
        if (!items.contains(r.device.name)) {
          items.add(r.device.name);
        }
      }
      setState(() {
        startedScanning = true;
      });
    });
  }

  void stopScanning() async {
    flutterBlue.stopScan();
    setState(() {
      startedScanning = false;
      items = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: startScanning, child: Text('Start scanning')),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: stopScanning, child: Text('Stop scanning')),
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: startBroadcast,
                      child: Text('Start broadcast')),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: stopBroadcast,
                        child: Text('Stop broadcast')),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${startedScanning ? 'Scanning' : 'Not Scanning'}",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  Text(
                    "${startedBroadcast ? 'Broadcasting' : 'Not Broadcasting'}",
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              ...items.map((e) => Text(e))
            ],
          ),
        ),
      ),
    );
  }
}

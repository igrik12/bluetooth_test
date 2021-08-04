import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue/flutter_blue.dart';

void onStart() {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();
  service.onDataReceived.listen((event) {
    print(event);
    if (event!["action"] == "setAsForeground") {
      service.setForegroundMode(true);
      return;
    }

    if (event["action"] == "setAsBackground") {
      service.setForegroundMode(false);
    }

    if (event["action"] == "stopService") {
      service.stopBackgroundService();
    }
  });

  // bring to foreground
  service.setForegroundMode(true);
  Timer.periodic(Duration(seconds: 1), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "My App Service",
      content: "Updated at ${DateTime.now()}",
    );

    service.sendData(
      {"current_date": DateTime.now().toIso8601String()},
    );
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FlutterBackgroundService.initialize(onStart);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wave Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Wave Home Page'),
    );
  }
}

FirebaseFirestore firestore = FirebaseFirestore.instance;

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool startedBroadcast = false;
  bool startedScanning = false;
  var isRunning = false;
  List<String> _results = [];
  final StreamController<String> beaconEventsController =
      StreamController<String>.broadcast();
  final ScrollController _scrollController = ScrollController();

  String uuid = 'unknown';
  CollectionReference users = FirebaseFirestore.instance.collection('users');
  static const int majorId = 1;
  static const int minorId = 100;
  static const int transmissionPower = -59;
  static const String identifier = 'com.example.myDeviceRegion';
  static const AdvertiseMode advertiseMode = AdvertiseMode.balanced;
  static const String layout = BeaconBroadcast.ALTBEACON_LAYOUT;
  static const int manufacturerId = 0x0118;
  static const List<int> extraData = [100];

  BeaconBroadcast beaconBroadcast = BeaconBroadcast();

  BeaconStatus _isTransmissionSupported = BeaconStatus.notSupportedBle;
  bool _isAdvertising = false;

  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<String> items = [];
  String text = "Stop Service";

  String _beaconResult = 'Not Scanned Yet.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    initPlatformState();
    initBroadcaster();
    getUserId(email: "blob@blob.com").then((id) => setState(() {
          uuid = id;
        }));
  }

  @override
  void dispose() {
    beaconEventsController.close();
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  void initBroadcaster() async {
    beaconBroadcast
        .checkTransmissionSupported()
        .then((isTransmissionSupported) {
      setState(() {
        _isTransmissionSupported = isTransmissionSupported;
      });
    });

    beaconBroadcast.getAdvertisingStateChange().listen((isAdvertising) {
      setState(() {
        _isAdvertising = isAdvertising;
      });
    });
  }

  Future<String> getUserId({@required String? email}) async {
    var results = await users.where('email', isEqualTo: email).get();
    print(results.size);
    return results.docs[0].id;
  }

  void startBroadcast() async {
    beaconBroadcast
        .setUUID(uuid)
        .setMajorId(majorId)
        .setMinorId(minorId)
        .setTransmissionPower(transmissionPower)
        .setAdvertiseMode(advertiseMode)
        .setIdentifier(identifier)
        .setLayout(layout)
        .setManufacturerId(manufacturerId)
        .setExtraData(extraData)
        .start();
    setState(() {
      startedBroadcast = true;
    });
  }

  void stopBroadcast() async {
    beaconBroadcast.stop();
    setState(() {
      startedBroadcast = false;
    });
  }

  Future<void> initPlatformState() async {
    if (Platform.isAndroid) {
      //Prominent disclosure
      await BeaconsPlugin.setDisclosureDialogMessage(
          title: "Need Location Permission",
          message: "This app collects location data to work with beacons.");

      //Only in case, you want the dialog to be shown again. By Default, dialog will never be shown if permissions are granted.
      //await BeaconsPlugin.clearDisclosureDialogShowFlag(false);
    }

    BeaconsPlugin.listenToBeacons(beaconEventsController);

    beaconEventsController.stream.listen(
        (data) {
          if (data.isNotEmpty && isRunning) {
            setState(() {
              _beaconResult = data;
              _results.add(_beaconResult);
            });

            print("Beacons DataReceived: " + data);
          }
        },
        onDone: () {},
        onError: (error) {
          print("Error: $error");
        });

    //Send 'true' to run in background
    await BeaconsPlugin.runInBackground(true);

    if (Platform.isAndroid) {
      BeaconsPlugin.channel.setMethodCallHandler((call) async {
        if (call.method == 'scannerReady') {
          await BeaconsPlugin.startMonitoring();
          setState(() {
            isRunning = true;
          });
        }
      });
    } else if (Platform.isIOS) {
      await BeaconsPlugin.startMonitoring();
      setState(() {
        isRunning = true;
      });
    }
  }

  Future<void> startScanning() async {
    await BeaconsPlugin.startMonitoring();
    setState(() {
      startedScanning = true;
    });
  }

  Future<void> stopScanning() async {
    await BeaconsPlugin.stopMonitoring();
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
                Text('Is beacon started?',
                    style: Theme.of(context).textTheme.headline5),
                Text('$_isAdvertising',
                    style: Theme.of(context).textTheme.subtitle1),
                Divider(
                  height: 20,
                ),
                TextField(),
                StreamBuilder<Map<String, dynamic>?>(
                  stream: FlutterBackgroundService().onDataReceived,
                  builder: (context, snapshot) {
                    print(snapshot.hasData);
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final data = snapshot.data!;
                    DateTime? date = DateTime.tryParse(data["current_date"]);
                    return Text(date.toString());
                  },
                ),
                ElevatedButton(
                  child: Text("Foreground Mode"),
                  onPressed: () {
                    FlutterBackgroundService()
                        .sendData({"action": "setAsForeground"});
                  },
                ),
                ElevatedButton(
                  child: Text("Background Mode"),
                  onPressed: () {
                    FlutterBackgroundService()
                        .sendData({"action": "setAsBackground"});
                  },
                ),
                ElevatedButton(
                  child: Text(text),
                  onPressed: () async {
                    var isRunning =
                        await FlutterBackgroundService().isServiceRunning();
                    if (isRunning) {
                      FlutterBackgroundService().sendData(
                        {"action": "stopService"},
                      );
                    } else {
                      FlutterBackgroundService.initialize(onStart);
                    }
                    if (!isRunning) {
                      text = 'Stop Service';
                    } else {
                      text = 'Start Service';
                    }
                    setState(() {});
                  },
                ),
                FutureBuilder<String>(
                    future: getUserId(email: "blob@blob.com"),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'UUID: ${snapshot.data}',
                          style: TextStyle(fontSize: 16),
                        );
                      }
                      return Text(
                        'UUID: Unable to from DB',
                        style: TextStyle(fontSize: 16),
                      );
                    }),
                Divider(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (isRunning) {
                          await stopScanning();
                        } else {
                          initPlatformState();
                          startScanning();
                        }
                        setState(() {
                          isRunning = !isRunning;
                        });
                      },
                      child: Text(
                          isRunning ? 'Stop Scanning' : 'Start Scanning',
                          style: TextStyle(fontSize: 20)),
                    ),
                    Visibility(
                      visible: _results.isNotEmpty,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _results.clear();
                            });
                          },
                          child: Text("Clear Results",
                              style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
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
                SizedBox(
                  height: 20.0,
                ),
                Row(
                  children: [
                    Expanded(child: _buildResultsList()),
                  ],
                )
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            FlutterBackgroundService().sendData({
              "hello": "world",
            });
          },
        ));
  }

  Widget _buildResultsList() {
    return Scrollbar(
      isAlwaysShown: true,
      controller: _scrollController,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        physics: ScrollPhysics(),
        controller: _scrollController,
        itemCount: _results.length,
        separatorBuilder: (BuildContext context, int index) => Divider(
          height: 1,
          color: Colors.black,
        ),
        itemBuilder: (context, index) {
          DateTime now = DateTime.now();
          String formattedDate =
              DateFormat('yyyy-MM-dd – kk:mm:ss.SSS').format(now);
          final item = ListTile(
              title: Text(
                "Time: $formattedDate\n${_results[0]}",
                textAlign: TextAlign.justify,
                style: Theme.of(context).textTheme.headline4?.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF1A1B26),
                      fontWeight: FontWeight.normal,
                    ),
              ),
              onTap: () {});
          return item;
        },
      ),
    );
  }
}

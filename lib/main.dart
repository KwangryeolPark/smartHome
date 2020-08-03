import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'system_configuration.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'json_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterLocalNotificationsPlugin().initialize(InitializationSettings(
      AndroidInitializationSettings('@mipmap/ic_launcher'), IOSInitializationSettings()
  ));


  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        initialRoute: '/loading',
        routes: {
          '/loading': (context) => LoadingRoute(),
          '/IP': (context) => IPRoute(),
          '/Main': (context) => MainRoute()
        });
  }
}

class LoadingRoute extends StatefulWidget {
  @override
  _LoadingRoute createState() => _LoadingRoute();
}

class _LoadingRoute extends State<LoadingRoute> {
  StreamController<int> processFlow = StreamController();

  @override
  void initState() {
    super.initState();
    initProcess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: StreamBuilder<int>(
                stream: processFlow.stream,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  if (snapshot.hasData) {
                    debugPrint(snapshot.data.toString());
                    switch (snapshot.data) {
                      case 0:
                        return Center(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text('기존 데이터를 불러오는 중입니다.\n'),
                            CircularProgressIndicator(
                              valueColor: new AlwaysStoppedAnimation<Color>(
                                  Colors.purple),
                            )
                          ],
                        ));
                        break;

                      case 1:
                        return Center(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text('거의 끝났습니다. 조금 더 기다려주세요.\n'),
                            CircularProgressIndicator(
                              valueColor: new AlwaysStoppedAnimation<Color>(
                                  Colors.purple),
                            )
                          ],
                        ));
                        break;
                    }
                  } else {
                    return Center(
                        child: CircularProgressIndicator(
                      valueColor:
                          new AlwaysStoppedAnimation<Color>(Colors.purple),
                    ));
                  }
                })));
  }

  Future initProcess() async {
    processFlow.sink.add(0);
    await initSystemConfiguration();
    await Future.delayed(new Duration(milliseconds: 2000), () {
      setState(() {
        processFlow.sink.add(1);
      });
    });

    await Future.delayed(new Duration(milliseconds: 2000), () {
      setState(() {
        Navigator.of(this.context).pushNamed('/IP');
      });
    });
  }
}

class IPRoute extends StatefulWidget {
  @override
  _IPRoute createState() => _IPRoute();
}

class _IPRoute extends State<IPRoute> {
  final TextEditingController textEditingController =
      new TextEditingController();

  @override
  void initState() {
    super.initState();
    textEditingController.text = systemConfiguration['targetIP'].status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                width: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    TextField(
                        keyboardType: TextInputType.number,
                        controller: textEditingController,
                        onSubmitted: (String text) {
                          textEditingController.clear();
                        },
                        decoration: new InputDecoration(
                            labelText: "IP Address",
                            hintText: systemConfiguration['targetIP'].status)),
                    IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () async {
                          systemConfiguration['targetIP'].status =
                              textEditingController.text;
                          systemConfigurationDatabase.insert(
                              systemConfigurationTableName,
                              systemConfiguration['targetIP']);
                          setAppReady();
                          Navigator.of(this.context).pushNamed('/Main');
                        })
                  ],
                ))));
  }
}

class MainRoute extends StatefulWidget {
  @override
  _MainRoute createState() => _MainRoute();
}

class _MainRoute extends State<MainRoute> with WidgetsBindingObserver {
  AppLifecycleState appLifecycleState;
  final TextEditingController textEditingController =
      new TextEditingController();

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool autoBlinder = true;
  bool blinder = true;
  bool light = true;

  Timer timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = new Timer.periodic(Duration(seconds:10), (Timer timer) async {
      String data = await sendData("2", "0");
      if(data != null) {
        JsonData jsonData = await fetch(data);
        if(jsonData.Status1 == "onFire") showNotification1("재난 알림", "현재 집에 불이 난 것같습니다!!");
        if(jsonData.Status2 == "intruder") showNotification2("침입자 알림", "현재 집에 침입자가 있습니다.");
        debugPrint(jsonData.toString());
      }
    });
    //init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      appLifecycleState = state;
      debugPrint(appLifecycleState.toString());

      switch(appLifecycleState) {
        case AppLifecycleState.detached:
          FlutterForegroundPlugin.stopForegroundService();
          timer.cancel();
          break;

        case AppLifecycleState.paused:
          startForegroundService();
          timer.cancel();
          break;

        case AppLifecycleState.resumed:
          FlutterForegroundPlugin.stopForegroundService();
          timer = new Timer.periodic(Duration(seconds:10), (Timer timer) async {
            String data = await sendData("2", "0");
            if(data != null) {
              JsonData jsonData = await fetch(data);
              if(jsonData.Status1 == "onFire") showNotification1("재난 알림", "현재 집에 불이 난 것같습니다!!");
              if(jsonData.Status2 == "intruder") showNotification2("침입자 알림", "현재 집에 침입자가 있습니다.");
            }
          });
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Expanded(
                  flex: 2,
                  child: Icon(
                    ((autoBlinder)
                        ? Icons.brightness_auto
                        : Icons.brightness_low),
                    size: 40,
                  )),
              Expanded(
                flex: 9,
                child: Text(
                  (autoBlinder) ? "블라인더 자동모드 " : "블라인더 수동모드 ",
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Expanded(
                  flex: 2,
                  child: Switch(
                    onChanged: (bool value) {
                      setState(() {
                        this.autoBlinder = value;
                        debugPrint((value) ? "1" : "0");
                        sendData("0", (value) ? "1" : "0");
                      });
                    },
                    value: this.autoBlinder,
                    focusColor: Colors.purple,
                    activeColor: Colors.purple[900],
                  ))
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Expanded(
                flex: 2,
                child: Icon(
                    ((autoBlinder) ? Icons.lightbulb_outline : Icons.cancel),
                    color: ((blinder)
                        ? (autoBlinder ? Colors.yellow : Colors.black)
                        : Colors.black),
                    size: 40),
              ),
              Expanded(
                flex: 9,
                child: Text(((blinder) ? "블라인더 올리기" : "블라인더 내리기"),
                    style: TextStyle(fontSize: 20)),
              ),
              Expanded(
                  flex: 2,
                  child: Switch(
                    onChanged: (!this.autoBlinder)
                        ? (bool value) {
                            setState(() {
                              this.blinder = value;
                              debugPrint((blinder) ? "1" : "0");
                              sendData("1", (blinder) ? "1" : "0");
                            });
                          }
                        : null,
                    value: this.blinder,
                    focusColor: Colors.purple,
                    activeColor: Colors.purple[900],
                  ))
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Expanded(
                flex: 2,
                child: Icon(Icons.lightbulb_outline, color: (light) ? Colors.yellow : Colors.black,
                    size: 40),
              ),
              Expanded(
                flex: 9,
                child: Text(((blinder) ? "조명 켜기" : "조명 끄기"),
                    style: TextStyle(fontSize: 20)),
              ),
              Expanded(
                  flex: 2,
                  child: Switch(
                    onChanged: (!this.autoBlinder)
                        ? (bool value) {
                      setState(() {
                        this.blinder = value;
                        debugPrint((blinder) ? "1" : "0");
                        sendData("3", (blinder) ? "1" : "0");
                      });
                    }
                        : null,
                    value: this.blinder,
                    focusColor: Colors.purple,
                    activeColor: Colors.purple[900],
                  ))
            ])
          ],
        ));
  }

  Future<String> sendData(String msg, String data) async {
    try {
      final response = await http.post(
        'http://${systemConfiguration['targetIP'].status}/',
        body: jsonEncode({'Message': msg, 'Data': data}),
      );

      setState(() {
        debugPrint(response.body);
/*        scaffoldKey.currentState.showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 2000),
            content: Text('Received data : ' + response.body)));*/
        return response.body;
      });
    } catch (error) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 3000),
          content: Text(error.toString())));
    }
  }
  Future<JsonData> fetch(String data) async {
    JsonData jsonData = JsonData.fromJson(jsonDecode(data));
    return jsonData;
  }
}

void startForegroundService() async {
  await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 10);
  await FlutterForegroundPlugin.setServiceMethod(await globalForegroundService);
  await FlutterForegroundPlugin.startForegroundService(
    holdWakeLock: false,
    onStarted: () {
      print("Foreground on Started");
    },
    onStopped: () {
      print("Foreground on Stopped");
    },
    title: "Flutter Foreground Service",
    content: "This is Content",
    iconName: "ic_stat_hot_tub",
  );
}

Future globalForegroundService() async {
  try {
    String Message = "";
    debugPrint("Data transport to " + 'http://${systemConfiguration['targetIP'].status}/');
    Future<String> readData() async {
      final response = await http.get(
        'http://${systemConfiguration['targetIP'].status}/'
      );
      return response.body;
    }
    Future<JsonData> fetch(String data) async {
      JsonData jsonData = JsonData.fromJson(jsonDecode(data));
      return jsonData;
    }

    String data = await readData();
    if(data != null) {
      JsonData jsonData = await fetch(data);

      debugPrint("Received data : ${jsonData.toString()}");
      if(jsonData.Status1 == "onFire") showNotification1("재난 알림", "현재 집에 불이 난 것같습니다!!");
      if(jsonData.Status2 == "intruder") showNotification2("침입자 알림", "현재 집에 침입자가 있습니다!!");
    }
  } catch (error) {
    debugPrint(error.toString());
    showNotification1("Error", error.toString());
  }
}

Future<void> showNotification1(String title, String contents) async {
  var android = AndroidNotificationDetails(
      'smartHomeNotification1', 'smartHomeNotificationChannel1', 'smartHomeNotificationData1',
      enableLights: true,
      enableVibration: false);
  var iOS = IOSNotificationDetails();
  var platform = NotificationDetails(android, iOS);

  await FlutterLocalNotificationsPlugin().show(0, title, contents, platform);
}


Future<void> showNotification2(String title, String contents) async {
  var android = AndroidNotificationDetails(
      'smartHomeNotification2', 'smartHomeNotificationChannel2', 'smartHomeNotificationData2',
      enableLights: true,
      enableVibration: false);
  var iOS = IOSNotificationDetails();
  var platform = NotificationDetails(android, iOS);

  await FlutterLocalNotificationsPlugin().show(1, title, contents, platform);
}
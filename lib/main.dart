import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'dart:convert' show utf8, json;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coudy Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(title: 'Coudy Mobile'),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage(
      {
        Key key,
        this.title,
        this.transcript = 'None',
        this.buttonColor,
        this.recordPath,
        this.localIp = '192.168.1.252',
        this.useLocalApi = false
      }
      ) : super(key: key);

  final String title;
  String transcript;
  Color buttonColor;
  String recordPath;
  String localIp = '192.168.1.252';
  bool useLocalApi = false;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterSound flutterSound;

  @override
  void initState() {
    super.initState();
    flutterSound = new FlutterSound();
    flutterSound.setSubscriptionDuration(0.01);
    flutterSound.setDbPeakLevelUpdate(0.8);
    flutterSound.setDbLevelEnabled(true);
  }

  void _startRecord() async {
    try {
      String path = await flutterSound.startRecorder(null);
      print('_startRecord: $path');

      setState(() {
        widget.buttonColor = Colors.red;
        widget.transcript = 'Recording...';
        widget.recordPath = path;
      });

      new Timer(new Duration(seconds: 3), () {
        setState(() {
          widget.buttonColor = Colors.grey;
          widget.transcript = 'Done. Waiting for response...';
        });
        _stopRecord();
      });
    } catch (err) {
      print('_startRecord error: $err');
    }
  }

  void _stopRecord() async {
    try {
      String result = await flutterSound.stopRecorder();
      print('_stopRecord result: $result');
      _uploadRecord();
    } catch (err) {
      print('_stopRecord error: $err');
    }
  }

  _onApiSwitchChange(bool newValue) {
    print('_onApiSwitchChange: $newValue');
    setState(() {
      widget.useLocalApi = newValue;
    });
  }

  _onLocalIpChange(String newValue) {
    print('_onLocalIpChange: $newValue');
    setState(() {
      widget.localIp = newValue;
    });
  }

  Future _uploadRecord() async {
    try {
      File recordFile = File(widget.recordPath);
      var stream = new http.ByteStream(DelegatingStream.typed(recordFile.openRead()));
      var length = await recordFile.length();

      var uri = Uri.parse("http://192.168.1.29:3000/api/v1/mobile");
      if(widget.useLocalApi == true) {
        uri = Uri.parse("http://${widget.localIp}:3000/api/v1/mobile");
      } else {
        uri = Uri.parse("http://192.168.1.29:3000/api/v1/mobile");
      }
      print('URI: $uri');
      var request = new http.MultipartRequest("POST", uri);
      var mediaType = new MediaType('audio', 'mp4');
      var multipartFile = new http.MultipartFile('audioData', stream, length, filename: basename(recordFile.path.split('/').last), contentType: mediaType);
      request.files.add(multipartFile);
      http.StreamedResponse response = await request.send();
      String responseData = await response.stream.transform(utf8.decoder).join();
      Map jsonResponseData = json.decode(responseData);
      if(jsonResponseData['code'] == 400) {
        setState(() {
          widget.transcript = "Error: $jsonResponseData['error']";
        });
      } else {
        setState(() {
          widget.transcript = responseData;
        });
      }
      print('_uploadRecord result: $responseData');

    } catch (err) {
      print('_uploadRecord error: $err');
      setState(() {
        widget.transcript = 'Error: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Set an IP address for local API:'
                    ),
                    TextField(
                      onSubmitted: _onLocalIpChange,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.localIp
                      ),
                      textAlign: TextAlign.center,
                    )
                  ]
                )
              )
            ),
            Container(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Remote API'
                    ),
                    Switch(
                        value: widget.useLocalApi,
                        onChanged: _onApiSwitchChange
                    ),
                    Text(
                      'Localhost API'
                    )
                  ]
                )
              )
            ),
            Text(
                ''
            ),
            Text(
                ''
            ),
            Text(
              'Press icon for recording (3 seconds)'
            ),
            Text(
                ''
            ),
            IconButton(
              icon: Icon(Icons.keyboard_voice),
              tooltip: 'Start recording',
              iconSize: 56.0,
              color: widget.buttonColor,
              onPressed: _startRecord
            ),
            Text(
              ''
            ),
            Text(
              'Transcript of a previous command:',
            ),
            Text(
              '${widget.transcript}',
              style: TextStyle(fontStyle: FontStyle.italic)
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

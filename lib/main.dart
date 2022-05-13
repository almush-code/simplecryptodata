// https://github.com/almush-code/simplecryptodata.git

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';

void main() {
  //runApp(MaterialApp(home: MyApp()));
  runApp(const MyApp()); // Through error: No MaterialLocalizations found
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Candle> candles = [];
  bool themeIsDark = false;
  String selectedItem = 'BTC/USD';
  List<String> itemsDropdownButton = [];

  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://ws-sandbox.coinapi.io/v1/'),
    //Uri.parse('wss://ws.coinapi.io/v1/'),
  );

  @override
  void initState() {
    fetchCandles().then((value) {
      setState(() {
        candles = value;
      });
    });
    //getCurr(context);
    getCurr(context).then((value) {
      setState(() {
        itemsDropdownButton = value;
      });
    });
    _sendMessage();
    super.initState();
  }

  Future<void> _msgErrConnection() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          //title: const Text('AlertDialog Title'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text(
                    'You have a problem with Internet connection or wrong ApiKey from CoinAPI. Please try later'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future getCurr(BuildContext context) async {
    List<String> _lstCurr = [];

    int _errCount = 0;
    var decodedData;
    int _msgNo = 0;
    do {
      http.Response res = await http.get(Uri.parse(
          'https://rest.coinapi.io/v1/assets?apikey=BFB948DE-76ED-4FBD-8487-265856991F16'));
      _msgNo = res.statusCode;
      decodedData = jsonDecode(res.body);
      _errCount++;
    } while (_msgNo != 200 && decodedData is! List && _errCount < 7);
    if (decodedData is List) {
      var lstMapCurr = decodedData
          .where((element) => element['type_is_crypto'] == 1)
          .toList();
      lstMapCurr.forEach((element) {
        _lstCurr.add(element['asset_id'] + '/USD');
      });
      _lstCurr.removeRange(
          99, _lstCurr.length - 1); // <<< First 100 instead of 1500 elements
      itemsDropdownButton = _lstCurr;
      return _lstCurr;
    } else {
      _msgErrConnection();
    }
  }

  Future<List<Candle>> fetchCandles() async {
    int _errCount = 0;
    var decodedData;
    int _msgNo = 0;

    do {
      http.Response res = await http.get(Uri.parse(
          'https://rest.coinapi.io/v1/ohlcv/$selectedItem/latest?period_id=1DAY&apikey=BFB948DE-76ED-4FBD-8487-265856991F16'));
      _msgNo = res.statusCode;
      decodedData = jsonDecode(res.body);
      _errCount++;
    } while (_msgNo != 200 && decodedData is! List && _errCount < 7);
    if (decodedData is List) {
      List<Candle> lstCandle = [];
      for (var i = 0; i < decodedData.length; i++) {
        String sTime = decodedData[i]["time_period_start"];
        sTime = timeFromCoinapi(sTime);
        DateTime dTime = DateTime.parse(sTime);

        final candle = Candle(
            date: dTime,
            open: decodedData[i]["price_open"],
            high: decodedData[i]["price_high"],
            low: decodedData[i]["price_low"],
            close: decodedData[i]["price_close"],
            volume: decodedData[i]["volume_traded"]);
        lstCandle.add(candle);
      }
      setState(() {
        this.candles = lstCandle;
        //print(candles[0].open);
      });
      return lstCandle;
    } else {
      _msgErrConnection();
      throw Exception('Failed to load');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Simple Crypto Data"),
        ),
        body: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedItem,
                      onChanged: (String? string) =>
                          setState(() => selectedItem = string!),
                      selectedItemBuilder: (BuildContext context) {
                        return itemsDropdownButton.map<Widget>((String item) {
                          return Text(
                            item,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              height: 2.0,
                            ),
                          );
                        }).toList();
                      },
                      items: itemsDropdownButton.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                    ),
                  ),
                  Container(
                    width: 20,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      print(selectedItem);
                      fetchCandles();
                      _sendMessage();
                      //Candlesticks(candles: candles);
                    },
                    child: const Text('Subscribe'),
                  )
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Container(
                //height: 110,
                padding: const EdgeInsets.all(10.0),
                decoration: const BoxDecoration(
                  borderRadius:
                      BorderRadius.all(Radius.circular(5.0)), // <<<<<<<<<<
                  color: Colors.white,
                ),
                child: StreamBuilder(
                  stream: _channel.stream,
                  builder: (context, snapshot) {
                    String _sCurr = 'n/a';
                    String _sPrice = 'n/a';
                    String _sTime = 'n/a';
                    if (snapshot.hasData) {
                      var _decodedData = jsonDecode('${snapshot.data}');
                      _sCurr = selectedItem;
                      //_sCurr = _decodedData['symbol_id'];
                      _sPrice = _decodedData['price'].toString();
                      //_sPrice = _decodedData['price'].toStringAsFixed(5);
                      _sTime = timeFromCoinapi(_decodedData['time_exchange']);
                      DateTime dTime = DateTime.parse(_sTime);
                      _sTime = DateFormat('MMM d, h:mm a').format(dTime);
                    } else {
                      _sCurr = 'n/a';
                      _sPrice = 'n/a';
                      _sTime = 'n/a';
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Text(
                                'Symbol:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _sCurr,
                                style: const TextStyle(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Text(
                                'Price:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _sPrice,
                                style: const TextStyle(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Text(
                                'Time:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _sTime,
                                style: const TextStyle(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    //return Text(snapshot.hasData ? '${snapshot.data}' : '');
                  },
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                child: Candlesticks(
                  candles: candles,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  timeFromCoinapi(String sOrig) {
    sOrig = sOrig.replaceAll("T", " ");
    sOrig = sOrig.replaceAll("0000Z", "");
    return sOrig;
  }

  void _sendMessage() {
    String msgHello = '''
{
  "type": "hello",
  "apikey": "BFB948DE-76ED-4FBD-8487-265856991F16",
  "heartbeat": false,
  "subscribe_data_type": ["trade"],
  "subscribe_filter_asset_id": ["$selectedItem"]
}    
    ''';
    _channel.sink.add(msgHello);
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}

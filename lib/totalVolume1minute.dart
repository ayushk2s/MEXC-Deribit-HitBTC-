import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class VolumeChartApp extends StatefulWidget {
  @override
  _VolumeChartAppState createState() => _VolumeChartAppState();
}

class _VolumeChartAppState extends State<VolumeChartApp> {
  List<FlSpot> volumeData = [];

  @override
  void initState() {
    super.initState();
    fetchVolumeData();
  }

  Future<void> fetchVolumeData() async {
    final urls = {
      'Binance': 'https://api.binance.com/api/v3/klines?symbol=ETHUSDT&interval=1m&limit=500',
      'Kraken': 'https://api.kraken.com/0/public/OHLC?pair=ETHUSD&interval=1',
      'Coinbase': 'https://api.pro.coinbase.com/products/ETH-USD/candles?granularity=60&limit=500'
    };

    List<double> volumeList = List.filled(500, 0.0); // Stores volume for last 500 minutes

    for (var exchange in urls.keys) {
      final response = await http.get(Uri.parse(urls[exchange]!));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        for (int i = 0; i < 500; i++) {
          double volume = 0.0;

          if (exchange == 'Binance') {
            volume = double.parse(data[i][5]); // Binance format: [time, open, high, low, close, volume]
          } else if (exchange == 'Kraken') {
            var key = data['result'].keys.first;
            volume = double.parse(data['result'][key][i][6]); // Kraken format: [time, open, high, low, close, vwap, volume]
          } else if (exchange == 'Coinbase') {
            volume = data[i][5].toDouble(); // Coinbase format: [time, low, high, open, close, volume]
          }

          volumeList[i] += volume; // Add volume from all exchanges
        }
      } else {
        print('Failed to fetch volume from $exchange');
      }
    }

    setState(() {
      volumeData = volumeList.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value); // (minute, volume)
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('ETH Volume (Last 500m)')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: volumeData,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2,
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

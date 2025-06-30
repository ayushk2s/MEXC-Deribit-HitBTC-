import 'package:arbitrage_trading/Deribit/ArbitrageShowingFramework.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/DeribitIndTrade.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndTrade/DeribitIndTrial.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/BTCETHONLY/BTC.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/BTCETHONLY/ETH.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/DeribitIndicator.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/DeribitIndicator2.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/ETHBTCINDI.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/TimeFrame.dart';
import 'package:arbitrage_trading/Deribit/DeribitTrade/DifferentWebsocket/ba.dart';
import 'package:arbitrage_trading/Deribit/DeribitWebsocket/bidaskwebsocket.dart';
import 'package:arbitrage_trading/Deribit/DeribitIndicator/PriceDifferenceFramWork.dart';
import 'package:arbitrage_trading/Mexc/MEXCBuyAndSelling.dart';
import 'package:arbitrage_trading/Mexc/Indicator/mexcIndicator.dart';
import 'package:arbitrage_trading/totalVolume1minute.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // home: ArbitrageApp(),
      // home: DeribitIndicator(),
      // home: MEXCIndicator()
      // home: OrderBookApp()
      // home: TradingHomePage(),
      // home:PriceDifferenceChart(),
      // home: DeribitIndicator(),
      // home: ArbitrageHomePage()
      // home: DeribitIndTrade()
      // home: BidAskDeribit()
      // home: BTCINDICATOR(),
      // home: BTCINDICATOR()
      // home: VolumeChartApp()
      home: MEXCIndicator()
    );
  }
}


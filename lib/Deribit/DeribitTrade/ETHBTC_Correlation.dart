import 'dart:async';
import 'package:arbitrage_trading/Deribit/DeribitTrade/ETHBTC_WebSocket_Price.dart';

class ETHBTC_Correlation_Trading {
  double? ethPrice;
  double? btcPrice;
  final MyData myData = MyData();
  final ETHBTCWebSocketPrice priceFetcher = ETHBTCWebSocketPrice();

  ETHBTC_Correlation_Trading() {
    // Start WebSocket and update prices in real-time
    priceFetcher.startWebSocket(myData);
  }

  void updatePrices() {
    // Update the latest prices from myData
    ethPrice = myData.ethPrice;
    btcPrice = myData.btcPrice;
  }

  void tradingAlgorithm() {
    // Update prices before running the algorithm
    updatePrices();

    // Access updated ETH and BTC prices for trading logic
    if (ethPrice != null && btcPrice != null) {
      print('Running trading algorithm with ETH: $ethPrice, BTC: $btcPrice');
      // Add your trading logic here
    } else {
      print('Waiting for price updates...');
    }
  }
}

void main() {
  final ethbtcCorrelationTrading = ETHBTC_Correlation_Trading();

  // Periodically run the trading algorithm and print updated prices
  Timer.periodic(const Duration(milliseconds: 200), (_) {
    ethbtcCorrelationTrading.tradingAlgorithm();
  });
}

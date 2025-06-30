import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() async {
  List<double> EthClose = await fetchOHLCDataFromDeribit('ETH-PERPETUAL');
  List<double> BtcClose = await fetchOHLCDataFromDeribit('BTC-PERPETUAL');

  print('Eth close $EthClose \n Btc Close $BtcClose');

  ///Calculation of the correlation coefficient
  double correlationValue = await calculateCorrelation(BtcClose, EthClose);
  print('Correlation Value is ${correlationValue}');

  // Assume a beta value for testing (e.g., beta = 1.0 for simplicity)
  double beta = calculateBeta(EthClose, BtcClose);
  print('Beta value $beta');

  // Calculate the spread for each pair of ETH and BTC prices
  List<double> spreads = calculateSpreads(EthClose, BtcClose, beta);
  print('Spreads: $spreads');

  // Determine what to buy or sell based on the spreads
  String action = determineTradeAction(spreads);
  print('Trade Action: $action');
}

Future<List<double>> fetchOHLCDataFromDeribit(String symbol) async {
  try {
    final String interval = '1D';
    // Get the current time (end timestamp)
    final int endTime = DateTime.now().millisecondsSinceEpoch;

    // Get the time 30 days ago (start timestamp)
    final int startTime = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;

    // Deribit API endpoint for OHLC data
    final String url = 'https://www.deribit.com/api/v2/public/get_tradingview_chart_data'
        '?end_timestamp=$endTime&instrument_name=$symbol&resolution=$interval&start_timestamp=$startTime';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);

      if (data['result'] != null) {
        List<dynamic> ticks = data['result']['ticks'] ?? [];

        // Function to safely parse a list of doubles
        List<double> parseDoubleList(List<dynamic>? input) {
          if (input == null) return [];
          return input.map((e) {
            if (e is num) return e.toDouble();
            return 0.0; // Fallback for non-numeric or null values
          }).toList();
        }

        // Safely map the response data
        List<double> open = parseDoubleList(data['result']['open']);
        List<double> high = parseDoubleList(data['result']['high']);
        List<double> low = parseDoubleList(data['result']['low']);
        List<double> close = parseDoubleList(data['result']['close']);
        List<double> volume = parseDoubleList(data['result']['volume']);
        return close;
      } else {
        print('Invalid response structure: Missing "result" key');
      }
    } else {
      print('Failed to fetch candle data from Deribit: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching OHLC data from Deribit: $e');
    return [];
  }
  return [];
}

Future<double> calculateCorrelation(List<double> btcPrices, List<double> ethPrices) async {
  if (btcPrices.length != ethPrices.length || btcPrices.isEmpty) {
    throw ArgumentError("Both lists must have the same non-zero length.");
  }

  int n = btcPrices.length;

  // Calculate means
  double mean(List<double> values) => values.reduce((a, b) => a + b) / n;
  double meanBtc = mean(btcPrices);
  double meanEth = mean(ethPrices);

  // Calculate covariance (numerator) and variances (denominator)
  double covariance = 0.0;
  double varianceBtc = 0.0;
  double varianceEth = 0.0;

  for (int i = 0; i < n; i++) {
    double diffBtc = btcPrices[i] - meanBtc;
    double diffEth = ethPrices[i] - meanEth;

    covariance += diffBtc * diffEth;
    varianceBtc += diffBtc * diffBtc;
    varianceEth += diffEth * diffEth;
  }

  // Calculate the correlation coefficient
  double denominator = sqrt(varianceBtc * varianceEth);
  if (denominator == 0) {
    throw ArgumentError("Standard deviation is zero, cannot compute correlation.");
  }

  return covariance / denominator;
}

// Beta value calculation
double calculateBeta(List<double> btcPrices, List<double> ethPrices) {
  if (btcPrices.length != ethPrices.length || btcPrices.isEmpty) {
    throw ArgumentError("Both lists must have the same non-zero length.");
  }

  int n = btcPrices.length;

  // Compute log prices
  List<double> logBtcPrices = btcPrices.map((price) => log(price)).toList();
  List<double> logEthPrices = ethPrices.map((price) => log(price)).toList();

  // Calculate means
  double mean(List<double> values) => values.reduce((a, b) => a + b) / n;
  double meanLogBtc = mean(logBtcPrices);
  double meanLogEth = mean(logEthPrices);

  // Calculate covariance and variance
  double covariance = 0.0;
  double variance = 0.0;

  for (int i = 0; i < n; i++) {
    covariance += (logBtcPrices[i] - meanLogBtc) * (logEthPrices[i] - meanLogEth);
    variance += pow(logBtcPrices[i] - meanLogBtc, 2);
  }

  covariance /= n;
  variance /= n;

  return covariance / variance;
}

List<double> calculateSpreads(List<double> ethPrices, List<double> btcPrices, double beta) {
  List<double> spreads = [];
  for (int i = 0; i < ethPrices.length; i++) {
    spreads.add(log(ethPrices[i]) - beta * log(btcPrices[i]));
  }
  return spreads;
}

// Function to determine buy/sell action based on spread
String determineTradeAction(List<double> spreads) {
  // Define the mean and standard deviation of the spreads
  double meanSpread = spreads.reduce((a, b) => a + b) / spreads.length;
  double variance = spreads.fold(0.0, (prev, element) => prev + pow(element - meanSpread, 2));
  double stdDev = sqrt(variance / spreads.length);

  // Define thresholds based on the mean and std deviation
  double upperThreshold = meanSpread + 2 * stdDev;
  double lowerThreshold = meanSpread - 2 * stdDev;

  // Check the latest spread
  double latestSpread = spreads.last;

  // If the spread is above the upper threshold, short ETH and long BTC (ETH overpriced)
  if (latestSpread > upperThreshold) {
    return "Short ETH, Long BTC";
  }
  // If the spread is below the lower threshold, long ETH and short BTC (ETH underpriced)
  else if (latestSpread < lowerThreshold) {
    return "Long ETH, Short BTC";
  } else {
    return "No trade";
  }
}

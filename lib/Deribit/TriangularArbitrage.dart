void checkTriangularArbitrage(double ethToUsdt, double ethToUsdc, double usdcToUsdt) {
  // Cycle 1: ETH -> USDC -> USDT -> ETH
  double cycle1 = (1 / ethToUsdc) * usdcToUsdt * (1 / ethToUsdt);

  // Cycle 2: ETH -> USDT -> USDC -> ETH
  double cycle2 = (1 / ethToUsdt) * (1 / usdcToUsdt) * ethToUsdc;

  // Cycle 3: USDC -> ETH -> USDT -> USDC
  double cycle3 = (1 / usdcToUsdt) * (1 / ethToUsdt) * ethToUsdc;

  // Cycle 4: USDC -> USDT -> ETH -> USDC
  double cycle4 = (1 / usdcToUsdt) * ethToUsdt * (1 / ethToUsdc);

  // Cycle 5: USDT -> ETH -> USDC -> USDT
  double cycle5 = (1 / usdcToUsdt) * ethToUsdc * (1 / ethToUsdt);

  // Cycle 6: USDT -> USDC -> ETH -> USDT
  double cycle6 = (1 / ethToUsdt) * ethToUsdc * usdcToUsdt;

  // Create a map to associate cycle numbers with their respective cycle descriptions
  List<Map<String, dynamic>> cycleDetails = [
    {"cycle": 1, "description": "ETH -> USDC -> USDT -> ETH", "value": cycle1},
    {"cycle": 2, "description": "ETH -> USDT -> USDC -> ETH", "value": cycle2},
    {"cycle": 3, "description": "USDC -> ETH -> USDT -> USDC", "value": cycle3},
    {"cycle": 4, "description": "USDC -> USDT -> ETH -> USDC", "value": cycle4},
    {"cycle": 5, "description": "USDT -> ETH -> USDC -> USDT", "value": cycle5},
    {"cycle": 6, "description": "USDT -> USDC -> ETH -> USDT", "value": cycle6},
  ];

  bool arbitrageFound = false;

  // Iterate through all cycles and print the ones where arbitrage is found
  for (var cycle in cycleDetails) {
    if (cycle["value"] > 1) {
      print('Arbitrage opportunity found in cycle: ${cycle["description"]}');
      print('The cycle yields a profit of ${(cycle["value"] - 1) * 100}%');
      arbitrageFound = true;
    }
  }

  // If no arbitrage opportunity found in any cycle
  if (!arbitrageFound) {
    print('No arbitrage opportunity found.');
  }
}

void main() {
  // Provided exchange rates
  double ethToUsdt = 3605.5735; // ETH to USDT
  double ethToUsdc = 3602.4396; // ETH to USDC
  double usdcToUsdt = 1.0008; // USDC to USDT

  // Check for triangular arbitrage opportunity in all cycles
  checkTriangularArbitrage(ethToUsdt, ethToUsdc, usdcToUsdt);
}
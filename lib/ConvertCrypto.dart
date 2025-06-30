import 'dart:io';

void main() {
  while (true) {
    // Get the initial investment amount from the user
    stdout.write("Enter the initial amount for arbitrage cycle (enter 0 to exit): ");
    String? initialAmountInput = stdin.readLineSync();

    if (initialAmountInput == null || double.tryParse(initialAmountInput) == null) {
      print("Please enter a valid number for the amount.");
      continue;
    }

    double initialAmount = double.parse(initialAmountInput);

    // Check if the user wants to exit
    if (initialAmount == 0) {
      print("Exiting the program. Goodbye!");
      break;
    }

    // Get conversion rates for the three pairs
    stdout.write("Enter the conversion rate for Pair 1 (e.g., USDC/USDT): ");
    String? rate1Input = stdin.readLineSync();

    stdout.write("Enter the conversion rate for Pair 2 (e.g., ETH/USDT): ");
    String? rate2Input = stdin.readLineSync();

    stdout.write("Enter the conversion rate for Pair 3 (e.g., ETH/USDC): ");
    String? rate3Input = stdin.readLineSync();

    if (rate1Input == null || rate2Input == null || rate3Input == null ||
        double.tryParse(rate1Input) == null ||
        double.tryParse(rate2Input) == null ||
        double.tryParse(rate3Input) == null) {
      print("Please enter valid numbers for all conversion rates.");
      continue;
    }

    double rate1 = double.parse(rate1Input);
    double rate2 = double.parse(rate2Input);
    double rate3 = double.parse(rate3Input);

    // Perform arbitrage cycle
    double afterFirstConversion = initialAmount / rate1;
    double afterSecondConversion = afterFirstConversion * rate2;
    double finalAmount = afterSecondConversion / rate3;

    print("Initial Amount: \\${initialAmount.toStringAsFixed(2)}");
    print("After first conversion: \\${afterFirstConversion.toStringAsFixed(2)}");
    print("After second conversion: \\${afterSecondConversion.toStringAsFixed(2)}");
    print("Final Amount after arbitrage cycle: \\${finalAmount.toStringAsFixed(2)}");

    // Profit or loss
    double profitOrLoss = finalAmount - initialAmount;
    if (profitOrLoss > 0) {
      print("Profit: \\${profitOrLoss.toStringAsFixed(2)}");
    } else {
      print("Loss: \\${profitOrLoss.abs().toStringAsFixed(2)}");
    }
  }
}

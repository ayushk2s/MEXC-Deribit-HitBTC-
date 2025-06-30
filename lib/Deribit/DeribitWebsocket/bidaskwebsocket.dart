// import 'dart:convert';
// import 'dart:async'; // For Timer
// import 'dart:io';
//
// import 'package:flutter/material.dart';
//
//
// class OrderBookApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Order Book Viewer',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: OrderBookScreen(),
//     );
//   }
// }
//
// class OrderBookScreen extends StatefulWidget {
//   @override
//   _OrderBookScreenState createState() => _OrderBookScreenState();
// }
//
// class _OrderBookScreenState extends State<OrderBookScreen> {
//   final websocketUrl = 'wss://www.deribit.com/ws/api/v2';
//
//   Map<double, double> bids = {};
//   Map<double, double> asks = {};
//
//   WebSocket? webSocket; // Use dart:html WebSocket
//   Timer? heartbeatTimer; // For sending heartbeat messages
//   Timer? uiUpdateTimer; // For debouncing UI updates
//
//   @override
//   void initState() {
//     super.initState();
//     _connectWebSocket();
//   }
//
//   void _connectWebSocket() {
//     webSocket = WebSocket(websocketUrl);
//
//     webSocket!.onOpen.listen((_) {
//       print('Connected to Deribit WebSocket');
//       _subscribeToOrderBook();
//       _sendHeartbeat();
//     });
//
//     webSocket!.onMessage.listen((message) {
//       final data = jsonDecode(message.data);
//
//       if (data["params"] != null &&
//           data["params"]["channel"] == "book.ETH-PERPETUAL.100ms") {
//         final orderBookData = data["params"]["data"];
//         final type = orderBookData["type"];
//         if (type == "snapshot") {
//           _updateOrderBook(orderBookData["bids"], bids);
//           _updateOrderBook(orderBookData["asks"], asks);
//         } else if (type == "change") {
//           _updateOrderBook(orderBookData["bids"], bids);
//           _updateOrderBook(orderBookData["asks"], asks);
//         }
//         _debouncedUpdateUI();
//       }
//     });
//
//     webSocket!.onError.listen((error) {
//       print('WebSocket error: $error');
//       _reconnectWebSocket(); // Attempt to reconnect
//     });
//
//     webSocket!.onClose.listen((_) {
//       print('WebSocket connection closed');
//       _reconnectWebSocket(); // Attempt to reconnect
//     });
//   }
//
//   void _reconnectWebSocket() {
//     print('Reconnecting to WebSocket...');
//     Future.delayed(Duration(seconds: 2), _connectWebSocket);
//   }
//
//   void _subscribeToOrderBook() {
//     final orderBookSubscription = {
//       "jsonrpc": "2.0",
//       "id": 1,
//       "method": "public/subscribe",
//       "params": {
//         "channels": ["book.ETH-PERPETUAL.100ms"]
//       }
//     };
//     webSocket!.send(jsonEncode(orderBookSubscription));
//   }
//
//   void _sendHeartbeat() {
//     heartbeatTimer?.cancel();
//     heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
//       if (webSocket != null && webSocket!.readyState == WebSocket.OPEN) {
//         webSocket!.send(jsonEncode({"method": "ping"}));
//         print('Heartbeat sent');
//       }
//     });
//   }
//
//   void _updateOrderBook(List<dynamic> entries, Map<double, double> book) {
//     for (var entry in entries) {
//       final action = entry[0];
//       final price = entry[1] as double;
//       final amount = entry[2] as double;
//       if (action == "new" || action == "change") {
//         book[price] = amount;
//       } else if (action == "delete") {
//         book.remove(price);
//       }
//       print('bid $bids');
//       print('ask $asks');
//     }
//   }
//
//   void _debouncedUpdateUI() {
//     if (uiUpdateTimer != null && uiUpdateTimer!.isActive) return;
//     uiUpdateTimer = Timer(Duration(milliseconds: 500), () {
//       if (mounted) setState(() {});
//     });
//   }
//
//   @override
//   void dispose() {
//     webSocket?.close();
//     heartbeatTimer?.cancel();
//     uiUpdateTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Order Book Viewer'),
//       ),
//       body: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   color: Colors.green,
//                   child: Text(
//                     'Bids',
//                     style: TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//                 Expanded(
//                   child: ListView(
//                     children: bids.entries
//                         .toList()
//                         .map((entry) => ListTile(
//                       title: Text('Price: ${entry.key}'),
//                       trailing: Text('Amount: ${entry.value}'),
//                     ))
//                         .toList(),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           VerticalDivider(width: 1, color: Colors.grey),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   color: Colors.red,
//                   child: Text(
//                     'Asks',
//                     style: TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//                 Expanded(
//                   child: ListView(
//                     children: asks.entries
//                         .toList()
//                         .map((entry) => ListTile(
//                       title: Text('Price: ${entry.key}'),
//                       trailing: Text('Amount: ${entry.value}'),
//                     ))
//                         .toList(),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

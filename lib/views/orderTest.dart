import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'orderDetailes.dart';

class OrderList extends StatelessWidget {
  final OrderController _orderController = OrderController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order List 3'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Order>>(
        future: _orderController.getOrders(),
        builder: (BuildContext context, AsyncSnapshot<List<Order>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Order not found"));
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: snapshot.data!.length,
            itemBuilder: (BuildContext context, int index) {
              final order = snapshot.data![index];
              return Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: Text(order.name ?? "Unnamed"),
                      subtitle: Text(order.note ?? "No note"),
                      trailing: Text(
                        order.createdDateTime != null
                            ? DateFormat(
                                'yyyy-MM-dd – kk:mm',
                              ).format(order.createdDateTime!)
                            : "No date",
                      ),
                      leading: CircleAvatar(
                        child: Text((order.name?.substring(0, 1) ?? "?")),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetails(order),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

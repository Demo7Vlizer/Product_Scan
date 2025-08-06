import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:eopystocknew/models/orderDetail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderList extends StatelessWidget {
  final OrderController _orderController = OrderController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order List'),
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
            return Center(child: Text("No orders found"));
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

class OrderDetails extends StatefulWidget {
  final Order order;

  const OrderDetails(this.order);

  @override
  _OrderDetailsState createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<OrderDetails> {
  final OrderController _orderController = OrderController();
  late Future<List<OrderDetail>> _orderDetails;
  int deneme = 0;

  @override
  void initState() {
    super.initState();
    _orderDetails = _orderController.getOrderDetails(widget.order.id ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order.name ?? "Order Details"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        height: 270.0,
        width: 350.0,
        child: Center(
          child: FutureBuilder<List<OrderDetail>>(
            future: _orderDetails,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<OrderDetail>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData && snapshot.data != null) {
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        final orderDetail = snapshot.data![index];
                        return Row(
                          children: [
                            Text((orderDetail.amount ?? 0).toString()),
                          ],
                        );
                      },
                    );
                  } else {
                    return Center(child: Text("No data available"));
                  }
                },
          ),
        ),
      ),
    );
  }
}

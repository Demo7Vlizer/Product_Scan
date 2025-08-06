import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:eopystocknew/models/orderDetail.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

///-> Stateful
class OrderDetails extends StatefulWidget {
  final Order order;

  const OrderDetails(this.order);

  @override
  _OrderDetailsState createState() => _OrderDetailsState();
}

///-> Stateful implement
class _OrderDetailsState extends State<OrderDetails> {
  final OrderController _orderController = OrderController();
  late Future<List<OrderDetail>> _orderDetails;
  int deneme = 0;

  ///-> Initialize
  @override
  void initState() {
    super.initState();
    _orderDetails = _orderController.getOrderDetails(widget.order.id ?? 0);
  }

  ///-> MainWidget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //-> Appbar
      appBar: AppBar(
        title: Text(widget.order.name ?? "Order Details"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      //-> Body
      body: detaylariGetir(),
    );
  }

  ///-> BodyWidget
  Widget detaylariGetir() {
    return Container(
      child: FutureBuilder<List<OrderDetail>>(
        future: _orderDetails,
        builder:
            (BuildContext context, AsyncSnapshot<List<OrderDetail>> snapshot) {
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.all(3),
                            child: Container(
                              child: Row(
                                children: [
                                  decButton(orderDetail),
                                  Text(
                                    (orderDetail.amount ?? 0).toString(),
                                    style: TextStyle(
                                      fontFamily: "Arial",
                                      fontSize: 22,
                                    ),
                                  ),
                                  incButton(orderDetail),
                                  addButton(orderDetail),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: Text(orderDetail.stockCode ?? "No Code"),
                            subtitle: Text(orderDetail.stockName ?? "No Name"),
                          ),
                        ),
                      ],
                    );
                  },
                );
              } else {
                return Center(child: Text("No data available"));
              }
            },
      ),
    );
  }

  Widget decButton(OrderDetail data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        (data.amount ?? 0) > 0
            ? IconButton(
                icon: Icon(Icons.remove),
                onPressed: () => setState(() {
                  data.amount = (data.amount ?? 0) - 1;
                }),
              )
            : Container(),
      ],
    );
  }

  Widget incButton(OrderDetail data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        (data.amount ?? 0) < 100
            ? IconButton(
                icon: Icon(Icons.add, size: 32),
                onPressed: () => setState(() {
                  data.amount = (data.amount ?? 0) + 1;
                }),
              )
            : Container(),
      ],
    );
  }

  Widget addButton(OrderDetail data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        (data.amount ?? 0) < 100
            ? IconButton(
                icon: Icon(Icons.update, size: 32),
                onPressed: () => update(data),
              )
            : Container(),
      ],
    );
  }

  void update(OrderDetail orderDetail) {
    _orderDetails.then((value) {
      orderDetail.stockName = "Stock Updated";
      orderDetail.stockCode = "Stock Code";

      _orderController
          .addUpdateOrderDetail(orderDetail)
          .then((result) {
            Fluttertoast.showToast(
              msg: "Updated",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
          })
          .catchError((error) {
            Fluttertoast.showToast(
              msg: "Error",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
          });
    });
  }

  addUpdateOrderDetail() {}
}

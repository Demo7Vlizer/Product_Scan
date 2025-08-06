import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:eopystocknew/models/orderDetail.dart';
import 'package:flutter/material.dart';
import 'order_detail_new.dart';

class OrderDetailListPage extends StatefulWidget {
  final Order order;

  const OrderDetailListPage({Key? key, required this.order}) : super(key: key);
  @override
  _OrderDetailListPageState createState() => _OrderDetailListPageState();
}

class _OrderDetailListPageState extends State<OrderDetailListPage> {
  late OrderController _dbHelper;
  late Future<List<OrderDetail>> getOrderDetails;
  late int orderDetailCount;
  final String deleted = "Deleted";
  final String archived = "Archived";
  final String restore = "";

  @override
  void initState() {
    _dbHelper = OrderController();
    getOrderDetailList();
    super.initState();
  }

  void getOrderDetailList() {
    getOrderDetails = _dbHelper.getOrderDetails(widget.order.id!);
    getOrderDetails.then((value) {
      orderDetailCount = value.length;
      refresh();
    });
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.order.name} ($orderDetailCount)")),
      floatingActionButton: Container(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                getOrderDetailList();
              },
              child: Icon(Icons.refresh),
              backgroundColor: Colors.amber,
              heroTag: "Refresh",
            ),
            SizedBox(height: 20),
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddOrderDetailPage(
                      orderDetail: new OrderDetail(),
                      order: widget.order,
                    ),
                  ),
                );
              },
              child: Icon(Icons.add),
              heroTag: "Add",
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddOrderDetailPage(
                      orderDetail: new OrderDetail(),
                      order: widget.order,
                    ),
                  ),
                );
              },
              child: Icon(Icons.filter_frames),
              heroTag: "Barcode",
            ),
          ],
        ),
      ),
      body: FutureBuilder(
        future: getOrderDetails,
        builder:
            (BuildContext context, AsyncSnapshot<List<OrderDetail>> snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              if (snapshot.data!.isEmpty)
                return Text("Your Order List is Empty...");
              if (snapshot.hasError) return Text("An Error Occurred...");
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (BuildContext context, int index) {
                  OrderDetail orderDetail = snapshot.data![index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddOrderDetailPage(
                            orderDetail: orderDetail,
                            order: widget.order,
                          ),
                        ),
                      ).then((value) => getOrderDetailList());
                    },
                    child: Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.red,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                      onDismissed: (direction) async {
                        await _dbHelper
                            .changeStatusOrderDetail(orderDetail, deleted)
                            .then((value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${orderDetail.stockCode} silindi.",
                                  ),
                                  action: SnackBarAction(
                                    label: "Geri Al",
                                    onPressed: () async {
                                      await _dbHelper.changeStatusOrderDetail(
                                        orderDetail,
                                        restore,
                                      );

                                      getOrderDetailList();
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                      child: Expanded(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              //orderDetail.stockCode.substring(0, 1),
                              (index + 1).toString(),
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(orderDetail.stockCode ?? ''),
                              ),
                              Text(
                                orderDetail.amount.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Expanded(
                            child: Text(orderDetail.stockName ?? ''),
                          ),
                          trailing: Expanded(
                            child: new IconButton(
                              icon: new Icon(Icons.plus_one),
                              onPressed: () {
                                amountIncremet(orderDetail);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
      ),
    );
  }

  void amountIncremet(OrderDetail orderDetail) {
    orderDetail.amount = (orderDetail.amount ?? 0) + 1;
    _dbHelper
        .addUpdateOrderDetail(orderDetail)
        .then((value) => getOrderDetailList());
  }
}

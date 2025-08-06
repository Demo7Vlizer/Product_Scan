import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:eopystocknew/models/orderDetail.dart';
import 'package:flutter/material.dart';

class AddOrderDetailPage extends StatelessWidget {
  final OrderDetail orderDetail;
  final Order order;

  const AddOrderDetailPage({
    Key? key,
    required this.orderDetail,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          orderDetail.id == null
              ? "Add New Item"
              : (orderDetail.stockCode ?? "Stock"),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: OrderDetailForm(
          orderDetail: orderDetail,
          order: order,
          child: AddOrderDetailForm(),
        ),
      ),
    );
  }
}

class OrderDetailForm extends InheritedWidget {
  final OrderDetail orderDetail;
  final Order order;

  OrderDetailForm({
    Key? key,
    required Widget child,
    required this.orderDetail,
    required this.order,
  }) : super(key: key, child: child);

  static OrderDetailForm? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OrderDetailForm>();
  }

  @override
  bool updateShouldNotify(OrderDetailForm oldWidget) {
    return orderDetail.id != oldWidget.orderDetail.id;
  }
}

class AddOrderDetailForm extends StatefulWidget {
  @override
  _AddOrderDetailFormState createState() => _AddOrderDetailFormState();
}

class _AddOrderDetailFormState extends State<AddOrderDetailForm> {
  final _formKey = GlobalKey<FormState>();
  late OrderController _dbHelper;
  String _value = "";
  final _controller = TextEditingController();

  void _captureCode() async {
    // Using mobile_scanner instead of flutter_barcode_scanner
    // This would need to be implemented with a scanner screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Scanner functionality needs to be implemented"),
        duration: Duration(microseconds: 2000),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dbHelper = OrderController();

    _controller.addListener(() {
      // Listener logic if needed
    });
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    OrderDetailForm? orderDetailForm = OrderDetailForm.of(context);
    if (orderDetailForm == null) return Container();

    OrderDetail orderDetail = orderDetailForm.orderDetail;
    Order order = orderDetailForm.order;
    _controller.text = orderDetail.stockCode ?? "";
    String resultmsg = "";
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: TextFormField(
                          decoration: InputDecoration(hintText: "Stok Kodu"),
                          controller: _controller,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "İsim Gerekli";
                            }
                            return null;
                          },
                          onSaved: (value) {
                            orderDetail.stockCode = value;
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.scanner),
                        onPressed: _captureCode,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    decoration: InputDecoration(hintText: "Stok İsmi"),
                    initialValue: orderDetail.stockName,
                    validator: (value) {
                      return null;
                    },
                    onSaved: (value) {
                      orderDetail.stockName = value;
                    },
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Save $_value"),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      if (orderDetail.id == null) {
                        orderDetail.id = 0;
                        orderDetail.orderId = order.id ?? 0;
                        orderDetail.status = "";
                        await _dbHelper.addUpdateOrderDetail(orderDetail);
                      } else {
                        await _dbHelper.addUpdateOrderDetail(orderDetail);
                      }
                      FocusScope.of(context).unfocus();
                      resultmsg = "${orderDetail.stockCode} kaydedildi";
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(resultmsg),
                          duration: Duration(microseconds: 1000),
                        ),
                      );

                      Navigator.pop(context, resultmsg);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

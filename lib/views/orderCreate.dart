import 'package:flutter/material.dart';

class OrderCreate extends StatefulWidget {
  @override
  _OrderCreateState createState() => _OrderCreateState();
}

class _OrderCreateState extends State<OrderCreate> {
  String? _name, _note, _createdate;
  bool otomatikKontrol = false;
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.save),
      ),
      appBar: AppBar(
        title: Text("Add New Order"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Form(
          key: formKey,
          child: ListView(
            children: <Widget>[
              SizedBox(height: 10),
              TextFormField(
                maxLength: 25,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.book),
                  hintText: "Enter Order Name",
                  hintStyle: TextStyle(fontSize: 12),
                  labelText: "Order",
                  border: OutlineInputBorder(),
                ),
                validator: _isimKontrol,
                onSaved: (deger) => _name = deger,
              ),
              SizedBox(height: 20),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.comment),
                  hintText: "Enter Order Description",
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                validator: _aciklamaKontrol,
                onSaved: (deger) => _note = deger,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text("SAVE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _girisBilgileriniOnayla,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _girisBilgileriniOnayla() {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      FocusScope.of(context).unfocus();
      _createdate = DateTime.now().toString();
      debugPrint("Girilen name: $_name note:$_note date:$_createdate");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$_name ->")));
      Navigator.pop(context);
    } else {
      setState(() {
        otomatikKontrol = true;
      });
    }
  }

  String? _aciklamaKontrol(String? aciklama) {
    if (aciklama == null || aciklama.length > 100)
      return 'En fazla 100 karakter';
    else
      return null;
  }

  String? _isimKontrol(String? isim) {
    if (isim == null || isim.length < 3 || isim.length > 100)
      return '3-100 karakter arası olmalı';
    else
      return null;
  }
}

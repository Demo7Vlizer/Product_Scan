import 'package:flutter/material.dart';
import 'package:eopystocknew/views/add_product_simple.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _searchController;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await RequestClient.loadServerUrl();
    setState(() {
      _settingsLoaded = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Eopy Stock Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // TODO: Implement notifications
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products, orders...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // TODO: Implement search functionality
                    },
                  ),
                ),

                SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),

                SizedBox(height: 16),

                // Feature Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    children: [
                      _buildFeatureCard(
                        'Add Product',
                        Icons.add_box,
                        Colors.green,
                        '/addProduct',
                        'Scan QR & add product',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddProductSimplePage(),
                            ),
                          );
                        },
                      ),
                      _buildFeatureCard(
                        'Scan QR Code',
                        Icons.qr_code_scanner,
                        Colors.blue,
                        '/camera',
                        'Scan products quickly',
                      ),
                      _buildFeatureCard(
                        'Product List',
                        Icons.list,
                        Colors.green,
                        '/products',
                        'View and edit products',
                      ),
                      _buildFeatureCard(
                        'Orders',
                        Icons.shopping_cart,
                        Colors.orange,
                        '/order',
                        'View and manage orders',
                      ),
                      _buildFeatureCard(
                        'Create Order',
                        Icons.add_shopping_cart,
                        Colors.purple,
                        '/orderCreate',
                        'Create new orders',
                      ),
                      _buildFeatureCard(
                        'Users',
                        Icons.people,
                        Colors.teal,
                        '/user',
                        'Manage users',
                      ),
                      _buildFeatureCard(
                        'Settings',
                        Icons.settings,
                        Colors.grey,
                        '/settings',
                        'App configuration',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    String route,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

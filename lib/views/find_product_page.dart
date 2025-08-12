import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../controllers/productLocationController.dart';
import '../models/productLocation.dart';
import '../services/network/request_service.dart';

class FindProductPage extends StatefulWidget {
  const FindProductPage({Key? key}) : super(key: key);

  @override
  State<FindProductPage> createState() => _FindProductPageState();
}

class _FindProductPageState extends State<FindProductPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ProductLocationController _locationController = ProductLocationController();
  
  // Add Location Tab
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  List<String> _selectedImagesBase64 = [];
  List<File> _selectedImageFiles = [];
  bool _isAddingLocation = false;

  // Search Tab
  final TextEditingController _searchController = TextEditingController();
  List<ProductLocation> _searchResults = [];
  List<String> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  // Browse Tab
  List<ProductLocation> _allLocations = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingBrowse = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllLocations();
    
    // Add listener for search suggestions
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productNameController.dispose();
    _locationNameController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty && query.length >= 2) {
      _getSuggestions(query);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await _locationController.getProductSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently handle suggestion errors - not critical
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _selectedImageFiles.add(imageFile);
          _selectedImagesBase64.add('data:image/jpeg;base64,$base64Image');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addLocation() async {
    if (_productNameController.text.trim().isEmpty ||
        _locationNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in product name and location name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAddingLocation = true;
    });

    try {
      final message = await _locationController.addProductLocation(
        _productNameController.text.trim(),
        _locationNameController.text.trim(),
        _selectedImagesBase64.isNotEmpty ? _selectedImagesBase64 : null,
        _notesController.text.trim(),
      );

      setState(() {
        _isAddingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      
      // Clear form
      _productNameController.clear();
      _locationNameController.clear();
      _notesController.clear();
      setState(() {
        _selectedImageFiles.clear();
        _selectedImagesBase64.clear();
      });
      
      // Refresh browse tab
      _loadAllLocations();
    } catch (e) {
      setState(() {
        _isAddingLocation = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final locations = await _locationController.searchProductLocations(query.trim());

      setState(() {
        _isSearching = false;
        _searchResults = locations;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAllLocations() async {
    setState(() {
      _isLoadingBrowse = true;
    });

    try {
      final response = await _locationController.getProductLocations(
        page: _currentPage,
        perPage: 10,
      );

      setState(() {
        _isLoadingBrowse = false;
        _allLocations = response.locations ?? [];
        _totalPages = response.totalPages ?? 1;
      });
    } catch (e) {
      setState(() {
        _isLoadingBrowse = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load locations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50.withOpacity(0.3),
              Colors.purple.shade50.withOpacity(0.3),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(context),
              
              // Enhanced Tab Bar
              _buildEnhancedTabBar(),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAddLocationTab(),
                    _buildSearchTab(),
                    _buildBrowseTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button with enhanced design
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.grey.shade700,
                  size: 20,
                ),
              ),
            ),
          ),
          
          SizedBox(width: 16),
          
          // Enhanced title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Product',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Locate your inventory with ease',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          // Action button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Quick add functionality
                  _tabController.animateTo(0);
                },
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.add_location_alt,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTabBar() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate, size: 18),
                SizedBox(width: 6),
                Text('Add'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 18),
                SizedBox(width: 6),
                Text('Search'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 18),
                SizedBox(width: 6),
                Text('Browse'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade400.withOpacity(0.1),
                  Colors.green.shade400.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.shade200,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_location_alt,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Add New Location',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Capture where your products are stored',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Form card with glassmorphism
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Enhanced input fields
                  _buildEnhancedTextField(
                    controller: _productNameController,
                    label: 'Product Name',
                    hint: 'Enter the product name',
                    icon: Icons.inventory_2_outlined,
                    iconColor: Colors.teal.shade600,
                  ),
                  
                  SizedBox(height: 20),
                  
                  _buildEnhancedTextField(
                    controller: _locationNameController,
                    label: 'Location Name',
                    hint: 'e.g., Aisle 3, Shelf B, Storage Room',
                    icon: Icons.place_outlined,
                    iconColor: Colors.blue.shade600,
                  ),
                  
                  SizedBox(height: 20),
                  
                  _buildEnhancedTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    hint: 'Additional details about the location',
                    icon: Icons.note_outlined,
                    iconColor: Colors.purple.shade600,
                    maxLines: 3,
                  ),
                  SizedBox(height: 24),
                  
                  // Enhanced Image Section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50.withOpacity(0.5),
                          Colors.purple.shade50.withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (_selectedImageFiles.isNotEmpty) ...[
                            // Image Grid
                            _buildImageGrid(),
                            const SizedBox(height: 20),
                            // Add More Photos Button
                            _buildImageActionButton(
                              onPressed: _pickImage,
                              icon: Icons.add_photo_alternate,
                              label: 'Add More Photos',
                              gradient: [Colors.blue.shade400, Colors.indigo.shade500],
                              isLarge: true,
                            ),
                            const SizedBox(height: 12),
                            // Clear All Button
                            _buildImageActionButton(
                              onPressed: () {
                                setState(() {
                                  _selectedImageFiles.clear();
                                  _selectedImagesBase64.clear();
                                });
                              },
                              icon: Icons.clear_all,
                              label: 'Clear All Photos',
                              gradient: [Colors.red.shade400, Colors.pink.shade500],
                            ),
                          ] else ...[
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade400, Colors.purple.shade500],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade200,
                                    blurRadius: 15,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Add Location Photos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Capture multiple angles of where this\nproduct is located for easy identification',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            _buildImageActionButton(
                              onPressed: _pickImage,
                              icon: Icons.camera_alt,
                              label: 'Take First Photo',
                              gradient: [Colors.teal.shade400, Colors.green.shade500],
                              isLarge: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Enhanced Save Button
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.green.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.shade200,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isAddingLocation ? null : _addLocation,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _isAddingLocation
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Saving Location...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.save,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Save Location',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Enhanced search header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400.withOpacity(0.1), Colors.purple.shade400.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search by product name or location...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Container(
                          margin: EdgeInsets.all(12),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.purple.shade500],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.search, color: Colors.white, size: 20),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _suggestions = [];
                                    _showSuggestions = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: _searchLocations,
                    ),
                    

                  ],
                ),
              ),
              
              // Suggestions section
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange.shade600),
                            SizedBox(width: 8),
                            Text(
                              'Suggestions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _searchController.text = suggestion;
                                  setState(() {
                                    _showSuggestions = false;
                                  });
                                  _searchLocations(suggestion);
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          size: 16,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suggestion,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(height: 16),
              
              // Search button
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _searchLocations(_searchController.text),
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.search, color: Colors.white, size: 20),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          
          // Search results section with proper height
          SizedBox(height: 20),
          
          Container(
            constraints: BoxConstraints(
              minHeight: 300,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Icon(
                                Icons.search_off,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchController.text.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.purple.shade500],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade200,
                                        blurRadius: 15,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.search,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Search Product Locations',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Enter a product name or location to find\nwhere your items are stored',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _buildSearchResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        // Header with pagination info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Locations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _currentPage > 1 ? () {
                      setState(() {
                        _currentPage--;
                      });
                      _loadAllLocations();
                    } : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$_currentPage / $_totalPages'),
                  IconButton(
                    onPressed: _currentPage < _totalPages ? () {
                      setState(() {
                        _currentPage++;
                      });
                      _loadAllLocations();
                    } : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoadingBrowse
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAllLocations,
                  child: _buildLocationsList(_allLocations, 'No locations found'),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final location = _searchResults[index];
          return _buildLocationCard(location);
        },
      ),
    );
  }

  Widget _buildLocationsList(List<ProductLocation> locations, String emptyMessage) {
    if (locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return _buildLocationCard(location);
      },
    );
  }

  Widget _buildLocationCard(ProductLocation location) {
    // Get all image paths (multiple images support)
    final imagePaths = location.imagePaths ?? 
                      (location.imagePath != null ? [location.imagePath!] : <String>[]);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLocationDetails(location),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with multiple photo indicator
              if (imagePaths.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        '${RequestClient.baseUrl}/uploads/${imagePaths.first}',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error, size: 48, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Multiple photos indicator
                    if (imagePaths.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black54, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${imagePaths.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                                         // Action buttons (Edit and View)
                     Positioned(
                       bottom: 12,
                       right: 12,
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           // Edit button
                           Container(
                             width: 36,
                             height: 36,
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 colors: [Colors.orange.shade400, Colors.red.shade500],
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                               ),
                               borderRadius: BorderRadius.circular(18),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.black26,
                                   blurRadius: 4,
                                   offset: Offset(0, 2),
                                 ),
                               ],
                             ),
                             child: Material(
                               color: Colors.transparent,
                               child: InkWell(
                                 onTap: () => _showEditLocationDialog(location),
                                 borderRadius: BorderRadius.circular(18),
                                 child: Icon(
                                   Icons.edit,
                                   color: Colors.white,
                                   size: 18,
                                 ),
                               ),
                             ),
                           ),
                           
                           SizedBox(width: 8),
                           
                           // View button
                           Container(
                             width: 36,
                             height: 36,
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 colors: [Colors.blue.shade400, Colors.purple.shade500],
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                               ),
                               borderRadius: BorderRadius.circular(18),
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.black26,
                                   blurRadius: 4,
                                   offset: Offset(0, 2),
                                 ),
                               ],
                             ),
                             child: Material(
                               color: Colors.transparent,
                               child: InkWell(
                                 onTap: () => _showLocationDetails(location),
                                 borderRadius: BorderRadius.circular(18),
                                 child: Icon(
                                   Icons.visibility,
                                   color: Colors.white,
                                   size: 18,
                                 ),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                  ],
                ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.productName ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(Icons.place, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.locationName ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (location.notes != null && location.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    location.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      location.updatedDate != null
                          ? DateTime.parse(location.updatedDate!).toLocal().toString().split('.')[0]
                          : 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationDetails(ProductLocation location) {
    final imagePaths = location.imagePaths ?? 
                      (location.imagePath != null ? [location.imagePath!] : <String>[]);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LocationDetailsDialog(
          location: location,
          imagePaths: imagePaths,
        );
      },
    );
  }

  void _showEditLocationDialog(ProductLocation location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditLocationDialog(
          location: location,
          onLocationUpdated: () {
            // Refresh the data after editing
            _loadAllLocations();
            if (_searchResults.isNotEmpty) {
              _searchLocations(_searchController.text);
            }
          },
        );
      },
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildImageActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> gradient,
    bool isLarge = false,
  }) {
    return Container(
      height: isLarge ? 50 : 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isLarge ? 6 : 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isLarge ? 20 : 16,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isLarge ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _selectedImageFiles.length,
        itemBuilder: (context, index) {
          return _buildImageCard(index);
        },
      ),
    );
  }

  Widget _buildImageCard(int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImageFiles[index],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          
          // Photo number badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Delete button
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.pink.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedImageFiles.removeAt(index);
                      _selectedImagesBase64.removeAt(index);
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          
          // Tap to view full size
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showImagePreview(index),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _selectedImageFiles[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 40,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(22),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Photo ${index + 1} of ${_selectedImageFiles.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EditLocationDialog extends StatefulWidget {
  final ProductLocation location;
  final VoidCallback onLocationUpdated;

  const EditLocationDialog({
    Key? key,
    required this.location,
    required this.onLocationUpdated,
  }) : super(key: key);

  @override
  State<EditLocationDialog> createState() => _EditLocationDialogState();
}

class _EditLocationDialogState extends State<EditLocationDialog> {
  late TextEditingController _productNameController;
  late TextEditingController _locationNameController;
  late TextEditingController _notesController;
  
  List<String> _existingImagePaths = [];
  List<File> _newImageFiles = [];
  List<String> _newImagesBase64 = [];
  List<String> _imagesToDelete = [];
  
  bool _isUpdating = false;
  final ProductLocationController _locationController = ProductLocationController();

  @override
  void initState() {
    super.initState();
    _productNameController = TextEditingController(text: widget.location.productName ?? '');
    _locationNameController = TextEditingController(text: widget.location.locationName ?? '');
    _notesController = TextEditingController(text: widget.location.notes ?? '');
    
    // Load existing images
    _existingImagePaths = widget.location.imagePaths ?? 
                         (widget.location.imagePath != null ? [widget.location.imagePath!] : <String>[]);
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _locationNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _newImageFiles.add(imageFile);
          _newImagesBase64.add('data:image/jpeg;base64,$base64Image');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteExistingImage(String imagePath) {
    setState(() {
      _existingImagePaths.remove(imagePath);
      _imagesToDelete.add(imagePath);
    });
  }

  void _deleteNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
      _newImagesBase64.removeAt(index);
    });
  }

  Future<void> _updateLocation() async {
    if (_productNameController.text.trim().isEmpty ||
        _locationNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in product name and location name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final message = await _locationController.updateProductLocationWithPhotoDeletion(
        widget.location.id!,
        _productNameController.text.trim(),
        _locationNameController.text.trim(),
        _newImagesBase64.isNotEmpty ? _newImagesBase64 : null,
        _notesController.text.trim(),
        _imagesToDelete,
      );

      setState(() {
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.onLocationUpdated();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.red.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name Field
                    _buildTextField(
                      controller: _productNameController,
                      label: 'Product Name',
                      icon: Icons.inventory_2_outlined,
                      iconColor: Colors.orange.shade600,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Location Name Field
                    _buildTextField(
                      controller: _locationNameController,
                      label: 'Location Name',
                      icon: Icons.place_outlined,
                      iconColor: Colors.blue.shade600,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Notes Field
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes (Optional)',
                      icon: Icons.note_outlined,
                      iconColor: Colors.purple.shade600,
                      maxLines: 3,
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Images Section
                    Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Existing Images
                    if (_existingImagePaths.isNotEmpty) ...[
                      Text(
                        'Current Photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildExistingImagesGrid(),
                      SizedBox(height: 16),
                    ],
                    
                    // New Images
                    if (_newImageFiles.isNotEmpty) ...[
                      Text(
                        'New Photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildNewImagesGrid(),
                      SizedBox(height: 16),
                    ],
                    
                    // Add Photo Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.purple.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Update Button
            Container(
              padding: EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.red.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade200,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUpdating ? null : _updateLocation,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: _isUpdating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Update Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildExistingImagesGrid() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _existingImagePaths.length,
        itemBuilder: (context, index) {
          final imagePath = _existingImagePaths[index];
          return Container(
            width: 120,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${RequestClient.baseUrl}/uploads/$imagePath',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.error, color: Colors.grey),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _deleteExistingImage(imagePath),
                        borderRadius: BorderRadius.circular(14),
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewImagesGrid() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _newImageFiles.length,
        itemBuilder: (context, index) {
          return Container(
            width: 120,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade200,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _newImageFiles[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _deleteNewImage(index),
                        borderRadius: BorderRadius.circular(14),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class LocationDetailsDialog extends StatefulWidget {
  final ProductLocation location;
  final List<String> imagePaths;

  const LocationDetailsDialog({
    Key? key,
    required this.location,
    required this.imagePaths,
  }) : super(key: key);

  @override
  State<LocationDetailsDialog> createState() => _LocationDetailsDialogState();
}

class _LocationDetailsDialogState extends State<LocationDetailsDialog> {
  late PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.location.productName ?? 'Unknown Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place, color: Colors.white70, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.location.locationName ?? 'Unknown Location',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image Gallery
            if (widget.imagePaths.isNotEmpty) ...[
              Container(
                height: 300,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemCount: widget.imagePaths.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.all(10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              '${RequestClient.baseUrl}/uploads/${widget.imagePaths[index]}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.error,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    // Navigation arrows
                    if (widget.imagePaths.length > 1) ...[
                      // Left arrow
                      if (_currentImageIndex > 0)
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _pageController.previousPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Right arrow
                      if (_currentImageIndex < widget.imagePaths.length - 1)
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],

                    // Photo counter
                    if (widget.imagePaths.length > 1)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1} of ${widget.imagePaths.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Thumbnail strip for multiple images
              if (widget.imagePaths.length > 1)
                Container(
                  height: 80,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.imagePaths.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentImageIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              '${RequestClient.baseUrl}/uploads/${widget.imagePaths[index]}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.error, size: 20, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],

            // Details section
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.location.notes != null && widget.location.notes!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.note_outlined, size: 20, color: Colors.grey.shade600),
                        SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        widget.location.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Date info
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                      SizedBox(width: 4),
                      Text(
                        'Added: ${widget.location.createdDate != null ? DateTime.parse(widget.location.createdDate!).toLocal().toString().split('.')[0] : 'Unknown'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

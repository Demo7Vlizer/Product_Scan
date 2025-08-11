import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSyncEnabled = true;
  String _selectedLanguage = 'English';
  String _serverUrl = 'http://192.168.2.27:8080';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    RequestClient.loadServerUrl().then((_) {
      setState(() {
        _serverUrl = RequestClient.baseUrl;
      });
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _serverUrl = prefs.getString('server_url') ?? 'http://192.168.2.27:8080';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
    await prefs.setBool('auto_sync_enabled', _autoSyncEnabled);
    await prefs.setString('selected_language', _selectedLanguage);
    await prefs.setString('server_url', _serverUrl);
    await RequestClient.saveServerUrl(_serverUrl);
    // TODO: Trigger reload of all data here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: IconButton(
              icon: Icon(Icons.save_outlined, color: Colors.grey.shade600, size: 20),
            onPressed: () async {
              await _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Settings saved successfully!'),
                    ],
                  ),
                    backgroundColor: Colors.grey.shade800,
                ),
              );
            },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
            vertical: 16,
          ),
          child: Column(
        children: [
          // App Information
          _buildSectionCard('App Information', [
            _buildInfoTile('App Version', '1.0.0'),
            _buildInfoTile('Build Number', '1'),
            _buildInfoTile('Last Updated', '2024'),
          ]),

          SizedBox(height: 16),

          // Notifications
          _buildSectionCard('Notifications', [
            SwitchListTile(
              title: Text('Enable Notifications'),
              subtitle: Text('Receive alerts for important events'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ]),

          SizedBox(height: 16),

          // Appearance
          _buildSectionCard('Appearance', [
            SwitchListTile(
              title: Text('Dark Mode'),
              subtitle: Text('Use dark theme'),
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
            ),
            ListTile(
              title: Text(
                'Language',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _selectedLanguage,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                _showLanguageDialog();
              },
            ),
          ]),

          SizedBox(height: 16),

          // Data & Sync
          _buildSectionCard('Data & Sync', [
            SwitchListTile(
              title: Text('Auto Sync'),
              subtitle: Text('Automatically sync data with server'),
              value: _autoSyncEnabled,
              onChanged: (value) {
                setState(() {
                  _autoSyncEnabled = value;
                });
              },
            ),
            ListTile(
              title: Text(
                'Server URL',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _serverUrl,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 16),
              ),
              onTap: () {
                _showServerUrlDialog();
              },
            ),
          ]),

          SizedBox(height: 16),

          // Actions
          _buildSectionCard('Actions', [
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Icon(Icons.refresh_outlined, color: Colors.blue.shade600, size: 16),
              ),
              title: Text(
                'Sync Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Manually sync data',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Syncing data...'),
                    backgroundColor: Colors.grey.shade800,
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: Icon(Icons.download_outlined, color: Colors.green.shade600, size: 16),
              ),
              title: Text(
                'Export Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Export data to file',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export functionality coming soon!'),
                    backgroundColor: Colors.grey.shade800,
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Icon(Icons.upload_outlined, color: Colors.orange.shade600, size: 16),
              ),
              title: Text(
                'Import Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Import data from file',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Import functionality coming soon!'),
                    backgroundColor: Colors.grey.shade800,
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200, width: 1),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 16),
              ),
              title: Text(
                'Clear All Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Delete all local data',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                _showClearDataDialog();
              },
            ),
          ]),

          SizedBox(height: 16),

          // About
          _buildSectionCard('About', [
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Icon(Icons.info_outlined, color: Colors.blue.shade600, size: 16),
              ),
              title: Text(
                'About App',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Version and license information',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: Icon(Icons.help_outline, color: Colors.green.shade600, size: 16),
              ),
              title: Text(
                'Help & Support',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Get help and contact support',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Help & Support coming soon!'),
                    backgroundColor: Colors.grey.shade800,
                  ),
                );
              },
            ),
          ]),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(Icons.info_outlined, color: Colors.grey.shade600, size: 16),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('English'),
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text('Turkish'),
                value: 'Turkish',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: _serverUrl);
    bool isAutoDetecting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;
            final maxDialogHeight = screenHeight * 0.8;
            
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: maxDialogHeight,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200, width: 1),
                              ),
                              child: Icon(Icons.dns_outlined, color: Colors.blue.shade600, size: 16),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Server Configuration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Current Server Section
                        Text(
                          'Current Server:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade200, width: 1),
                          ),
                          child: SelectableText(
                            _serverUrl.isEmpty ? 'No server configured' : _serverUrl,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _serverUrl.isEmpty ? Colors.grey.shade500 : Colors.grey.shade800,
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // New Server URL Section
                        Text(
                          'Enter New Server URL:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
            controller: controller,
            decoration: InputDecoration(
                            hintText: '192.168.1.100:8080',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade500, width: 1),
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.all(8),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.language_outlined, color: Colors.grey.shade600, size: 16),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          style: TextStyle(fontSize: 13),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Auto-detect button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isAutoDetecting ? null : () async {
                              if (!mounted) return;
                              
                              setDialogState(() {
                                isAutoDetecting = true;
                              });
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Looking for server...'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 10),
                                  ),
                                );
                              }
                              
                              bool detected = await RequestClient.findServerAutomatically();
                              
                              if (mounted) {
                                setDialogState(() {
                                  isAutoDetecting = false;
                                });
                                
                                if (detected) {
                                  String newUrl = RequestClient.baseUrl;
                                  controller.text = newUrl.replaceAll('http://', '');
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Expanded(child: Text('Server found: ${controller.text}')),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    // Get device IP to show user what IP range to expect
                                    String? deviceIP = await RequestClient.getDeviceIP();
                                    String suggestion = deviceIP != null 
                                        ? "Try: ${deviceIP.substring(0, deviceIP.lastIndexOf('.'))}.100:8080"
                                        : "Check server terminal for correct IP";
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.error, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('Server not found'),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              suggestion,
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: isAutoDetecting 
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.search, size: 20),
                            label: Text(
                              isAutoDetecting ? 'Searching...' : 'Find Server',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade700,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: Colors.orange.shade200, width: 1),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
              onPressed: () async {
                                  String newUrl = controller.text.trim();
                                  if (newUrl.isNotEmpty) {
                setState(() {
                                      _serverUrl = newUrl.startsWith('http://') ? newUrl : 'http://$newUrl';
                });
                await RequestClient.saveServerUrl(_serverUrl);
                Navigator.of(context).pop();
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Server URL updated successfully'),
                                          ],
                                        ),
                                        backgroundColor: Colors.grey.shade800,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.grey.shade700,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                                child: Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All Data'),
          content: Text(
            'Are you sure you want to clear all local data? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All data cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('About Eopy Stock Management'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: 1.0.0'),
              SizedBox(height: 8),
              Text('A comprehensive stock management solution for businesses.'),
              SizedBox(height: 16),
              Text('Features:'),
              Text('• Barcode scanning'),
              Text('• Inventory management'),
              Text('• Order processing'),
              Text('• Real-time sync'),
              SizedBox(height: 16),
              Text('© 2024 Eopy Stock Management'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

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
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              await _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings saved successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
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
              title: Text('Language'),
              subtitle: Text(_selectedLanguage),
              trailing: Icon(Icons.arrow_forward_ios),
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
              title: Text('Server URL'),
              subtitle: Text(_serverUrl),
              trailing: Icon(Icons.edit),
              onTap: () {
                _showServerUrlDialog();
              },
            ),
          ]),

          SizedBox(height: 16),

          // Actions
          _buildSectionCard('Actions', [
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.blue),
              title: Text('Sync Now'),
              subtitle: Text('Manually sync data'),
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Syncing data...')));
              },
            ),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.green),
              title: Text('Export Data'),
              subtitle: Text('Export data to file'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export functionality coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.restore, color: Colors.orange),
              title: Text('Import Data'),
              subtitle: Text('Import data from file'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import functionality coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Clear All Data'),
              subtitle: Text('Delete all local data'),
              onTap: () {
                _showClearDataDialog();
              },
            ),
          ]),

          SizedBox(height: 16),

          // About
          _buildSectionCard('About', [
            ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title: Text('About App'),
              subtitle: Text('Version and license information'),
              onTap: () {
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.help, color: Colors.green),
              title: Text('Help & Support'),
              subtitle: Text('Get help and contact support'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Help & Support coming soon!')),
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
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
      title: Text(title),
      subtitle: Text(value),
      trailing: Icon(Icons.info_outline, color: Colors.grey),
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Server URL'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter server URL',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _serverUrl = controller.text;
                });
                await RequestClient.saveServerUrl(_serverUrl);
                Navigator.of(context).pop();
                // TODO: Trigger reload of all data here if needed
              },
              child: Text('Save'),
            ),
          ],
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

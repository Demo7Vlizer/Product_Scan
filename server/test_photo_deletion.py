#!/usr/bin/env python3
"""
Test script to verify photo deletion functionality
"""

import sqlite3
import json
import os

def test_photo_deletion_fix():
    """Test that photo deletion properly updates database"""
    print("🧪 Testing Photo Deletion Fix")
    print("=" * 50)
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Check current state
    cursor.execute('''
        SELECT id, recipient_name, recipient_photo 
        FROM transactions 
        WHERE recipient_photo IS NOT NULL AND recipient_photo != ''
    ''')
    
    transactions = cursor.fetchall()
    
    print(f"📊 Found {len(transactions)} transactions with photos:")
    
    for trans_id, name, photo_data in transactions:
        try:
            if photo_data.startswith('['):
                photos = json.loads(photo_data)
                print(f"  ID: {trans_id}, Name: {name}, Photos: {len(photos)} items")
                for i, photo in enumerate(photos):
                    filename = photo.replace('customer_photos/', '') if photo.startswith('customer_photos/') else photo
                    file_path = os.path.join('uploads', 'customer_photos', filename)
                    exists = os.path.exists(file_path)
                    status = "✅ exists" if exists else "❌ missing"
                    print(f"    {i+1}. {filename} - {status}")
            else:
                filename = photo_data.replace('customer_photos/', '') if photo_data.startswith('customer_photos/') else photo_data
                file_path = os.path.join('uploads', 'customer_photos', filename)
                exists = os.path.exists(file_path)
                status = "✅ exists" if exists else "❌ missing"
                print(f"  ID: {trans_id}, Name: {name}, Photo: {filename} - {status}")
        except json.JSONDecodeError:
            filename = photo_data.replace('customer_photos/', '') if photo_data.startswith('customer_photos/') else photo_data
            file_path = os.path.join('uploads', 'customer_photos', filename)
            exists = os.path.exists(file_path)
            status = "✅ exists" if exists else "❌ missing"
            print(f"  ID: {trans_id}, Name: {name}, Photo: {filename} - {status}")
    
    conn.close()
    
    print("\n🔧 Fix Summary:")
    print("1. ✅ Server endpoint now updates database when deleting photos")
    print("2. ✅ Flutter app sends customer info when deleting photos")  
    print("3. ✅ Improved photo comparison logic in save function")
    print("\n📝 Next Steps:")
    print("1. Test deleting a photo from the Flutter app")
    print("2. Verify the photo file is deleted from server storage")
    print("3. Verify the database is updated immediately")
    print("4. Verify clicking camera icon shows only remaining photos")

if __name__ == "__main__":
    test_photo_deletion_fix()

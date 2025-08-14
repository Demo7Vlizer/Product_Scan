#!/usr/bin/env python3
"""
Script to fix existing photos in the database that are stored as JSON arrays or base64 strings
"""

import sqlite3
import json
import base64
import os
from datetime import datetime
from app import process_and_save_image, app

def fix_json_array_photos():
    """Fix photos stored as JSON arrays"""
    print("🔧 Fixing JSON array photos...")
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Find transactions with JSON array photos
    cursor.execute('''
        SELECT id, recipient_name, recipient_phone, recipient_photo
        FROM transactions 
        WHERE recipient_photo IS NOT NULL 
        AND recipient_photo LIKE '[%'
    ''')
    
    json_transactions = cursor.fetchall()
    
    if not json_transactions:
        print("  ✅ No JSON array photos found")
        conn.close()
        return
    
    print(f"  📊 Found {len(json_transactions)} transactions with JSON array photos")
    
    fixed_count = 0
    
    for trans in json_transactions:
        trans_id, recipient_name, recipient_phone, photo_json = trans
        
        try:
            # Parse JSON array
            photo_array = json.loads(photo_json)
            
            if isinstance(photo_array, list) and len(photo_array) > 0:
                first_photo = photo_array[0]
                
                if first_photo and first_photo.startswith('data:image'):
                    # Process and save the first photo
                    customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                    filename = f"customer_{customer_key}_fixed_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
                    
                    success, full_path, error_msg = process_and_save_image(
                        first_photo, 
                        filename, 
                        app.config['CUSTOMER_PHOTOS_FOLDER'],
                        compress=True
                    )
                    
                    if success:
                        # Update database with file path
                        new_photo_path = f"customer_photos/{filename}"
                        cursor.execute('''
                            UPDATE transactions 
                            SET recipient_photo = ?
                            WHERE id = ?
                        ''', (new_photo_path, trans_id))
                        
                        fixed_count += 1
                        print(f"    ✅ Fixed transaction {trans_id} ({recipient_name})")
                    else:
                        print(f"    ❌ Failed to process photo for transaction {trans_id}: {error_msg}")
        
        except Exception as e:
            print(f"    ❌ Error processing transaction {trans_id}: {e}")
    
    conn.commit()
    conn.close()
    
    print(f"  🎉 Fixed {fixed_count} JSON array photos")

def fix_base64_photos():
    """Fix photos stored as raw base64 strings"""
    print("\n🔧 Fixing base64 photos...")
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Find transactions with base64 photos
    cursor.execute('''
        SELECT id, recipient_name, recipient_phone, recipient_photo
        FROM transactions 
        WHERE recipient_photo IS NOT NULL 
        AND recipient_photo LIKE 'data:image%'
        AND recipient_photo NOT LIKE 'customer_photos/%'
        AND recipient_photo NOT LIKE 'product_photos/%'
    ''')
    
    base64_transactions = cursor.fetchall()
    
    if not base64_transactions:
        print("  ✅ No base64 photos found")
        conn.close()
        return
    
    print(f"  📊 Found {len(base64_transactions)} transactions with base64 photos")
    
    fixed_count = 0
    
    for trans in base64_transactions:
        trans_id, recipient_name, recipient_phone, photo_base64 = trans
        
        try:
            if photo_base64.startswith('data:image'):
                # Process and save the photo
                customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                filename = f"customer_{customer_key}_fixed_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
                
                success, full_path, error_msg = process_and_save_image(
                    photo_base64, 
                    filename, 
                    app.config['CUSTOMER_PHOTOS_FOLDER'],
                    compress=True
                )
                
                if success:
                    # Update database with file path
                    new_photo_path = f"customer_photos/{filename}"
                    cursor.execute('''
                        UPDATE transactions 
                        SET recipient_photo = ?
                        WHERE id = ?
                    ''', (new_photo_path, trans_id))
                    
                    fixed_count += 1
                    print(f"    ✅ Fixed transaction {trans_id} ({recipient_name})")
                else:
                    print(f"    ❌ Failed to process photo for transaction {trans_id}: {error_msg}")
        
        except Exception as e:
            print(f"    ❌ Error processing transaction {trans_id}: {e}")
    
    conn.commit()
    conn.close()
    
    print(f"  🎉 Fixed {fixed_count} base64 photos")

def verify_fixes():
    """Verify that fixes were applied correctly"""
    print("\n🔍 Verifying fixes...")
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Count remaining problematic photos
    cursor.execute('''
        SELECT COUNT(*) FROM transactions 
        WHERE recipient_photo IS NOT NULL 
        AND (recipient_photo LIKE '[%' OR 
             (recipient_photo LIKE 'data:image%' AND 
              recipient_photo NOT LIKE 'customer_photos/%' AND 
              recipient_photo NOT LIKE 'product_photos/%'))
    ''')
    
    remaining_issues = cursor.fetchone()[0]
    
    # Count properly formatted photos
    cursor.execute('''
        SELECT COUNT(*) FROM transactions 
        WHERE recipient_photo IS NOT NULL 
        AND (recipient_photo LIKE 'customer_photos/%' OR 
             recipient_photo LIKE 'product_photos/%')
    ''')
    
    fixed_photos = cursor.fetchone()[0]
    
    conn.close()
    
    print(f"  📊 Properly formatted photos: {fixed_photos}")
    print(f"  ⚠️  Remaining issues: {remaining_issues}")
    
    if remaining_issues == 0:
        print("  🎉 All photos are now properly formatted!")
    else:
        print("  ⚠️  Some photos still need attention")

def main():
    print("🔧 Photo Database Fix Tool")
    print("=" * 50)
    
    # Ensure we're in the right directory
    if not os.path.exists('inventory.db'):
        print("❌ inventory.db not found. Make sure you're running this from the server directory.")
        return
    
    # Create app context for using the process_and_save_image function
    with app.app_context():
        fix_json_array_photos()
        fix_base64_photos()
        verify_fixes()
    
    print("\n🎯 What to do next:")
    print("=" * 50)
    print("1. Restart your server: python app.py")
    print("2. Test photo viewing in the web interface")
    print("3. Try taking new photos from the Flutter app")
    print("4. All new photos should now be saved as file paths")

if __name__ == "__main__":
    main()

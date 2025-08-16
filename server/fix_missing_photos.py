#!/usr/bin/env python3
"""
Fix missing customer photos by removing references to non-existent files
"""

import sqlite3
import json
import os
from datetime import datetime

def fix_missing_photos():
    """Remove references to missing photo files from the database"""
    print("🔧 Fixing Missing Customer Photos")
    print("=" * 50)
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Get all transactions with photos
    cursor.execute('''
        SELECT id, recipient_name, recipient_photo 
        FROM transactions 
        WHERE recipient_photo IS NOT NULL AND recipient_photo != ''
    ''')
    
    transactions = cursor.fetchall()
    fixed_count = 0
    
    for trans_id, recipient_name, photo_data in transactions:
        try:
            # Parse photo data
            if photo_data.startswith('['):
                # JSON array of photos
                photos = json.loads(photo_data)
                if isinstance(photos, list):
                    # Check which files exist
                    existing_photos = []
                    missing_photos = []
                    
                    for photo_path in photos:
                        if photo_path.startswith('customer_photos/'):
                            filename = photo_path.replace('customer_photos/', '')
                            full_path = os.path.join('uploads', 'customer_photos', filename)
                            
                            if os.path.exists(full_path):
                                existing_photos.append(photo_path)
                                print(f"  ✅ {filename} - exists")
                            else:
                                missing_photos.append(photo_path)
                                print(f"  ❌ {filename} - missing")
                    
                    # Update database if there were missing photos
                    if missing_photos:
                        if existing_photos:
                            # Update with only existing photos
                            if len(existing_photos) == 1:
                                new_photo_data = existing_photos[0]  # Single photo as string
                            else:
                                new_photo_data = json.dumps(existing_photos)  # Multiple photos as JSON
                            
                            cursor.execute('''
                                UPDATE transactions 
                                SET recipient_photo = ?
                                WHERE id = ?
                            ''', (new_photo_data, trans_id))
                            
                            print(f"  🔄 Updated transaction {trans_id} ({recipient_name})")
                            print(f"     Removed {len(missing_photos)} missing photos")
                            print(f"     Kept {len(existing_photos)} existing photos")
                            fixed_count += 1
                        else:
                            # No photos exist, set to NULL
                            cursor.execute('''
                                UPDATE transactions 
                                SET recipient_photo = NULL
                                WHERE id = ?
                            ''', (trans_id,))
                            
                            print(f"  🗑️  Removed all photos for transaction {trans_id} ({recipient_name}) - none exist")
                            fixed_count += 1
                    else:
                        print(f"  ✅ All photos exist for transaction {trans_id} ({recipient_name})")
            else:
                # Single photo
                if photo_data.startswith('customer_photos/'):
                    filename = photo_data.replace('customer_photos/', '')
                    full_path = os.path.join('uploads', 'customer_photos', filename)
                    
                    if not os.path.exists(full_path):
                        # Photo doesn't exist, remove reference
                        cursor.execute('''
                            UPDATE transactions 
                            SET recipient_photo = NULL
                            WHERE id = ?
                        ''', (trans_id,))
                        
                        print(f"  🗑️  Removed missing photo for transaction {trans_id} ({recipient_name}): {filename}")
                        fixed_count += 1
                    else:
                        print(f"  ✅ Photo exists for transaction {trans_id} ({recipient_name}): {filename}")
                        
        except Exception as e:
            print(f"  ❌ Error processing transaction {trans_id}: {e}")
    
    # Commit changes
    conn.commit()
    conn.close()
    
    print(f"\n🎉 Fixed {fixed_count} transactions with missing photos")
    print("=" * 50)

if __name__ == "__main__":
    fix_missing_photos()

#!/usr/bin/env python3
"""
Debug script to check photo storage and database entries
"""

import sqlite3
import os
import json

def check_database_photos():
    """Check what photos are stored in the database"""
    print("🔍 Checking database for photo entries...")
    print("=" * 50)
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Check transactions with photos
    cursor.execute('''
        SELECT id, recipient_name, recipient_phone, recipient_photo, transaction_date
        FROM transactions 
        WHERE recipient_photo IS NOT NULL AND recipient_photo != ''
        ORDER BY transaction_date DESC
        LIMIT 10
    ''')
    
    transactions = cursor.fetchall()
    
    if transactions:
        print(f"📊 Found {len(transactions)} transactions with photos:")
        for trans in transactions:
            photo_info = trans[3]
            photo_type = "Unknown"
            
            if photo_info:
                if photo_info.startswith('data:image'):
                    photo_type = "Base64 (not processed)"
                elif photo_info.startswith('customer_photos/'):
                    photo_type = "File path (processed)"
                elif photo_info.startswith('['):
                    try:
                        photo_array = json.loads(photo_info)
                        photo_type = f"JSON array ({len(photo_array)} photos)"
                    except:
                        photo_type = "JSON (invalid)"
                else:
                    photo_type = f"Other: {photo_info[:50]}..."
            
            print(f"  ID: {trans[0]}, Customer: {trans[1]}, Type: {photo_type}")
    else:
        print("❌ No transactions with photos found in database")
    
    # Check products with photos
    cursor.execute('''
        SELECT barcode, name, image_path
        FROM products 
        WHERE image_path IS NOT NULL AND image_path != ''
        LIMIT 10
    ''')
    
    products = cursor.fetchall()
    
    if products:
        print(f"\n📦 Found {len(products)} products with photos:")
        for prod in products:
            print(f"  Barcode: {prod[0]}, Name: {prod[1]}, Image: {prod[2]}")
    else:
        print("\n❌ No products with photos found in database")
    
    conn.close()

def check_file_system():
    """Check what photo files exist on disk"""
    print("\n🗂️  Checking file system for photos...")
    print("=" * 50)
    
    upload_folders = [
        'uploads/customer_photos',
        'uploads/product_photos', 
        'uploads/find-photos'
    ]
    
    total_files = 0
    
    for folder in upload_folders:
        if os.path.exists(folder):
            files = [f for f in os.listdir(folder) if f.endswith(('.jpg', '.jpeg', '.png'))]
            total_files += len(files)
            
            print(f"\n📁 {folder}: {len(files)} files")
            for i, file in enumerate(files[:5]):  # Show first 5 files
                file_path = os.path.join(folder, file)
                file_size = os.path.getsize(file_path)
                print(f"  {i+1}. {file} ({file_size/1024:.1f}KB)")
            
            if len(files) > 5:
                print(f"  ... and {len(files) - 5} more files")
        else:
            print(f"\n❌ {folder}: Directory doesn't exist")
    
    print(f"\n📊 Total photo files: {total_files}")

def check_web_interface_urls():
    """Check what URLs the web interface should use"""
    print("\n🌐 Web interface photo URLs...")
    print("=" * 50)
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Get a few transactions with photos to show expected URLs
    cursor.execute('''
        SELECT id, recipient_name, recipient_photo
        FROM transactions 
        WHERE recipient_photo IS NOT NULL AND recipient_photo != ''
        AND recipient_photo LIKE 'customer_photos/%'
        LIMIT 3
    ''')
    
    transactions = cursor.fetchall()
    
    if transactions:
        print("Expected photo URLs for web interface:")
        for trans in transactions:
            photo_path = trans[2]
            url = f"http://localhost:8080/uploads/{photo_path}"
            print(f"  Transaction {trans[0]} ({trans[1]}): {url}")
    
    conn.close()

def main():
    print("🔧 Photo System Debug Tool")
    print("=" * 50)
    
    # Change to server directory
    if not os.path.exists('inventory.db'):
        print("❌ inventory.db not found. Make sure you're running this from the server directory.")
        return
    
    check_database_photos()
    check_file_system()
    check_web_interface_urls()
    
    print("\n🎯 Common Issues and Solutions:")
    print("=" * 50)
    print("1. If photos show 'Unable to load image':")
    print("   - Check if photo files exist in uploads/ folders")
    print("   - Verify database has correct file paths (not base64)")
    print("   - Ensure server is serving /uploads/ correctly")
    
    print("\n2. If no photos in database:")
    print("   - Check if Flutter app is sending photos to server")
    print("   - Verify server is processing photo data correctly")
    print("   - Check server logs for errors during photo upload")
    
    print("\n3. If photos exist but don't display:")
    print("   - Check browser network tab for 404 errors")
    print("   - Verify photo file permissions")
    print("   - Test direct URL access: http://localhost:8080/uploads/customer_photos/filename.jpg")

if __name__ == "__main__":
    main()

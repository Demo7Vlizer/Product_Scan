#!/usr/bin/env python3
"""
Test script to verify photo integration between Flutter app and backend server
"""

import requests
import base64
import json
from datetime import datetime

# Configuration
BASE_URL = "http://localhost:8080"  # Adjust if your server runs on different port

def test_photo_compression_detection():
    """Test that backend properly detects pre-compressed images"""
    
    # Simulate a small pre-compressed image (like from Flutter)
    small_image_data = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
    
    # Test adding a product with pre-compressed image
    product_data = {
        "barcode": "TEST123456",
        "name": "Test Product",
        "mrp": 10.00,
        "quantity": 5,
        "image_path": small_image_data
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/products", json=product_data)
        if response.status_code == 200:
            print("✅ Product with pre-compressed image added successfully")
            result = response.json()
            print(f"   Server response: {result.get('Result', 'Unknown')}")
        else:
            print(f"❌ Failed to add product: {response.status_code}")
            print(f"   Error: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
    
    return True

def test_transaction_with_photo():
    """Test transaction with customer photo"""
    
    # Simulate a customer photo (small, pre-compressed)
    customer_photo = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
    
    transaction_data = {
        "barcode": "TEST123456",
        "transaction_type": "OUT",
        "quantity": 1,
        "recipient_name": "Test Customer",
        "recipient_phone": "1234567890",
        "recipient_photo": customer_photo,
        "notes": "Test transaction with photo"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/transactions", json=transaction_data)
        if response.status_code == 200:
            print("✅ Transaction with customer photo added successfully")
            result = response.json()
            print(f"   Server response: {result.get('Result', 'Unknown')}")
        else:
            print(f"❌ Failed to add transaction: {response.status_code}")
            print(f"   Error: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
    
    return True

def test_multi_photo_array():
    """Test multi-item sale with photo array"""
    
    # Simulate multiple photos as JSON array (from multi-item sale)
    photo_array = [
        "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=",
        "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=",
        "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
    ]
    
    bulk_update_data = {
        "recipient_name": "Multi Item Customer",
        "recipient_phone": "9876543210",
        "recipient_photo": json.dumps(photo_array),  # JSON array of photos
        "items": [
            {"barcode": "TEST123456", "quantity": 2},
            {"barcode": "TEST789012", "quantity": 1}
        ]
    }
    
    try:
        response = requests.put(f"{BASE_URL}/api/transactions/bulk-update", json=bulk_update_data)
        if response.status_code == 200:
            print("✅ Multi-item sale with photo array processed successfully")
            result = response.json()
            print(f"   Server response: {result.get('Result', 'Unknown')}")
        else:
            print(f"❌ Failed to process multi-item sale: {response.status_code}")
            print(f"   Error: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
    
    return True

def test_server_status():
    """Test if server is running"""
    try:
        response = requests.get(f"{BASE_URL}/")
        if response.status_code == 200:
            print("✅ Server is running and accessible")
            return True
        else:
            print(f"❌ Server responded with status: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to server: {e}")
        print(f"   Make sure the server is running on {BASE_URL}")
        return False

def main():
    """Run all photo integration tests"""
    print("🧪 Testing Photo Integration Between Flutter App and Backend Server")
    print("=" * 70)
    
    # Test server status first
    if not test_server_status():
        print("\n❌ Server is not accessible. Please start the server first.")
        print("   Run: cd server && python app.py")
        return
    
    print("\n1. Testing photo compression detection...")
    test_photo_compression_detection()
    
    print("\n2. Testing transaction with customer photo...")
    test_transaction_with_photo()
    
    print("\n3. Testing multi-item sale with photo array...")
    test_multi_photo_array()
    
    print("\n" + "=" * 70)
    print("🎉 Photo integration tests completed!")
    print("\nTo verify results:")
    print(f"   1. Open {BASE_URL} in your browser")
    print("   2. Check the 'Products' and 'Transactions' tabs")
    print("   3. Look for camera icons indicating photos are attached")
    print("   4. Click camera icons to view photos")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3

import requests
import json

try:
    print("🔍 Testing customer photos API...")
    
    # Test the new API endpoint
    url = "http://localhost:8080/api/customer-photos/Rahuls/82884649494"
    print(f"📡 Calling: {url}")
    
    response = requests.get(url, timeout=10)
    print(f"📊 Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print("✅ API Response:")
        print(json.dumps(data, indent=2))
        
        if data.get('success'):
            print(f"🎉 Found {data.get('count', 0)} photos!")
            for i, photo in enumerate(data.get('photos', []), 1):
                print(f"  📷 Photo {i}: {photo}")
        else:
            print("❌ API returned success=false")
    else:
        print(f"❌ API Error: {response.status_code}")
        print(f"Response: {response.text}")
        
except requests.exceptions.ConnectionError:
    print("❌ Could not connect to server. Is it running?")
except Exception as e:
    print(f"❌ Error: {e}")

print("\n🔍 Also checking if photos exist in filesystem...")
import os
import glob

photos_folder = "uploads/customer_photos"
pattern = os.path.join(photos_folder, "customer_Rahuls_82884649494_*.jpg")
print(f"📂 Looking for pattern: {pattern}")

files = glob.glob(pattern)
if files:
    print(f"✅ Found {len(files)} files in filesystem:")
    for f in sorted(files):
        print(f"  📷 {f}")
else:
    print("❌ No files found in filesystem")

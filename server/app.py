from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import sqlite3
import os
import json
from datetime import datetime, timezone, timedelta
import base64
from werkzeug.utils import secure_filename
import io

# Try to import PIL, fallback gracefully if not available
try:
    from PIL import Image
    COMPRESSION_AVAILABLE = True
    print("Image compression enabled (Pillow available)")
except ImportError:
    COMPRESSION_AVAILABLE = False
    print("Image compression disabled (Pillow not installed). Run: pip install Pillow")

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

# Configure upload folders
UPLOAD_FOLDER = 'uploads'
PRODUCT_PHOTOS_FOLDER = os.path.join(UPLOAD_FOLDER, 'product_photos')
CUSTOMER_PHOTOS_FOLDER = os.path.join(UPLOAD_FOLDER, 'customer_photos')
FIND_PHOTOS_FOLDER = os.path.join(UPLOAD_FOLDER, 'find-photos')

# Create directories if they don't exist
for folder in [UPLOAD_FOLDER, PRODUCT_PHOTOS_FOLDER, CUSTOMER_PHOTOS_FOLDER, FIND_PHOTOS_FOLDER]:
    if not os.path.exists(folder):
        os.makedirs(folder)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['PRODUCT_PHOTOS_FOLDER'] = PRODUCT_PHOTOS_FOLDER
app.config['CUSTOMER_PHOTOS_FOLDER'] = CUSTOMER_PHOTOS_FOLDER
app.config['FIND_PHOTOS_FOLDER'] = FIND_PHOTOS_FOLDER

# Helper function to get local timestamp
def get_local_timestamp():
    """Get current timestamp in local timezone"""
    # You can adjust the timezone offset here if needed
    # For India (IST), UTC+5:30
    ist = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(ist).strftime('%Y-%m-%d %H:%M:%S')

# Database setup
def init_db():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Products table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            image_path TEXT,
            mrp REAL,
            quantity INTEGER DEFAULT 0,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Transactions table (Product In/Out)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT NOT NULL,
            transaction_type TEXT NOT NULL, -- 'IN' or 'OUT'
            quantity INTEGER NOT NULL,
            recipient_name TEXT,
            recipient_phone TEXT,
            recipient_photo TEXT,
            transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            notes TEXT
        )
    ''')
    
    # Customers table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT UNIQUE NOT NULL,
            address TEXT,
            email TEXT,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Product Location Photos table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS product_location_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name TEXT NOT NULL,
            location_name TEXT NOT NULL,
            image_path TEXT NOT NULL,
            notes TEXT,
            created_date TEXT,
            updated_date TEXT
        )
    ''')
    
    # Product Location Images table (for multiple images per location)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS product_location_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            location_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            image_order INTEGER DEFAULT 1,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (location_id) REFERENCES product_location_photos (id) ON DELETE CASCADE
        )
    ''')
    
    conn.commit()
    conn.close()

# Initialize database
init_db()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/server-status', methods=['GET'])
def get_server_status():
    """Simple endpoint to confirm server is running and return basic info"""
    local_ip = get_local_ip()
    return jsonify({
        'status': 'running',
        'ip': local_ip,
        'port': 8080,
        'url': f'http://{local_ip}:8080',
        'message': 'Server is running successfully'
    })

@app.route('/api/products/<barcode>', methods=['GET'])
def get_product_by_barcode(barcode):
    """Get a specific product by barcode"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            SELECT barcode, name, mrp, quantity, created_date, image_path
            FROM products 
            WHERE barcode = ?
        ''', (barcode,))
        
        product = cursor.fetchone()
        conn.close()
        
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        product_dict = {
            'barcode': product[0],
            'name': product[1],
            'mrp': product[2],
            'quantity': product[3],
            'created_date': product[4],
            'image_path': product[5]
        }
        
        return jsonify({'Result': product_dict}), 200
        
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 500

@app.route('/api/products/<barcode>/export', methods=['GET'])
def export_product_data(barcode):
    """Export product data as JSON"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Get product details
        cursor.execute('''
            SELECT barcode, name, mrp, quantity, created_date, image_path
            FROM products 
            WHERE barcode = ?
        ''', (barcode,))
        
        product = cursor.fetchone()
        if not product:
            conn.close()
            return jsonify({'error': 'Product not found'}), 404
        
        # Get transaction history
        cursor.execute('''
            SELECT transaction_type, quantity, transaction_date, notes
            FROM transactions 
            WHERE barcode = ?
            ORDER BY transaction_date DESC
        ''', (barcode,))
        
        transactions = cursor.fetchall()
        conn.close()
        
        # Build export data
        product_data = {
            'product_info': {
                'barcode': product[0],
                'name': product[1],
                'mrp': product[2],
                'quantity': product[3],
                'created_date': product[4],
                'image_path': product[5]
            },
            'transaction_history': [
                {
                    'transaction_type': t[0],
                    'quantity': t[1],
                    'transaction_date': t[2],
                    'notes': t[3]
                } for t in transactions
            ],
            'statistics': {
                'total_transactions': len(transactions),
                'total_sold': sum(t[1] for t in transactions if t[0] == 'out'),
                'total_restocked': sum(t[1] for t in transactions if t[0] == 'in'),
                'export_date': datetime.now().isoformat()
            }
        }
        
        # Create response with download headers
        response = jsonify(product_data)
        response.headers['Content-Disposition'] = f'attachment; filename=product_{barcode}_export.json'
        response.headers['Content-Type'] = 'application/json'
        
        return response
        
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 500

@app.route('/api/products', methods=['GET'])
def get_products():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM products ORDER BY created_date DESC')
    products = cursor.fetchall()
    conn.close()
    
    product_list = []
    for product in products:
        product_list.append({
            'id': product[0],
            'barcode': product[1],
            'name': product[2],
            'image_path': product[3],
            'mrp': product[4],
            'quantity': product[5],
            'created_date': product[6]
        })
    
    return jsonify({'Result': product_list})

@app.route('/api/products/<barcode>', methods=['GET'])
def get_product(barcode):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM products WHERE barcode = ?', (barcode,))
    product = cursor.fetchone()
    conn.close()
    
    if product:
        return jsonify({
            'Result': {
                'id': product[0],
                'barcode': product[1],
                'name': product[2],
                'image_path': product[3],
                'mrp': product[4],
                'quantity': product[5],
                'created_date': product[6]
            }
        })
    else:
        return jsonify({'Result': None}), 404

@app.route('/api/products', methods=['POST'])
def add_product():
    data = request.json
    
    # Handle image upload if provided
    image_path = None
    if 'image_path' in data and data['image_path']:
        print(f"🔧 DEBUG: Received image data length: {len(data['image_path'])} characters")
        print(f"🔧 DEBUG: Image data starts with: {data['image_path'][:50]}...")
        
        # Process and save compressed image to product_photos folder
        filename = f"{data['barcode']}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        
        # Enable maximum compression for product images
        success, full_path, error_msg = process_and_save_image(
            data['image_path'], 
            filename, 
            app.config['PRODUCT_PHOTOS_FOLDER'],
            compress=True  # Enable maximum compression
        )
        
        print(f"🔧 DEBUG: Save result - Success: {success}, Path: {full_path}, Error: {error_msg}")
        
        if not success:
            return jsonify({'error': f'Failed to process product image: {error_msg}'}), 400
        
        # Check file size after saving
        if os.path.exists(full_path):
            file_size = os.path.getsize(full_path)
            print(f"🔧 DEBUG: Saved file size: {file_size} bytes")
            if file_size < 100:
                print(f"🔧 DEBUG: WARNING - File too small, likely corrupted!")
        
        # Save relative path in database (product_photos/filename)
        image_path = f"product_photos/{filename}"
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO products (barcode, name, image_path, mrp, quantity)
            VALUES (?, ?, ?, ?, ?)
        ''', (data['barcode'], data['name'], image_path, data.get('mrp'), data.get('quantity', 0)))
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Product added successfully'})
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'Product with this barcode already exists'}), 400

@app.route('/api/products/<barcode>', methods=['PUT'])
def update_product(barcode):
    try:
        data = request.json
        print(f"Updating product {barcode} with data: {data}")
    
        conn = sqlite3.connect('inventory.db')
        cursor = conn.cursor()
    
        # Check if product exists and get current image path
        cursor.execute('SELECT image_path FROM products WHERE barcode = ?', (barcode,))
        current_product = cursor.fetchone()
        if not current_product:
            conn.close()
            return jsonify({'error': 'Product not found'}), 404
        
        old_image_path = current_product[0] if current_product[0] else None

        # Handle image upload if provided
        image_path = None
        update_image = False
        
        if 'image_path' in data:
            if data['image_path'] and data['image_path'].startswith('data:image'):
                # New image provided - first delete old image, then save new one
                try:
                    # Delete old image file if it exists (products don't need safety check as they're unique per barcode)
                    if old_image_path:
                        if old_image_path.startswith('product_photos/'):
                            # New format: product_photos/filename
                            old_file_path = os.path.join(app.config['UPLOAD_FOLDER'], old_image_path)
                        else:
                            # Old format: just filename (assume it's in uploads root)
                            old_file_path = os.path.join(app.config['UPLOAD_FOLDER'], old_image_path)
                        
                        if os.path.exists(old_file_path):
                            os.remove(old_file_path)
                            print(f"Deleted old product image: {old_image_path}")
                    
                    # Process and save compressed image to product_photos folder
                    filename = f"{barcode}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
                    success, full_path, error_msg = process_and_save_image(
                        data['image_path'], 
                        filename, 
                        app.config['PRODUCT_PHOTOS_FOLDER'],
                        compress=True
                    )
                    
                    if not success:
                        conn.close()
                        return jsonify({'error': f'Failed to process product image: {error_msg}'}), 400
        
                    # Save relative path in database (product_photos/filename)
                    image_path = f"product_photos/{filename}"
                    update_image = True
                    print(f"New compressed product image saved: {filename}")
                except Exception as img_error:
                    conn.close()
                    print(f"Error processing product image: {img_error}")
                    return jsonify({'error': f'Error processing image: {str(img_error)}'}), 400
            # If image_path is null or empty, don't update the image field
        
        # Update product
        if update_image:
            cursor.execute('''
                UPDATE products 
                SET name = ?, image_path = ?, mrp = ?, quantity = ?
                WHERE barcode = ?
            ''', (data['name'], image_path, data.get('mrp'), data.get('quantity', 0), barcode))
            print(f"Updated product with new image: {image_path}")
        else:
            cursor.execute('''
                UPDATE products 
                SET name = ?, mrp = ?, quantity = ?
                WHERE barcode = ?
            ''', (data['name'], data.get('mrp'), data.get('quantity', 0), barcode))
            print(f"Updated product without changing image")
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Product updated successfully'})
        
    except Exception as e:
        print(f"Error updating product: {e}")
        if 'conn' in locals():
            conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/products/<barcode>', methods=['DELETE'])
def delete_product(barcode):
    """Delete a product and its associated photo file"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Get product info for deletion summary
        cursor.execute('SELECT name, image_path FROM products WHERE barcode = ?', (barcode,))
        product_info = cursor.fetchone()
        
        if not product_info:
            conn.close()
            return jsonify({'error': 'Product not found'}), 404
        
        product_name, image_path = product_info
        deleted_files = []
        failed_deletions = []
        
        # Delete the product image file if it exists
        if image_path:
            try:
                # Handle both old and new path formats
                if image_path.startswith('product_photos/'):
                    # New format: product_photos/filename
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path)
                elif image_path.startswith('uploads/'):
                    # Handle uploads/ prefix
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path.replace('uploads/', ''))
                else:
                    # Old format: just filename (assume it's in uploads root)
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path)
                
                if os.path.exists(file_path):
                    os.remove(file_path)
                    deleted_files.append(image_path)
                    print(f"✅ Deleted product image: {file_path}")
                else:
                    print(f"⚠️ Product image file not found: {file_path}")
            except Exception as e:
                failed_deletions.append(f"Product image ({image_path}): {str(e)}")
                print(f"❌ Error deleting product image {image_path}: {e}")
        
        # Delete the product from database
        cursor.execute('DELETE FROM products WHERE barcode = ?', (barcode,))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'Product not found'}), 404
        
        conn.commit()
        conn.close()
        
        # Prepare response with deletion summary
        response_data = {
            'Result': 'Product deleted successfully',
            'product_info': {
                'barcode': barcode,
                'name': product_name
            },
            'deletion_summary': {
                'database_records_deleted': 1,
                'photo_files_deleted': len(deleted_files),
                'deleted_files': deleted_files
            }
        }
        
        if failed_deletions:
            response_data['warnings'] = {
                'failed_file_deletions': failed_deletions,
                'message': 'Product deleted but photo file could not be removed'
            }
        
        print(f"🗑️ Product deletion completed:")
        print(f"   📦 Product: {product_name} ({barcode})")
        print(f"   📊 Database records deleted: 1")
        print(f"   📸 Photo files deleted: {len(deleted_files)}")
        if failed_deletions:
            print(f"   ⚠️ Failed deletions: {len(failed_deletions)}")
        
        return jsonify(response_data)
        
    except Exception as e:
        conn.close()
        print(f"❌ Error in delete_product: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/api/products/search/<query>', methods=['GET'])
def search_products(query):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT * FROM products 
        WHERE name LIKE ? OR barcode LIKE ?
        ORDER BY created_date DESC
    ''', (f'%{query}%', f'%{query}%'))
    products = cursor.fetchall()
    conn.close()
    
    product_list = []
    for product in products:
        product_list.append({
            'id': product[0],
            'barcode': product[1],
            'name': product[2],
            'image_path': product[3],
            'mrp': product[4],
            'quantity': product[5],
            'created_date': product[6]
        })
    
    return jsonify({'Result': product_list})

@app.route('/api/transactions', methods=['POST'])
def add_transaction():
    data = request.json
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Process photo if provided
        processed_photo = None
        recipient_photo = data.get('recipient_photo')
        
        if recipient_photo:
            # Handle JSON array of photos (from multi-item sales)
            try:
                import json
                photo_array = json.loads(recipient_photo)
                if isinstance(photo_array, list) and len(photo_array) > 0:
                    # Process and save ALL photos from the array
                    processed_photos = []
                    recipient_name = data.get('recipient_name', 'Unknown')
                    recipient_phone = data.get('recipient_phone', '')
                    customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                    
                    for i, photo in enumerate(photo_array):
                        if photo and photo.startswith('data:image'):
                            # Create unique filename for each photo
                            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                            filename = f"customer_{customer_key}_{timestamp}_{i+1}.jpg"
                            
                            success, full_path, error_msg = process_and_save_image(
                                photo, 
                                filename, 
                                app.config['CUSTOMER_PHOTOS_FOLDER'],
                                compress=True
                            )
                            
                            if success:
                                processed_photos.append(f"customer_photos/{filename}")
                                print(f'Transaction creation: Processed photo {i+1} of {len(photo_array)}')
                            else:
                                print(f'Failed to process photo {i+1}: {error_msg}')
                                processed_photos.append(photo)  # Keep original if processing fails
                        else:
                            processed_photos.append(photo)
                    
                    # Store as JSON array if multiple photos, single string if one photo
                    if len(processed_photos) > 1:
                        processed_photo = json.dumps(processed_photos)
                        print(f'Transaction creation: Saved {len(processed_photos)} photos as JSON array')
                    elif len(processed_photos) == 1:
                        processed_photo = processed_photos[0]
                        print(f'Transaction creation: Saved single photo')
                    else:
                        processed_photo = recipient_photo
                else:
                    processed_photo = recipient_photo
            except (ValueError, TypeError):
                # Not JSON, handle as single photo
                if recipient_photo.startswith('data:image'):
                    # Process single base64 photo
                    recipient_name = data.get('recipient_name', 'Unknown')
                    recipient_phone = data.get('recipient_phone', '')
                    customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                    filename = f"customer_{customer_key}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
                    
                    success, full_path, error_msg = process_and_save_image(
                        recipient_photo, 
                        filename, 
                        app.config['CUSTOMER_PHOTOS_FOLDER'],
                        compress=True
                    )
                    
                    if success:
                        processed_photo = f"customer_photos/{filename}"
                        print(f'Transaction creation: Processed single customer photo')
                    else:
                        print(f'Failed to process single transaction photo: {error_msg}')
                        processed_photo = recipient_photo  # Keep original if processing fails
                else:
                    processed_photo = recipient_photo
        
        # Add transaction record with processed photo
        cursor.execute('''
            INSERT INTO transactions (barcode, transaction_type, quantity, recipient_name, recipient_phone, recipient_photo, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['barcode'],
            data['transaction_type'],
            data['quantity'],
            data.get('recipient_name'),
            data.get('recipient_phone'),
            processed_photo,
            data.get('notes')
        ))
        
        # Update product quantity
        if data['transaction_type'] == 'IN':
            cursor.execute('''
                UPDATE products SET quantity = quantity + ? WHERE barcode = ?
            ''', (data['quantity'], data['barcode']))
        else:  # OUT
            cursor.execute('''
                UPDATE products SET quantity = quantity - ? WHERE barcode = ?
            ''', (data['quantity'], data['barcode']))
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Transaction recorded successfully'})
    except Exception as e:
        conn.close()
        print(f'Error in add_transaction: {e}')
        return jsonify({'error': str(e)}), 400

@app.route('/api/transactions', methods=['GET'])
def get_transactions():
    barcode_filter = request.args.get('barcode')
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    if barcode_filter:
        # Filter by specific barcode
        cursor.execute('''
            SELECT t.*, p.name as product_name 
            FROM transactions t 
            LEFT JOIN products p ON t.barcode = p.barcode 
            WHERE t.barcode = ?
            ORDER BY transaction_date DESC
        ''', (barcode_filter,))
    else:
        # Get all transactions
        cursor.execute('''
            SELECT t.*, p.name as product_name 
            FROM transactions t 
            LEFT JOIN products p ON t.barcode = p.barcode 
            ORDER BY transaction_date DESC
        ''')
    
    transactions = cursor.fetchall()
    conn.close()
    
    transaction_list = []
    for trans in transactions:
        transaction_list.append({
            'id': trans[0],
            'barcode': trans[1],
            'transaction_type': trans[2],
            'quantity': trans[3],
            'recipient_name': trans[4],
            'recipient_phone': trans[5],
            'recipient_photo': trans[6],
            'transaction_date': trans[7],
            'notes': trans[8],
            'product_name': trans[9]
        })
    
    return jsonify({'Result': transaction_list})

@app.route('/api/transactions/grouped', methods=['GET'])
def get_grouped_transactions():
    """Get transactions grouped by customer, date, and notes (for multi-item sales)"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT t.*, p.name as product_name 
        FROM transactions t 
        LEFT JOIN products p ON t.barcode = p.barcode 
        WHERE t.transaction_type = 'OUT'
        ORDER BY t.transaction_date DESC, t.id DESC
    ''')
    transactions = cursor.fetchall()
    conn.close()
    
    # Group transactions by customer, date, and notes
    grouped_sales = {}
    
    for trans in transactions:
        # Create a unique key for grouping
        date_part = trans[7][:16] if trans[7] else ''  # transaction_date up to minutes
        group_key = f"{trans[4] or 'Unknown'}_{trans[5] or ''}_{date_part}_{trans[8] or ''}"  # name_phone_date_notes
        
        if group_key not in grouped_sales:
            grouped_sales[group_key] = {
                'id': trans[0],  # Use first transaction ID
                'customer_name': trans[4] or 'Unknown Customer',
                'customer_phone': trans[5] or '',
                'recipient_photo': '',  # decide below with replacement rules
                'transaction_date': trans[7],
                'notes': trans[8] or '',
                'items': [],
                'total_quantity': 0,
                'total_amount': 0.0,
                'is_multi_item': False
            }

        # Choose the best/most recent photo for the group
        try:
            current_photo = grouped_sales[group_key]['recipient_photo'] or ''
            new_photo = trans[6] or ''
            if new_photo:
                def is_filename(photo: str) -> bool:
                    return not photo.startswith('data:image') and photo.endswith('.jpg')

                # Replacement rules:
                # - Prefer filename (server-saved) over base64
                # - If both filenames, prefer lexicographically larger (contains timestamp)
                # - If current empty, take new
                should_replace = False
                if not current_photo:
                    should_replace = True
                elif is_filename(new_photo) and not is_filename(current_photo):
                    should_replace = True
                elif is_filename(new_photo) and is_filename(current_photo):
                    if new_photo > current_photo:
                        should_replace = True

                if should_replace:
                    grouped_sales[group_key]['recipient_photo'] = new_photo
        except Exception:
            # On any error, keep existing photo selection
            pass
        
        # Add item to the group
        item_info = {
            'transaction_id': trans[0],
            'barcode': trans[1],
            'product_name': trans[9] or 'Unknown Product',
            'quantity': trans[3] or 0,
            'mrp': 0.0  # We'll calculate this from products if needed
        }
        
        grouped_sales[group_key]['items'].append(item_info)
        grouped_sales[group_key]['total_quantity'] += item_info['quantity']
        
        # Mark as multi-item if more than one item
        if len(grouped_sales[group_key]['items']) > 1:
            grouped_sales[group_key]['is_multi_item'] = True
    
    # Convert to list and sort by date
    result = []
    for group in grouped_sales.values():
        # Calculate total amount from notes if available
        if group['notes'] and 'Total:' in group['notes']:
            try:
                # Extract total from notes like "Multi-item sale - Total: ₹1510.00"
                total_str = group['notes'].split('Total:')[1].strip()
                total_str = total_str.replace('₹', '').replace(',', '')
                group['total_amount'] = float(total_str)
            except:
                group['total_amount'] = 0.0
        
        result.append(group)
    
    # Sort by transaction date (newest first)
    result.sort(key=lambda x: x['transaction_date'] or '', reverse=True)
    
    return jsonify({'Result': result})

# Bulk update transactions endpoint (for editing multi-item sales)
@app.route('/api/transactions/bulk-update', methods=['PUT'])
def bulk_update_transactions():
    """Update multiple transactions for a sale, creating missing ones if needed"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    data = request.get_json()
    recipient_name = data.get('recipient_name')
    recipient_phone = data.get('recipient_phone')
    recipient_photo = data.get('recipient_photo')
    items = data.get('items', [])  # List of items with barcode, quantity, etc.
    
    try:
        print(f'Bulk updating transactions for {recipient_name}')
        print(f'Items to update: {len(items)}')
        
        # Process each item
        for item_data in items:
            barcode = item_data.get('barcode')
            quantity = item_data.get('quantity')
            transaction_id = item_data.get('transaction_id')
            
            if transaction_id:
                # Try to update existing transaction
                cursor.execute('SELECT id FROM transactions WHERE id = ?', (transaction_id,))
                if cursor.fetchone():
                    cursor.execute('''
                        UPDATE transactions 
                        SET recipient_name = ?, recipient_phone = ?, quantity = ?
                        WHERE id = ?
                    ''', (recipient_name, recipient_phone, quantity, transaction_id))
                    print(f'Updated existing transaction {transaction_id}')
                else:
                    print(f'Transaction {transaction_id} not found, will create new one')
                    transaction_id = None
            
            if not transaction_id:
                # Create new transaction
                cursor.execute('''
                    INSERT INTO transactions (barcode, transaction_type, quantity, recipient_name, recipient_phone, notes)
                    VALUES (?, 'OUT', ?, ?, ?, 'Updated from edit')
                ''', (barcode, quantity, recipient_name, recipient_phone))
                new_id = cursor.lastrowid
                print(f'Created new transaction {new_id} for {barcode}')
        
        # Update photo for all transactions with this customer
        if recipient_photo:
            # Handle JSON array of photos (from multi-item sales)
            processed_photo = recipient_photo
            try:
                import json
                photo_array = json.loads(recipient_photo)
                if isinstance(photo_array, list) and len(photo_array) > 0:
                    # Process and save ALL photos from the array
                    processed_photos = []
                    customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                    
                    for i, photo in enumerate(photo_array):
                        if photo and photo.startswith('data:image'):
                            # Create unique filename for each photo
                            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                            filename = f"customer_{customer_key}_{timestamp}_{i+1}.jpg"
                            
                            success, full_path, error_msg = process_and_save_image(
                                photo, 
                                filename, 
                                app.config['CUSTOMER_PHOTOS_FOLDER'],
                                compress=True
                            )
                            
                            if success:
                                processed_photos.append(f"customer_photos/{filename}")
                                print(f'Bulk update: Processed photo {i+1} of {len(photo_array)}')
                            else:
                                print(f'Failed to process photo {i+1}: {error_msg}')
                                processed_photos.append(photo)
                        else:
                            processed_photos.append(photo)
                    
                    # Store as JSON array if multiple photos, single string if one photo
                    if len(processed_photos) > 1:
                        processed_photo = json.dumps(processed_photos)
                        print(f'Bulk update: Saved {len(processed_photos)} photos as JSON array')
                    elif len(processed_photos) == 1:
                        processed_photo = processed_photos[0]
                        print(f'Bulk update: Saved single photo')
                    else:
                        processed_photo = recipient_photo
                else:
                    processed_photo = recipient_photo
            except (ValueError, TypeError):
                # Not JSON, use original value
                pass
            
            cursor.execute('''
                UPDATE transactions 
                SET recipient_photo = ?
                WHERE recipient_name = ? AND recipient_phone = ? AND transaction_type = 'OUT'
            ''', (processed_photo, recipient_name, recipient_phone))
        
        conn.commit()
        conn.close()
        return jsonify({'Result': 'Transactions updated successfully'})
        
    except Exception as e:
        conn.close()
        print(f'Error in bulk update: {e}')
        return jsonify({'error': str(e)}), 400

# Update transaction endpoint (for editing sales)
@app.route('/api/transactions/<int:transaction_id>', methods=['PUT'])
def update_transaction(transaction_id):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    data = request.get_json()
    recipient_name = data.get('recipient_name')
    recipient_phone = data.get('recipient_phone')
    quantity = data.get('quantity')
    recipient_photo = data.get('recipient_photo')
    
    try:
        print(f'Updating transaction {transaction_id} for {recipient_name}')
        print(f'Photo provided: {recipient_photo is not None and len(recipient_photo) > 0 if recipient_photo else False}')
        print(f'Quantity: {quantity}')
        print(f'Phone: {recipient_phone}')
        
        # First, check if transaction exists and get current photo path
        cursor.execute('SELECT recipient_photo FROM transactions WHERE id = ?', (transaction_id,))
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            print(f'Transaction {transaction_id} not found in database')
            # Instead of returning 404, try to find a similar transaction
            # This handles cases where the transaction ID from consolidated view doesn't match actual IDs
            return jsonify({'error': f'Transaction with ID {transaction_id} not found. This might be from a consolidated sale view.'}), 404
            
        old_photo_path = result[0] if result[0] else None
        print(f'Old photo path: {old_photo_path}')
        
        # Handle photo processing if provided
        new_photo_path = None
        if recipient_photo:
            # Check if it's a JSON array of photos (from multi-item sales)
            try:
                import json
                photo_array = json.loads(recipient_photo)
                if isinstance(photo_array, list) and len(photo_array) > 0:
                    # Process the first photo from the array
                    first_photo = photo_array[0]
                    if first_photo and first_photo.startswith('data:image'):
                        recipient_photo = first_photo
                        print(f'Processing first photo from array of {len(photo_array)} photos')
                    else:
                        recipient_photo = first_photo
            except (ValueError, TypeError):
                # Not JSON, continue with original value
                pass
            
            if recipient_photo.startswith('data:image'):
                try:
                    # First, process and save the new compressed customer photo
                    customer_key = f"{recipient_name}_{recipient_phone}".replace(' ', '_').replace('+', '').replace('(', '').replace(')', '')
                    filename = f"customer_{customer_key}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
                    
                    success, full_path, error_msg = process_and_save_image(
                        recipient_photo, 
                        filename, 
                        app.config['CUSTOMER_PHOTOS_FOLDER'],
                        compress=True
                    )
                    
                    if not success:
                        conn.close()
                        return jsonify({'error': f'Failed to process customer photo: {error_msg}'}), 400
                    
                    # Save relative path in database (customer_photos/filename)
                    new_photo_path = f"customer_photos/{filename}"
                    print(f'New compressed customer photo saved as: {filename}')
                    
                    # Store old photo path for deletion after database update
                    old_photo_to_delete = old_photo_path
                except Exception as e:
                    conn.close()
                    return jsonify({'error': f'Failed to process photo: {str(e)}'}), 400
            else:
                # If it's not base64, assume it's a filename to keep
                new_photo_path = recipient_photo
        
        # Update transaction with or without photo
        if new_photo_path is not None:
            cursor.execute('''
                UPDATE transactions 
                SET recipient_name = ?, recipient_phone = ?, quantity = ?, recipient_photo = ?
                WHERE id = ?
            ''', (recipient_name, recipient_phone, quantity, new_photo_path, transaction_id))
            
            # Also update all other transactions with the same customer and similar timestamp (multi-item sales)
            # Get the transaction date for this transaction
            cursor.execute('SELECT transaction_date FROM transactions WHERE id = ?', (transaction_id,))
            transaction_date_result = cursor.fetchone()
            if transaction_date_result:
                transaction_date = transaction_date_result[0]
                
                # First, get all related transactions to delete their old photos
                cursor.execute('''
                    SELECT id, recipient_photo FROM transactions 
                    WHERE recipient_name = ? AND recipient_phone = ? 
                    AND datetime(transaction_date) BETWEEN datetime(?) AND datetime(?, '+1 minute')
                    AND id != ? AND recipient_photo IS NOT NULL AND recipient_photo != ?
                ''', (recipient_name, recipient_phone, transaction_date, transaction_date, transaction_id, new_photo_path))
                
                related_transactions = cursor.fetchall()
                
                # Update all transactions with same customer and date (within 1 minute) with the new photo
                cursor.execute('''
                    UPDATE transactions 
                    SET recipient_photo = ?
                    WHERE recipient_name = ? AND recipient_phone = ? 
                    AND datetime(transaction_date) BETWEEN datetime(?) AND datetime(?, '+1 minute')
                    AND id != ?
                ''', (new_photo_path, recipient_name, recipient_phone, transaction_date, transaction_date, transaction_id))
                
                updated_count = cursor.rowcount
                if updated_count > 0:
                    print(f'Updated {updated_count} related transactions with new photo')
                
                # Now safely delete old photos from related transactions AFTER database update
                for trans_id, old_related_photo in related_transactions:
                    if old_related_photo and old_related_photo != new_photo_path:
                        safe_delete_photo(old_related_photo, trans_id)
        else:
            cursor.execute('''
                UPDATE transactions 
                SET recipient_name = ?, recipient_phone = ?, quantity = ?
                WHERE id = ?
            ''', (recipient_name, recipient_phone, quantity, transaction_id))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'Transaction not found'}), 404
        
        conn.commit()
        
        # After successful database commit, aggressively delete old customer photos
        if 'old_photo_to_delete' in locals() and old_photo_to_delete and new_photo_path:
            # Use aggressive deletion for customer photos since we want to replace all old ones
            force_delete_customer_old_photos(recipient_name, recipient_phone, new_photo_path)
        
        conn.close()
        return jsonify({'Result': 'Transaction updated successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

# Delete transaction endpoint
@app.route('/api/transactions/<int:transaction_id>', methods=['DELETE'])
def delete_transaction(transaction_id):
    """Delete a transaction and all associated customer photos"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Get transaction details including customer photos
        cursor.execute('''
            SELECT barcode, transaction_type, quantity, recipient_name, recipient_photo 
            FROM transactions WHERE id = ?
        ''', (transaction_id,))
        transaction = cursor.fetchone()
        
        if not transaction:
            conn.close()
            return jsonify({'error': 'Transaction not found'}), 404
        
        barcode, transaction_type, quantity, recipient_name, recipient_photo = transaction
        deleted_files = []
        failed_deletions = []
        
        # Delete customer photos if they exist
        if recipient_photo:
            try:
                # Parse photos - could be single photo or JSON array
                photos = []
                try:
                    # Try to parse as JSON array first
                    photos = json.loads(recipient_photo)
                    if not isinstance(photos, list):
                        photos = [recipient_photo]  # Single photo
                except:
                    # Not JSON, treat as single photo
                    photos = [recipient_photo]
                
                # Delete each photo file
                for photo_path in photos:
                    if photo_path and not photo_path.startswith('data:image'):
                        try:
                            # Handle different path formats
                            if photo_path.startswith('customer_photos/'):
                                file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo_path)
                            elif photo_path.startswith('uploads/'):
                                file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo_path.replace('uploads/', ''))
                            else:
                                # Assume it's in customer_photos folder
                                file_path = os.path.join(app.config['CUSTOMER_PHOTOS_FOLDER'], photo_path)
                            
                            if os.path.exists(file_path):
                                os.remove(file_path)
                                deleted_files.append(photo_path)
                                print(f"✅ Deleted customer photo: {file_path}")
                            else:
                                print(f"⚠️ Customer photo file not found: {file_path}")
                        except Exception as e:
                            failed_deletions.append(f"Customer photo ({photo_path}): {str(e)}")
                            print(f"❌ Error deleting customer photo {photo_path}: {e}")
            except Exception as e:
                failed_deletions.append(f"Photo parsing error: {str(e)}")
                print(f"❌ Error parsing customer photos: {e}")
        
        # Reverse the inventory changes
        if transaction_type == 'OUT':
            # If it was a sale (OUT), add the quantity back to inventory
            cursor.execute('UPDATE products SET quantity = quantity + ? WHERE barcode = ?', (quantity, barcode))
        elif transaction_type == 'IN':
            # If it was a restock (IN), subtract the quantity from inventory
            cursor.execute('UPDATE products SET quantity = quantity - ? WHERE barcode = ?', (quantity, barcode))
        
        # Delete the transaction from database
        cursor.execute('DELETE FROM transactions WHERE id = ?', (transaction_id,))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'Transaction not found'}), 404
        
        conn.commit()
        conn.close()
        
        # Prepare response with deletion summary
        response_data = {
            'Result': 'Transaction deleted successfully',
            'transaction_info': {
                'id': transaction_id,
                'barcode': barcode,
                'type': transaction_type,
                'quantity': quantity,
                'recipient_name': recipient_name
            },
            'deletion_summary': {
                'database_records_deleted': 1,
                'photo_files_deleted': len(deleted_files),
                'deleted_files': deleted_files,
                'inventory_adjusted': True
            }
        }
        
        if failed_deletions:
            response_data['warnings'] = {
                'failed_file_deletions': failed_deletions,
                'message': 'Transaction deleted but some photo files could not be removed'
            }
        
        print(f"🗑️ Transaction deletion completed:")
        print(f"   📋 Transaction ID: {transaction_id}")
        print(f"   👤 Customer: {recipient_name or 'Unknown'}")
        print(f"   📦 Product: {barcode} ({transaction_type} {quantity})")
        print(f"   📊 Database records deleted: 1")
        print(f"   📸 Photo files deleted: {len(deleted_files)}")
        if failed_deletions:
            print(f"   ⚠️ Failed deletions: {len(failed_deletions)}")
        
        return jsonify(response_data)
        
    except Exception as e:
        conn.close()
        print(f"❌ Error in delete_transaction: {e}")
        return jsonify({'error': str(e)}), 400

# Update product quantity endpoint (for inventory adjustment)
@app.route('/api/products/<barcode>/quantity', methods=['PUT'])
def update_product_quantity(barcode):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    data = request.get_json()
    new_quantity = data.get('quantity')
    
    if new_quantity is None:
        return jsonify({'error': 'Quantity is required'}), 400
    
    try:
        cursor.execute('''
            UPDATE products 
            SET quantity = ?
            WHERE barcode = ?
        ''', (new_quantity, barcode))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'Product not found'}), 404
        
        conn.commit()
        conn.close()
        return jsonify({'Result': 'Product quantity updated successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

# Update customer by phone number endpoint
@app.route('/api/customers/phone/<phone>', methods=['PUT'])
def update_customer_by_phone(phone):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    data = request.get_json()
    new_name = data.get('name')
    new_phone = data.get('phone')
    
    if new_name is None or new_phone is None:
        return jsonify({'error': 'Name and phone are required'}), 400
    
    try:
        # Update customer information
        cursor.execute('''
            UPDATE customers 
            SET name = ?, phone = ?
            WHERE phone = ?
        ''', (new_name, new_phone, phone))
        
        # Also update all transactions with this customer
        cursor.execute('''
            UPDATE transactions 
            SET recipient_name = ?, recipient_phone = ?
            WHERE recipient_phone = ?
        ''', (new_name, new_phone, phone))
        
        if cursor.rowcount == 0:
            # If no existing customer, this might be a new customer
            # The transaction updates will happen when the sale is saved
            pass
        
        conn.commit()
        conn.close()
        return jsonify({'Result': 'Customer information updated successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/cleanup-photos', methods=['POST'])
def cleanup_photos():
    """Remove orphaned photo files that are no longer referenced in the database"""
    try:
        conn = sqlite3.connect('inventory.db')
        cursor = conn.cursor()
        
        # Get all photo filenames currently in the database
        cursor.execute('SELECT DISTINCT recipient_photo FROM transactions WHERE recipient_photo IS NOT NULL AND recipient_photo != ""')
        db_photos = set()
        for row in cursor.fetchall():
            photo_path = row[0]
            if photo_path and not photo_path.startswith('data:image'):
                db_photos.add(photo_path)
        
        conn.close()
        
        deleted_count = 0
        deleted_files = []
        
        # Clean up customer photos in both old and new locations
        # Check old location (uploads root)
        upload_dir = app.config['UPLOAD_FOLDER']
        if os.path.exists(upload_dir):
            old_customer_files = set(f for f in os.listdir(upload_dir) if f.startswith('customer_') and f.endswith('.jpg'))
            orphaned_old_files = old_customer_files - db_photos
            
            for filename in orphaned_old_files:
                file_path = os.path.join(upload_dir, filename)
                try:
                    os.remove(file_path)
                    deleted_count += 1
                    deleted_files.append(filename)
                    print(f'Deleted orphaned customer photo from old location: {filename}')
                except Exception as e:
                    print(f'Failed to delete {filename}: {e}')
        
        # Check new location (customer_photos folder)
        customer_photos_dir = app.config['CUSTOMER_PHOTOS_FOLDER']
        if os.path.exists(customer_photos_dir):
            customer_files = set(f for f in os.listdir(customer_photos_dir) if f.startswith('customer_') and f.endswith('.jpg'))
            # Convert to relative paths for comparison
            customer_files_relative = set(f"customer_photos/{f}" for f in customer_files)
            orphaned_customer_files = customer_files_relative - db_photos
            
            for relative_path in orphaned_customer_files:
                filename = relative_path.split('/')[-1]  # Get just the filename
                file_path = os.path.join(customer_photos_dir, filename)
                try:
                    os.remove(file_path)
                    deleted_count += 1
                    deleted_files.append(relative_path)
                    print(f'Deleted orphaned customer photo: {relative_path}')
                except Exception as e:
                    print(f'Failed to delete {relative_path}: {e}')
        
        return jsonify({
            'Result': f'Cleanup completed. Deleted {deleted_count} orphaned photos.',
            'deleted_files': deleted_files
        })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/stats', methods=['GET'])
def get_stats():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Get total products
    cursor.execute('SELECT COUNT(*) FROM products')
    total_products = cursor.fetchone()[0]
    
    # Get total quantity
    cursor.execute('SELECT SUM(quantity) FROM products')
    total_quantity = cursor.fetchone()[0] or 0
    
    # Get total transactions
    cursor.execute('SELECT COUNT(*) FROM transactions')
    total_transactions = cursor.fetchone()[0]
    
    # Get low stock items (quantity <= 5)
    cursor.execute('SELECT COUNT(*) FROM products WHERE quantity <= 5')
    low_stock = cursor.fetchone()[0]
    
    # Get recent transactions
    cursor.execute('''
        SELECT t.*, p.name as product_name 
        FROM transactions t 
        LEFT JOIN products p ON t.barcode = p.barcode 
        ORDER BY transaction_date DESC 
        LIMIT 10
    ''')
    recent_transactions = cursor.fetchall()
    
    conn.close()
    
    transaction_list = []
    for trans in recent_transactions:
        transaction_list.append({
            'id': trans[0],
            'barcode': trans[1],
            'transaction_type': trans[2],
            'quantity': trans[3],
            'recipient_name': trans[4],
            'recipient_phone': trans[5],
            'recipient_photo': trans[6],
            'transaction_date': trans[7],
            'notes': trans[8],
            'product_name': trans[9]
        })
    
    return jsonify({
        'total_products': total_products,
        'total_quantity': total_quantity,
        'total_transactions': total_transactions,
        'low_stock': low_stock,
        'recent_transactions': transaction_list
    })

# Customer Management APIs
@app.route('/api/customers', methods=['GET'])
def get_customers():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM customers ORDER BY created_date DESC')
    customers = cursor.fetchall()
    conn.close()
    
    customer_list = []
    for customer in customers:
        customer_list.append({
            'id': customer[0],
            'name': customer[1],
            'phone': customer[2],
            'address': customer[3],
            'email': customer[4],
            'created_date': customer[5]
        })
    
    return jsonify({'Result': customer_list})

@app.route('/api/customers/search/<query>', methods=['GET'])
def search_customers(query):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT * FROM customers 
        WHERE name LIKE ? OR phone LIKE ?
        ORDER BY created_date DESC
    ''', (f'%{query}%', f'%{query}%'))
    customers = cursor.fetchall()
    conn.close()
    
    customer_list = []
    for customer in customers:
        customer_list.append({
            'id': customer[0],
            'name': customer[1],
            'phone': customer[2],
            'address': customer[3],
            'email': customer[4],
            'created_date': customer[5]
        })
    
    return jsonify({'Result': customer_list})

@app.route('/api/customers', methods=['POST'])
def add_customer():
    data = request.json
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO customers (name, phone, address, email)
            VALUES (?, ?, ?, ?)
        ''', (
            data['name'],
            data['phone'],
            data.get('address'),
            data.get('email')
        ))
        
        customer_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return jsonify({
            'Result': 'Customer added successfully',
            'customer_id': customer_id
        })
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'Customer with this phone number already exists'}), 400
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/customers/<customer_id>', methods=['PUT'])
def update_customer(customer_id):
    data = request.json
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE customers 
            SET name = ?, phone = ?, address = ?, email = ?
            WHERE id = ?
        ''', (
            data['name'],
            data['phone'],
            data.get('address'),
            data.get('email'),
            customer_id
        ))
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Customer updated successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/customers/<customer_id>', methods=['DELETE'])
def delete_customer(customer_id):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('DELETE FROM customers WHERE id = ?', (customer_id,))
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Customer deleted successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

# Product Location Management APIs
@app.route('/api/product-locations', methods=['GET'])
def get_product_locations():
    """Get all product location photos with pagination"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Get pagination parameters
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 10))
    offset = (page - 1) * per_page
    
    # Get total count
    cursor.execute('SELECT COUNT(*) FROM product_location_photos')
    total_count = cursor.fetchone()[0]
    
    # Get paginated results
    cursor.execute('''
        SELECT * FROM product_location_photos 
        ORDER BY updated_date DESC 
        LIMIT ? OFFSET ?
    ''', (per_page, offset))
    locations = cursor.fetchall()
    
    location_list = []
    for location in locations:
        location_id = location[0]
        
        # Get all images for this location
        cursor.execute('''
            SELECT image_path FROM product_location_images 
            WHERE location_id = ? 
            ORDER BY image_order
        ''', (location_id,))
        images = cursor.fetchall()
        image_paths = [img[0] for img in images] if images else []
        
        location_list.append({
            'id': location[0],
            'product_name': location[1],
            'location_name': location[2],
            'image_path': location[3],  # Main image (backward compatibility)
            'image_paths': image_paths,  # All images
            'notes': location[4],
            'created_date': location[5],
            'updated_date': location[6]
        })
    
    conn.close()
    
    return jsonify({
        'Result': location_list,
        'total_count': total_count,
        'page': page,
        'per_page': per_page,
        'total_pages': (total_count + per_page - 1) // per_page
    })

@app.route('/api/product-locations/search/<query>', methods=['GET'])
def search_product_locations(query):
    """Search product locations by product name or location name"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT * FROM product_location_photos 
        WHERE product_name LIKE ? OR location_name LIKE ?
        ORDER BY updated_date DESC
    ''', (f'%{query}%', f'%{query}%'))
    locations = cursor.fetchall()
    
    location_list = []
    for location in locations:
        location_id = location[0]
        
        # Get all images for this location
        cursor.execute('''
            SELECT image_path FROM product_location_images 
            WHERE location_id = ? 
            ORDER BY image_order
        ''', (location_id,))
        images = cursor.fetchall()
        image_paths = [img[0] for img in images] if images else []
        
        location_list.append({
            'id': location[0],
            'product_name': location[1],
            'location_name': location[2],
            'image_path': location[3],  # Main image (backward compatibility)
            'image_paths': image_paths,  # All images
            'notes': location[4],
            'created_date': location[5],
            'updated_date': location[6]
        })
    
    conn.close()
    return jsonify({'Result': location_list})

@app.route('/api/product-locations', methods=['POST'])
def add_product_location():
    """Add a new product location with multiple photos"""
    data = request.json
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # First, insert the location record with local timestamp
        current_time = get_local_timestamp()
        cursor.execute('''
            INSERT INTO product_location_photos (product_name, location_name, image_path, notes, created_date, updated_date)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            data['product_name'],
            data['location_name'],
            '',  # Will be updated with first image path
            data.get('notes', ''),
            current_time,
            current_time
        ))
        
        location_id = cursor.lastrowid
        
        # Handle multiple images
        image_paths = []
        first_image_path = None
        
        # Check for multiple images
        if 'image_data_list' in data and data['image_data_list']:
            for i, image_data in enumerate(data['image_data_list']):
                if image_data:
                    # Process and save compressed image to find-photos folder
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    product_safe = data['product_name'].replace(' ', '_').replace('/', '_')
                    filename = f"location_{product_safe}_{location_id}_{i+1}_{timestamp}.jpg"
                    success, full_path, error_msg = process_and_save_image(
                        image_data, 
                        filename, 
                        app.config['FIND_PHOTOS_FOLDER'],
                        compress=True
                    )
                    
                    if not success:
                        # Cleanup and return error
                        cursor.execute('DELETE FROM product_location_photos WHERE id = ?', (location_id,))
                        conn.commit()
                        conn.close()
                        return jsonify({'error': f'Failed to process image {i+1}: {error_msg}'}), 400
                    
                    # Save relative path in database (find-photos/filename)
                    relative_path = f"find-photos/{filename}"
                    image_paths.append(relative_path)
                    
                    if i == 0:  # First image becomes the main image
                        first_image_path = relative_path
                    
                    # Insert into product_location_images table
                    cursor.execute('''
                        INSERT INTO product_location_images (location_id, image_path, image_order)
                        VALUES (?, ?, ?)
                    ''', (location_id, relative_path, i + 1))
        
        # Handle single image (backward compatibility)
        elif 'image_data' in data and data['image_data']:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            product_safe = data['product_name'].replace(' ', '_').replace('/', '_')
            filename = f"location_{product_safe}_{location_id}_1_{timestamp}.jpg"
            success, full_path, error_msg = process_and_save_image(
                data['image_data'], 
                filename, 
                app.config['FIND_PHOTOS_FOLDER'],
                compress=True
            )
            
            if not success:
                cursor.execute('DELETE FROM product_location_photos WHERE id = ?', (location_id,))
                conn.commit()
                conn.close()
                return jsonify({'error': f'Failed to process image: {error_msg}'}), 400
            
            relative_path = f"find-photos/{filename}"
            first_image_path = relative_path
            
            # Insert into product_location_images table
            cursor.execute('''
                INSERT INTO product_location_images (location_id, image_path, image_order)
                VALUES (?, ?, ?)
            ''', (location_id, relative_path, 1))
        
        # Update the main location record with the first image path
        if first_image_path:
            cursor.execute('''
                UPDATE product_location_photos 
                SET image_path = ? 
                WHERE id = ?
            ''', (first_image_path, location_id))
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'Result': 'Product location added successfully',
            'location_id': location_id,
            'images_saved': len(image_paths) if image_paths else (1 if first_image_path else 0)
        })
        
    except Exception as e:
        # Cleanup on error
        try:
            cursor.execute('DELETE FROM product_location_photos WHERE id = ?', (location_id,))
            conn.commit()
        except:
            pass
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/product-locations/<int:location_id>', methods=['GET'])
def get_product_location(location_id):
    """Get a specific product location by ID"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            SELECT id, product_name, location_name, image_path, notes, created_date, updated_date
            FROM product_location_photos 
            WHERE id = ?
        ''', (location_id,))
        
        location = cursor.fetchone()
        
        if not location:
            conn.close()
            return jsonify({'error': 'Location not found'}), 404
        
        # Get all images for this location (like in the list endpoint)
        cursor.execute('''
            SELECT image_path FROM product_location_images 
            WHERE location_id = ? 
            ORDER BY image_order
        ''', (location_id,))
        images = cursor.fetchall()
        image_paths = [img[0] for img in images] if images else []
        
        conn.close()
        
        location_dict = {
            'id': location[0],
            'product_name': location[1],
            'location_name': location[2],
            'image_path': location[3],  # Main image (backward compatibility)
            'image_paths': image_paths,  # All images
            'notes': location[4],
            'created_date': location[5],
            'updated_date': location[6]
        }
        
        return jsonify({'Result': location_dict}), 200
        
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 500

@app.route('/api/product-locations/<int:location_id>', methods=['PUT'])
def update_product_location(location_id):
    """Update a product location with support for photo deletion"""
    data = request.json
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Check if location exists
        cursor.execute('SELECT image_path FROM product_location_photos WHERE id = ?', (location_id,))
        current_location = cursor.fetchone()
        if not current_location:
            conn.close()
            return jsonify({'error': 'Product location not found'}), 404
        
        # Handle images to delete
        images_to_delete = data.get('images_to_delete', [])
        if images_to_delete:
            for image_path in images_to_delete:
                # Delete from file system
                try:
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path)
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        print(f"Deleted image file: {image_path}")
                except Exception as e:
                    print(f"Error deleting image file {image_path}: {e}")
                
                # Delete from database
                cursor.execute('DELETE FROM product_location_images WHERE location_id = ? AND image_path = ?', 
                             (location_id, image_path))
        
        # Handle new images if provided
        image_paths = []
        first_image_path = None
        
        if 'image_data_list' in data and data['image_data_list']:
            for i, image_data in enumerate(data['image_data_list']):
                if image_data and image_data.startswith('data:image'):
                    try:
                        # Process and save compressed image to find-photos folder
                        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                        product_safe = data['product_name'].replace(' ', '_').replace('/', '_')
                        filename = f"location_{product_safe}_{timestamp}_{i}.jpg"
                        success, full_path, error_msg = process_and_save_image(
                            image_data, 
                            filename, 
                            app.config['FIND_PHOTOS_FOLDER'],
                            compress=True
                        )
                        
                        if not success:
                            conn.close()
                            return jsonify({'error': f'Failed to process image: {error_msg}'}), 400
                        
                        # Save relative path
                        relative_path = f"find-photos/{filename}"
                        image_paths.append(relative_path)
                        
                        if first_image_path is None:
                            first_image_path = relative_path
                        
                        # Insert into images table
                        cursor.execute('''
                            INSERT INTO product_location_images (location_id, image_path, image_order)
                            VALUES (?, ?, ?)
                        ''', (location_id, relative_path, i))
                        
                        print(f"New compressed location image saved: {filename}")
                    except Exception as img_error:
                        conn.close()
                        print(f"Error processing location image: {img_error}")
                        return jsonify({'error': f'Error processing image: {str(img_error)}'}), 400
        
        # Update main location record
        # Use first new image if available, otherwise keep existing
        main_image_path = first_image_path or current_location[0]
        
        cursor.execute('''
            UPDATE product_location_photos 
            SET product_name = ?, location_name = ?, image_path = ?, notes = ?, updated_date = ?
            WHERE id = ?
        ''', (
            data['product_name'],
            data['location_name'],
            main_image_path,
            data.get('notes', ''),
            get_local_timestamp(),
            location_id
        ))
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Product location updated successfully'})
        
    except Exception as e:
        print(f"Error updating product location: {e}")
        if 'conn' in locals():
            conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/product-locations/<int:location_id>', methods=['DELETE'])
def delete_product_location(location_id):
    """Delete a product location and all associated photos"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Check if location exists
        cursor.execute('SELECT id, product_name, location_name FROM product_location_photos WHERE id = ?', (location_id,))
        location_info = cursor.fetchone()
        
        if not location_info:
            conn.close()
            return jsonify({'error': 'Product location not found'}), 404
        
        deleted_files = []
        failed_deletions = []
        
        # 1. Get and delete the main image from product_location_photos
        cursor.execute('SELECT image_path FROM product_location_photos WHERE id = ?', (location_id,))
        main_result = cursor.fetchone()
        
        if main_result and main_result[0]:
            main_image_path = main_result[0]
            try:
                # Handle both absolute and relative paths
                if main_image_path.startswith('find-photos/') or main_image_path.startswith('uploads/'):
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], main_image_path.replace('uploads/', ''))
                else:
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], main_image_path)
                
                if os.path.exists(file_path):
                    os.remove(file_path)
                    deleted_files.append(main_image_path)
                    print(f"✅ Deleted main location image: {file_path}")
                else:
                    print(f"⚠️ Main image file not found: {file_path}")
            except Exception as e:
                failed_deletions.append(f"Main image ({main_image_path}): {str(e)}")
                print(f"❌ Error deleting main image {main_image_path}: {e}")
        
        # 2. Get and delete all additional images from product_location_images
        cursor.execute('SELECT image_path FROM product_location_images WHERE location_id = ?', (location_id,))
        additional_images = cursor.fetchall()
        
        for (image_path,) in additional_images:
            if image_path:
                try:
                    # Handle both absolute and relative paths
                    if image_path.startswith('find-photos/') or image_path.startswith('uploads/'):
                        file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path.replace('uploads/', ''))
                    else:
                        file_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path)
                    
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        deleted_files.append(image_path)
                        print(f"✅ Deleted additional location image: {file_path}")
                    else:
                        print(f"⚠️ Additional image file not found: {file_path}")
                except Exception as e:
                    failed_deletions.append(f"Additional image ({image_path}): {str(e)}")
                    print(f"❌ Error deleting additional image {image_path}: {e}")
        
        # 3. Delete database records
        # Delete from product_location_images first (foreign key constraint)
        cursor.execute('DELETE FROM product_location_images WHERE location_id = ?', (location_id,))
        additional_deleted = cursor.rowcount
        
        # Delete from main product_location_photos table
        cursor.execute('DELETE FROM product_location_photos WHERE id = ?', (location_id,))
        main_deleted = cursor.rowcount
        
        if main_deleted == 0:
            conn.close()
            return jsonify({'error': 'Product location not found'}), 404
        
        conn.commit()
        conn.close()
        
        # Prepare response with deletion summary
        response_data = {
            'Result': 'Product location deleted successfully',
            'location_info': {
                'id': location_info[0],
                'product_name': location_info[1],
                'location_name': location_info[2]
            },
            'deletion_summary': {
                'database_records_deleted': main_deleted + additional_deleted,
                'photo_files_deleted': len(deleted_files),
                'deleted_files': deleted_files
            }
        }
        
        if failed_deletions:
            response_data['warnings'] = {
                'failed_file_deletions': failed_deletions,
                'message': 'Location deleted but some photo files could not be removed'
            }
        
        print(f"🗑️ Location deletion completed:")
        print(f"   📍 Location: {location_info[1]} - {location_info[2]}")
        print(f"   📊 Database records deleted: {main_deleted + additional_deleted}")
        print(f"   📸 Photo files deleted: {len(deleted_files)}")
        if failed_deletions:
            print(f"   ⚠️ Failed deletions: {len(failed_deletions)}")
        
        return jsonify(response_data)
        
    except Exception as e:
        conn.close()
        print(f"❌ Error in delete_product_location: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/api/product-locations/suggestions/<query>', methods=['GET'])
def get_product_suggestions(query):
    """Get product name suggestions for search"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT DISTINCT product_name FROM product_location_photos 
        WHERE product_name LIKE ?
        ORDER BY product_name
        LIMIT 10
    ''', (f'%{query}%',))
    suggestions = cursor.fetchall()
    conn.close()
    
    suggestion_list = [suggestion[0] for suggestion in suggestions]
    return jsonify({'Result': suggestion_list})

# Sales Analytics APIs
@app.route('/api/sales/summary', methods=['GET'])
def get_sales_summary():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    # Get sales summary for today
    cursor.execute('''
        SELECT 
            COUNT(*) as total_sales,
            SUM(quantity) as total_quantity_sold,
            COUNT(DISTINCT recipient_phone) as unique_customers
        FROM transactions 
        WHERE transaction_type = 'OUT' 
        AND date(transaction_date) = date('now')
    ''')
    today_stats = cursor.fetchone()
    
    # Get top selling products
    cursor.execute('''
        SELECT 
            t.barcode,
            p.name,
            SUM(t.quantity) as total_sold
        FROM transactions t
        LEFT JOIN products p ON t.barcode = p.barcode
        WHERE t.transaction_type = 'OUT'
        GROUP BY t.barcode
        ORDER BY total_sold DESC
        LIMIT 5
    ''')
    top_products = cursor.fetchall()
    
    # Get recent sales
    cursor.execute('''
        SELECT 
            t.*,
            p.name as product_name,
            p.mrp
        FROM transactions t
        LEFT JOIN products p ON t.barcode = p.barcode
        WHERE t.transaction_type = 'OUT'
        ORDER BY t.transaction_date DESC
        LIMIT 10
    ''')
    recent_sales = cursor.fetchall()
    
    conn.close()
    
    # Format the response
    top_products_list = []
    for product in top_products:
        top_products_list.append({
            'barcode': product[0],
            'name': product[1] or 'Unknown Product',
            'total_sold': product[2]
        })
    
    recent_sales_list = []
    for sale in recent_sales:
        recent_sales_list.append({
            'id': sale[0],
            'barcode': sale[1],
            'transaction_type': sale[2],
            'quantity': sale[3],
            'recipient_name': sale[4],
            'recipient_phone': sale[5],
            'recipient_photo': sale[6],
            'transaction_date': sale[7],
            'notes': sale[8],
            'product_name': sale[9],
            'mrp': sale[10]
        })
    
    return jsonify({
        'today_stats': {
            'total_sales': today_stats[0] or 0,
            'total_quantity_sold': today_stats[1] or 0,
            'unique_customers': today_stats[2] or 0
        },
        'top_products': top_products_list,
        'recent_sales': recent_sales_list
    })

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    """Serve uploaded files from uploads directory and subdirectories"""
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/uploads/product_photos/<filename>')
def product_photo(filename):
    """Serve product photos"""
    return send_from_directory(app.config['PRODUCT_PHOTOS_FOLDER'], filename)

@app.route('/uploads/customer_photos/<filename>')
def customer_photo(filename):
    """Serve customer photos"""
    return send_from_directory(app.config['CUSTOMER_PHOTOS_FOLDER'], filename)

@app.route('/uploads/find-photos/<filename>')
def find_photo(filename):
    """Serve product location photos"""
    return send_from_directory(app.config['FIND_PHOTOS_FOLDER'], filename)

def compress_image(image_bytes, max_size_kb=300, quality=75, max_width=800, max_height=800):
    """
    Compress image to reduce file size while maintaining quality
    
    Args:
        image_bytes: Raw image bytes
        max_size_kb: Maximum file size in KB (default: 500KB)
        quality: JPEG quality (1-100, default: 85 for good quality)
        max_width: Maximum width in pixels (default: 1200px)
        max_height: Maximum height in pixels (default: 1200px)
    
    Returns:
        Compressed image bytes
    """
    # If Pillow is not available, return original bytes
    if not COMPRESSION_AVAILABLE:
        print("Compression skipped - Pillow not available")
        return image_bytes
        
    try:
        # Open image from bytes
        img = Image.open(io.BytesIO(image_bytes))
        
        # Handle EXIF orientation to fix rotation issues from mobile cameras
        try:
            # Use Pillow's built-in EXIF transpose function (most reliable method)
            from PIL import ImageOps
            original_size = img.size
            img = ImageOps.exif_transpose(img)
            new_size = img.size
            
            if original_size != new_size:
                print(f"EXIF orientation corrected: {original_size} → {new_size}")
            else:
                print("No EXIF orientation correction needed")
                
        except ImportError:
            print("ImageOps not available, trying manual EXIF handling")
            # Fallback to manual method if ImageOps is not available
            try:
                exif_dict = img.getexif() if hasattr(img, 'getexif') else None
                if exif_dict:
                    orientation = exif_dict.get(274)  # 274 is the EXIF orientation tag
                    if orientation:
                        print(f"EXIF orientation found: {orientation}")
                        if orientation == 3:
                            img = img.rotate(180, expand=True)
                            print("Applied 180° rotation")
                        elif orientation == 6:
                            img = img.rotate(270, expand=True)
                            print("Applied 270° rotation (correcting 90° CW)")
                        elif orientation == 8:
                            img = img.rotate(90, expand=True)
                            print("Applied 90° rotation (correcting 90° CCW)")
                else:
                    print("No EXIF data available")
            except Exception as fallback_e:
                print(f"Fallback EXIF processing failed: {fallback_e}")
        except Exception as e:
            print(f"Error processing EXIF orientation: {e} - continuing without EXIF correction")
            # Continue without EXIF processing if it fails
        
        # Convert to RGB if necessary (handles PNG with transparency, etc.)
        if img.mode in ('RGBA', 'LA', 'P'):
            # Create white background
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Get original dimensions
        original_width, original_height = img.size
        original_size_kb = len(image_bytes) / 1024
        
        print(f"Original image: {original_width}x{original_height}, {original_size_kb:.1f}KB")
        
        # Resize if image is too large
        if original_width > max_width or original_height > max_height:
            # Calculate new dimensions maintaining aspect ratio
            ratio = min(max_width / original_width, max_height / original_height)
            new_width = int(original_width * ratio)
            new_height = int(original_height * ratio)
            
            # Resize with high-quality resampling
            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            print(f"Resized to: {new_width}x{new_height}")
        
        # Compress with different quality levels until we reach target size
        compressed_bytes = None
        current_quality = quality
        
        for attempt in range(5):  # Try up to 5 different quality levels
            output_buffer = io.BytesIO()
            
            # Save with current quality
            img.save(output_buffer, format='JPEG', quality=current_quality, optimize=True)
            compressed_bytes = output_buffer.getvalue()
            compressed_size_kb = len(compressed_bytes) / 1024
            
            print(f"Attempt {attempt + 1}: Quality {current_quality}, Size: {compressed_size_kb:.1f}KB")
            
            # If size is acceptable, break
            if compressed_size_kb <= max_size_kb or current_quality <= 60:
                break
            
            # Reduce quality for next attempt
            current_quality = max(60, current_quality - 10)
        
        final_size_kb = len(compressed_bytes) / 1024
        compression_ratio = (original_size_kb / final_size_kb) if final_size_kb > 0 else 1
        
        print(f"Final compressed image: {final_size_kb:.1f}KB (compression ratio: {compression_ratio:.1f}x)")
        
        return compressed_bytes
        
    except Exception as e:
        print(f"Error compressing image: {e}")
        # Return original bytes if compression fails
        return image_bytes

def process_and_save_image(base64_data, filename, folder_path, compress=True):
    """
    Process base64 image data, compress it intelligently, and save to specified folder
    
    Args:
        base64_data: Base64 encoded image data (with or without data URL prefix)
        filename: Name for the saved file
        folder_path: Full path to the folder where image should be saved
        compress: Whether to compress the image (default: True)
    
    Returns:
        Tuple: (success: bool, file_path: str, error_message: str)
    """
    try:
        print(f"🔧 DEBUG: Starting image processing for {filename}")
        print(f"🔧 DEBUG: Input data length: {len(base64_data) if base64_data else 0} characters")
        
        if not base64_data or len(base64_data) < 100:
            error_msg = f"Invalid or too short base64 data: {len(base64_data) if base64_data else 0} characters"
            print(f"❌ {error_msg}")
            return False, "", error_msg
        
        # Remove data URL prefix if present
        original_data = base64_data
        if ',' in base64_data:
            prefix, base64_data = base64_data.split(',', 1)
            print(f"🔧 DEBUG: Removed data URL prefix: {prefix}")
        
        print(f"🔧 DEBUG: Base64 data length after cleanup: {len(base64_data)} characters")
        
        # Fix base64 padding - SIMPLE APPROACH
        base64_data = base64_data.strip()  # Remove any whitespace
        # Add padding to make it a multiple of 4
        while len(base64_data) % 4 != 0:
            base64_data += '='
        
        print(f"🔧 DEBUG: Fixed base64 length: {len(base64_data)} characters")
        
        # Decode full base64
        try:
            image_bytes = base64.b64decode(base64_data)
            original_size_kb = len(image_bytes) / 1024
            print(f"🔧 DEBUG: Decoded image: {len(image_bytes)} bytes ({original_size_kb:.1f}KB)")
        except Exception as decode_error:
            error_msg = f"Base64 decode failed: {str(decode_error)}"
            print(f"❌ {error_msg}")
            return False, "", error_msg
        
        if len(image_bytes) < 1000:  # Less than 1KB is suspicious
            error_msg = f"Decoded image too small: {len(image_bytes)} bytes"
            print(f"❌ {error_msg}")
            return False, "", error_msg
        
        # Apply aggressive compression to save space
        if compress and COMPRESSION_AVAILABLE:
            print(f"🔧 DEBUG: Applying aggressive compression...")
            try:
                # Test if it's a valid image first
                test_img = Image.open(io.BytesIO(image_bytes))
                test_img.verify()  # This will raise an exception if not a valid image
                print(f"🔧 DEBUG: Image format validation passed: {test_img.format}")
                
                # Re-open for processing (verify() closes the image)
                image_bytes = base64.b64decode(base64_data)
                
                # Apply minimal compression to keep text very clear
                print(f"Compressing image ({original_size_kb:.1f}KB) with minimal compression for text clarity...")
                image_bytes = compress_image(
                    image_bytes, 
                    max_size_kb=150,     # Larger target size for excellent quality
                    quality=80,          # Much higher quality for clear text
                    max_width=1000,      # Larger dimensions for excellent text clarity
                    max_height=1000
                )
                
                compressed_size_kb = len(image_bytes) / 1024
                print(f"✅ Compressed: {original_size_kb:.1f}KB → {compressed_size_kb:.1f}KB (saved {original_size_kb - compressed_size_kb:.1f}KB)")
            except Exception as img_error:
                print(f"⚠️ WARNING: Image compression failed: {str(img_error)}")
                print(f"🔧 DEBUG: Saving original image")
                # Use original image_bytes if compression fails
                image_bytes = base64.b64decode(base64_data)
        elif compress and not COMPRESSION_AVAILABLE:
            print(f"Compression requested but Pillow not available. Saving original image: {original_size_kb:.1f}KB")
        else:
            print(f"Compression disabled. Saving original image: {original_size_kb:.1f}KB")
        
        # Final validation before saving
        if len(image_bytes) < 100:
            error_msg = f"Final image data too small: {len(image_bytes)} bytes"
            print(f"❌ {error_msg}")
            return False, "", error_msg
        
        # Save to file
        full_path = os.path.join(folder_path, filename)
        print(f"🔧 DEBUG: Saving to: {full_path}")
        
        with open(full_path, 'wb') as f:
            f.write(image_bytes)
        
        # Verify file was saved correctly
        if os.path.exists(full_path):
            file_size = os.path.getsize(full_path)
            print(f"🔧 DEBUG: File saved successfully: {file_size} bytes")
            if file_size != len(image_bytes):
                print(f"⚠️ WARNING: File size mismatch! Expected: {len(image_bytes)}, Got: {file_size}")
        else:
            error_msg = "File was not created"
            print(f"❌ {error_msg}")
            return False, "", error_msg
        
        return True, full_path, ""
        
    except Exception as e:
        error_msg = f"Error processing image: {str(e)}"
        print(f"❌ {error_msg}")
        import traceback
        print(f"🔧 DEBUG: Full traceback: {traceback.format_exc()}")
        return False, "", error_msg

def is_photo_used_by_other_transactions(photo_path, excluding_transaction_id=None):
    """Check if a photo is still being used by other transactions"""
    if not photo_path or photo_path.startswith('data:image'):
        return False
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        if excluding_transaction_id:
            cursor.execute('''
                SELECT COUNT(*) FROM transactions 
                WHERE recipient_photo = ? AND id != ?
            ''', (photo_path, excluding_transaction_id))
        else:
            cursor.execute('''
                SELECT COUNT(*) FROM transactions 
                WHERE recipient_photo = ?
            ''', (photo_path,))
        
        count = cursor.fetchone()[0]
        return count > 0
    finally:
        conn.close()

def safe_delete_photo(photo_path, excluding_transaction_id=None):
    """Safely delete a photo file only if it's not used by other transactions"""
    if not photo_path or photo_path.startswith('data:image'):
        return False
    
    # Check if photo is still being used
    if is_photo_used_by_other_transactions(photo_path, excluding_transaction_id):
        print(f'Photo {photo_path} is still being used by other transactions, skipping deletion')
        return False
    
    # Determine file path
    if photo_path.startswith('customer_photos/') or photo_path.startswith('product_photos/'):
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo_path)
    else:
        # Old format: assume it's in uploads root
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo_path)
    
    # Delete file if it exists
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
            print(f'Successfully deleted photo: {photo_path}')
            return True
        except Exception as e:
            print(f'Failed to delete photo {photo_path}: {e}')
            return False
    
    return False

def force_delete_customer_old_photos(customer_name, customer_phone, new_photo_path):
    """
    Aggressively delete old customer photos when updating to a new one
    This is specifically for customer photo updates where we want to replace all old photos
    """
    if not customer_name or not customer_phone:
        return
    
    try:
        conn = sqlite3.connect('inventory.db')
        cursor = conn.cursor()
        
        # Get all old photos for this customer that are different from the new one
        cursor.execute('''
            SELECT DISTINCT recipient_photo FROM transactions 
            WHERE recipient_name = ? AND recipient_phone = ? 
            AND recipient_photo IS NOT NULL 
            AND recipient_photo != ? 
            AND recipient_photo != ''
        ''', (customer_name, customer_phone, new_photo_path))
        
        old_photos = cursor.fetchall()
        conn.close()
        
        # Delete each old photo file
        for (old_photo,) in old_photos:
            if old_photo and not old_photo.startswith('data:image'):
                # Determine file path
                if old_photo.startswith('customer_photos/') or old_photo.startswith('product_photos/'):
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], old_photo)
                else:
                    # Old format: assume it's in uploads root
                    file_path = os.path.join(app.config['UPLOAD_FOLDER'], old_photo)
                
                # Delete file if it exists
                if os.path.exists(file_path):
                    try:
                        os.remove(file_path)
                        print(f'Force deleted old customer photo: {old_photo}')
                    except Exception as e:
                        print(f'Failed to force delete photo {old_photo}: {e}')
        
    except Exception as e:
        print(f'Error in force_delete_customer_old_photos: {e}')

@app.route('/api/photos/delete', methods=['DELETE'])
def delete_photo():
    """Delete a photo file from the server and update database references"""
    try:
        data = request.json
        photo_path = data.get('photo_path')
        customer_name = data.get('customer_name')
        customer_phone = data.get('customer_phone')
        
        if not photo_path:
            return jsonify({'error': 'Photo path is required'}), 400
        
        # Don't delete base64 images
        if photo_path.startswith('data:image'):
            return jsonify({'message': 'Base64 images don\'t need server deletion'}), 200
        
        print(f'🗑️ Deleting photo: {photo_path} for customer: {customer_name} ({customer_phone})')
        
        # Update database to remove this photo from all transactions
        if customer_name and customer_phone:
            conn = sqlite3.connect('inventory.db')
            cursor = conn.cursor()
            
            try:
                # Get all transactions for this customer that have photos
                cursor.execute('''
                    SELECT id, recipient_photo FROM transactions 
                    WHERE recipient_name = ? AND recipient_phone = ? 
                    AND recipient_photo IS NOT NULL AND recipient_photo != ''
                ''', (customer_name, customer_phone))
                
                transactions = cursor.fetchall()
                updated_count = 0
                
                for trans_id, current_photo_data in transactions:
                    if not current_photo_data:
                        continue
                    
                    try:
                        # Handle JSON array of photos
                        if current_photo_data.startswith('['):
                            photos = json.loads(current_photo_data)
                            if isinstance(photos, list) and photo_path in photos:
                                # Remove the deleted photo from the array
                                photos.remove(photo_path)
                                
                                # Update the database with the new photo array
                                if photos:
                                    # Still have photos left
                                    new_photo_data = json.dumps(photos) if len(photos) > 1 else photos[0]
                                else:
                                    # No photos left
                                    new_photo_data = None
                                
                                cursor.execute('''
                                    UPDATE transactions 
                                    SET recipient_photo = ?
                                    WHERE id = ?
                                ''', (new_photo_data, trans_id))
                                
                                updated_count += 1
                                print(f'✅ Updated transaction {trans_id} - removed photo from array')
                        
                        # Handle single photo
                        elif current_photo_data == photo_path:
                            cursor.execute('''
                                UPDATE transactions 
                                SET recipient_photo = NULL
                                WHERE id = ?
                            ''', (trans_id,))
                            
                            updated_count += 1
                            print(f'✅ Updated transaction {trans_id} - removed single photo')
                    
                    except json.JSONDecodeError:
                        # Handle single photo (not JSON)
                        if current_photo_data == photo_path:
                            cursor.execute('''
                                UPDATE transactions 
                                SET recipient_photo = NULL
                                WHERE id = ?
                            ''', (trans_id,))
                            
                            updated_count += 1
                            print(f'✅ Updated transaction {trans_id} - removed single photo (non-JSON)')
                
                conn.commit()
                conn.close()
                
                print(f'🔄 Updated {updated_count} transactions in database')
                
            except Exception as db_error:
                conn.close()
                print(f'❌ Database update error: {db_error}')
                # Continue with file deletion even if database update fails
        
        # Now delete the actual file
        success = safe_delete_photo(photo_path)
        
        if success:
            return jsonify({
                'message': 'Photo deleted successfully', 
                'database_updated': updated_count if 'updated_count' in locals() else 0
            })
        else:
            return jsonify({'message': 'Photo not found or still in use by other transactions'})
    
    except Exception as e:
        print(f'Error in delete_photo endpoint: {e}')
        return jsonify({'error': str(e)}), 500

def get_local_ip():
    """Get the local IP address of the machine"""
    import socket
    try:
        # Connect to a remote server to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
        return local_ip
    except Exception:
        # Fallback method
        try:
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            if local_ip.startswith("127."):
                # If we get localhost, try a different approach
                import subprocess
                import platform
                if platform.system() == "Windows":
                    result = subprocess.run(['ipconfig'], capture_output=True, text=True)
                    lines = result.stdout.split('\n')
                    for line in lines:
                        if 'IPv4 Address' in line and '192.168' in line:
                            local_ip = line.split(':')[-1].strip()
                            break
                else:
                    result = subprocess.run(['ifconfig'], capture_output=True, text=True)
                    # Parse ifconfig output for IP
                    lines = result.stdout.split('\n')
                    for line in lines:
                        if 'inet ' in line and '192.168' in line:
                            local_ip = line.split()[1]
                            break
            return local_ip
        except Exception:
            return "localhost"

@app.route('/api/server-info', methods=['GET'])
def get_server_info():
    """Get server information including current IP"""
    local_ip = get_local_ip()
    return jsonify({
        'ip': local_ip,
        'port': 8080,
        'url': f'http://{local_ip}:8080'
    })

@app.route('/api/debug/transaction/<int:transaction_id>', methods=['GET'])
def debug_transaction(transaction_id):
    """Debug endpoint to check if a transaction exists"""
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute('SELECT * FROM transactions WHERE id = ?', (transaction_id,))
        transaction = cursor.fetchone()
        
        if transaction:
            return jsonify({
                'exists': True,
                'transaction': {
                    'id': transaction[0],
                    'barcode': transaction[1],
                    'transaction_type': transaction[2],
                    'quantity': transaction[3],
                    'recipient_name': transaction[4],
                    'recipient_phone': transaction[5],
                    'recipient_photo': transaction[6],
                    'transaction_date': transaction[7],
                    'notes': transaction[8]
                }
            })
        else:
            return jsonify({
                'exists': False,
                'message': f'Transaction {transaction_id} not found'
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

if __name__ == '__main__':
    local_ip = get_local_ip()
    
    print("=" * 60)
    print("🚀 INVENTORY MANAGEMENT SERVER STARTING...")
    print("=" * 60)
    print(f"📱 Mobile App URL: http://{local_ip}:8080")
    print(f"🌐 Local Access:   http://localhost:8080")
    print(f"💻 Web Dashboard: http://{local_ip}:8080")
    print("=" * 60)
    print("📋 Copy this URL to your mobile app settings:")
    print(f"   {local_ip}:8080")
    print("=" * 60)
    print("✨ Server will auto-update IP when network changes")
    print("🔄 Refresh your app to get the latest server URL")
    print("\n⚡ Press Ctrl+C to stop the server")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=8080, debug=True) 
from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import sqlite3
import os
import json
from datetime import datetime
import base64
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

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
    
    conn.commit()
    conn.close()

# Initialize database
init_db()

@app.route('/')
def index():
    return render_template('index.html')

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
        # Save base64 image
        image_data = data['image_path'].split(',')[1]  # Remove data:image/jpeg;base64, prefix
        image_bytes = base64.b64decode(image_data)
        filename = f"{data['barcode']}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        image_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        with open(image_path, 'wb') as f:
            f.write(image_bytes)
        
        # Save only the filename in database, not the full path
        image_path = filename
    
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
    data = request.json
    
    # Handle image upload if provided
    image_path = None
    if 'image_path' in data and data['image_path']:
        # Save base64 image
        image_data = data['image_path'].split(',')[1]  # Remove data:image/jpeg;base64, prefix
        image_bytes = base64.b64decode(image_data)
        filename = f"{barcode}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        image_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        with open(image_path, 'wb') as f:
            f.write(image_bytes)
        
        # Save only the filename in database, not the full path
        image_path = filename
    
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        if image_path:
            cursor.execute('''
                UPDATE products 
                SET name = ?, image_path = ?, mrp = ?, quantity = ?
                WHERE barcode = ?
            ''', (data['name'], image_path, data.get('mrp'), data.get('quantity', 0), barcode))
        else:
            cursor.execute('''
                UPDATE products 
                SET name = ?, mrp = ?, quantity = ?
                WHERE barcode = ?
            ''', (data['name'], data.get('mrp'), data.get('quantity', 0), barcode))
        
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Product updated successfully'})
    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 400

@app.route('/api/products/<barcode>', methods=['DELETE'])
def delete_product(barcode):
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
    
    try:
        # Get the image path to delete the file
        cursor.execute('SELECT image_path FROM products WHERE barcode = ?', (barcode,))
        result = cursor.fetchone()
        
        if result and result[0]:
            # Delete the image file
            image_path = os.path.join(app.config['UPLOAD_FOLDER'], result[0])
            if os.path.exists(image_path):
                os.remove(image_path)
        
        # Delete the product
        cursor.execute('DELETE FROM products WHERE barcode = ?', (barcode,))
        conn.commit()
        conn.close()
        
        return jsonify({'Result': 'Product deleted successfully'})
    except Exception as e:
        conn.close()
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
        # Add transaction record
        cursor.execute('''
            INSERT INTO transactions (barcode, transaction_type, quantity, recipient_name, recipient_phone, recipient_photo, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['barcode'],
            data['transaction_type'],
            data['quantity'],
            data.get('recipient_name'),
            data.get('recipient_phone'),
            data.get('recipient_photo'),
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
        return jsonify({'error': str(e)}), 400

@app.route('/api/transactions', methods=['GET'])
def get_transactions():
    conn = sqlite3.connect('inventory.db')
    cursor = conn.cursor()
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

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    print("Starting Inventory Management Server...")
    print("Server will be available at: http://localhost:8080")
    print("To access from mobile, use your computer's IP address")
    print("Example: http://192.168.1.100:8080")
    print("\nPress Ctrl+C to stop the server")
    app.run(host='0.0.0.0', port=8080, debug=True) 
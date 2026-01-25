-- TREE LAW ZOO Valley Database Schema
-- External SSD PostgreSQL Setup

-- 1. ตารางโต๊ะ (Tables)
CREATE TABLE tables (
  id SERIAL PRIMARY KEY,
  table_number INTEGER UNIQUE NOT NULL,
  status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'reserved', 'cleaning')),
  capacity INTEGER NOT NULL,
  location VARCHAR(50),
  description TEXT,
  last_updated TIMESTAMP DEFAULT NOW(),
  updated_by VARCHAR(50),
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 2. ตารางการจอง (Bookings)
CREATE TABLE bookings (
  id SERIAL PRIMARY KEY,
  table_id INTEGER REFERENCES tables(id) ON DELETE SET NULL,
  customer_name VARCHAR(100) NOT NULL,
  customer_phone VARCHAR(20),
  customer_email VARCHAR(100),
  booking_date DATE NOT NULL,
  booking_time TIME NOT NULL,
  number_of_people INTEGER NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed', 'no_show')),
  special_requests TEXT,
  notes TEXT,
  payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded', 'partial')),
  total_amount DECIMAL(10,2),
  deposit_amount DECIMAL(10,2) DEFAULT 0,
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by VARCHAR(50)
);

-- 3. ตารางหมวดหมู่อาหาร (Categories)
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name_th VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  description TEXT,
  icon_url VARCHAR(255),
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 4. ตารางเมนูอาหาร (Menu Items)
CREATE TABLE menu_items (
  id SERIAL PRIMARY KEY,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  name_th VARCHAR(100) NOT NULL,
  name_en VARCHAR(100),
  description_th TEXT,
  description_en TEXT,
  price DECIMAL(10,2) NOT NULL,
  original_price DECIMAL(10,2),
  image_url VARCHAR(255),
  thumbnail_url VARCHAR(255),
  sku VARCHAR(50) UNIQUE,
  preparation_time INTEGER, -- นาที
  allergens TEXT, -- JSON array
  nutritional_info TEXT, -- JSON
  is_available BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  tags TEXT, -- JSON array
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 5. ตารางคำสั่งซื้อ (Orders)
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  table_id INTEGER REFERENCES tables(id) ON DELETE SET NULL,
  booking_id INTEGER REFERENCES bookings(id) ON DELETE SET NULL,
  order_number VARCHAR(50) UNIQUE NOT NULL,
  items JSONB NOT NULL, -- Array of order items
  subtotal DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'served', 'cancelled')),
  payment_method VARCHAR(20),
  payment_status VARCHAR(20) DEFAULT 'pending',
  staff_id VARCHAR(50),
  notes TEXT,
  preparation_time INTEGER, -- นาที
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 6. ตารางโปรโมชั่น (Promotions)
CREATE TABLE promotions (
  id SERIAL PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  description TEXT,
  promo_code VARCHAR(50) UNIQUE,
  discount_type VARCHAR(20) CHECK (discount_type IN ('percentage', 'fixed_amount', 'buy_one_get_one')),
  discount_value DECIMAL(10,2),
  min_order_amount DECIMAL(10,2),
  max_discount_amount DECIMAL(10,2),
  applicable_items TEXT, -- JSON array of menu item IDs
  start_date DATE,
  end_date DATE,
  usage_limit INTEGER,
  usage_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  image_url VARCHAR(255),
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 7. ตารางผู้ใช้ (Users) - สำหรับ local authentication
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE,
  password_hash VARCHAR(255),
  full_name VARCHAR(100),
  phone VARCHAR(20),
  role VARCHAR(20) DEFAULT 'customer' CHECK (role IN ('admin', 'staff', 'customer')),
  avatar_url VARCHAR(255),
  preferences JSONB,
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP,
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 8. ตาราการตั้งค่า (Settings)
CREATE TABLE settings (
  id SERIAL PRIMARY KEY,
  key VARCHAR(100) UNIQUE NOT NULL,
  value TEXT,
  description TEXT,
  data_type VARCHAR(20) DEFAULT 'string' CHECK (data_type IN ('string', 'number', 'boolean', 'json')),
  is_public BOOLEAN DEFAULT false,
  category VARCHAR(50),
  sync_version INTEGER DEFAULT 1,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 9. ตารางบันทึกการ Sync (Sync Log)
CREATE TABLE sync_log (
  id SERIAL PRIMARY KEY,
  table_name VARCHAR(50) NOT NULL,
  operation VARCHAR(20) NOT NULL, -- 'insert', 'update', 'delete'
  record_id INTEGER,
  sync_version INTEGER,
  synced_at TIMESTAMP DEFAULT NOW(),
  device_id VARCHAR(50),
  status VARCHAR(20) DEFAULT 'success' CHECK (status IN ('success', 'failed', 'pending')),
  error_message TEXT
);

-- 10. ตารางรูปภาพ (Images)
CREATE TABLE images (
  id SERIAL PRIMARY KEY,
  original_name VARCHAR(255) NOT NULL,
  file_name VARCHAR(255) UNIQUE NOT NULL,
  file_path VARCHAR(500) NOT NULL,
  file_size INTEGER,
  mime_type VARCHAR(100),
  width INTEGER,
  height INTEGER,
  thumbnail_path VARCHAR(500),
  category VARCHAR(50), -- 'menu', 'avatar', 'promotion', 'general'
  sync_version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes สำหรับ performance
CREATE INDEX idx_tables_status ON tables(status);
CREATE INDEX idx_bookings_date ON bookings(booking_date);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_menu_items_available ON menu_items(is_available);
CREATE INDEX idx_orders_table ON orders(table_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_promotions_active ON promotions(is_active);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_sync_log_table ON sync_log(table_name);
CREATE INDEX idx_sync_log_synced ON sync_log(synced_at);

-- Trigger สำหรับ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_promotions_updated_at BEFORE UPDATE ON promotions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger สำหรับ sync_version
CREATE OR REPLACE FUNCTION increment_sync_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sync_version = OLD.sync_version + 1;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER increment_tables_sync_version BEFORE UPDATE ON tables
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

CREATE TRIGGER increment_bookings_sync_version BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

CREATE TRIGGER increment_menu_items_sync_version BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

CREATE TRIGGER increment_categories_sync_version BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

CREATE TRIGGER increment_promotions_sync_version BEFORE UPDATE ON promotions
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

CREATE TRIGGER increment_users_sync_version BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();

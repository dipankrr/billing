-- Run this in your Supabase SQL Editor to MIGRATE to UUIDs
-- WARNING: This will drop existing tables and data!

DROP TABLE IF EXISTS public.bill_items;
DROP TABLE IF EXISTS public.bills;
DROP TABLE IF EXISTS public.customers;
DROP TABLE IF EXISTS public.products;

-- Create products table
create table public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  price numeric not null,
  stock int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create customers table
create table public.customers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  phone text not null,
  address text,
  previous_due numeric default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create bills table
create table public.bills (
  id uuid default gen_random_uuid() primary key,
  customer_id uuid references public.customers not null,
  total_amount numeric not null,
  discount numeric default 0,
  paid_amount numeric default 0,
  due_amount numeric default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create bill_items table
create table public.bill_items (
  id uuid default gen_random_uuid() primary key,
  bill_id uuid references public.bills not null,
  product_id uuid references public.products not null,
  quantity int not null,
  price_at_time numeric not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

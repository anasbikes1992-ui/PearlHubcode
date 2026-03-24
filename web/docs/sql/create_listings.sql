-- Stays listings table
CREATE TABLE IF NOT EXISTS public.stays_listings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  type TEXT NOT NULL DEFAULT 'guest_house',
  stars INTEGER DEFAULT 0,
  price_per_night NUMERIC NOT NULL DEFAULT 0,
  location TEXT NOT NULL DEFAULT '',
  lat NUMERIC DEFAULT 7.8731,
  lng NUMERIC DEFAULT 80.7718,
  rooms INTEGER DEFAULT 1,
  amenities TEXT[] DEFAULT '{}',
  images TEXT[] DEFAULT '{}',
  approved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Vehicles listings table
CREATE TABLE IF NOT EXISTS public.vehicles_listings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  make TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL DEFAULT 2024,
  type TEXT NOT NULL DEFAULT 'car',
  price NUMERIC NOT NULL DEFAULT 0,
  price_unit TEXT NOT NULL DEFAULT 'day',
  seats INTEGER DEFAULT 4,
  ac BOOLEAN DEFAULT true,
  driver TEXT DEFAULT 'optional',
  fuel TEXT DEFAULT 'Petrol',
  location TEXT NOT NULL DEFAULT '',
  lat NUMERIC DEFAULT 7.8731,
  lng NUMERIC DEFAULT 80.7718,
  images TEXT[] DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Events listings table
CREATE TABLE IF NOT EXISTS public.events_listings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  category TEXT NOT NULL DEFAULT 'concert',
  date DATE NOT NULL,
  time TIME NOT NULL,
  duration_hours NUMERIC DEFAULT 2,
  price NUMERIC NOT NULL DEFAULT 0,
  location TEXT NOT NULL DEFAULT '',
  lat NUMERIC DEFAULT 7.8731,
  lng NUMERIC DEFAULT 80.7718,
  capacity INTEGER DEFAULT 100,
  images TEXT[] DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
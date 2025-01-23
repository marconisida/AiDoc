// Add these types to your existing types.ts file

export interface UserProfile {
  id: string;
  user_id: string;
  first_name: string | null;
  last_name: string | null;
  country: string | null;
  preferred_language: string | null;
  whatsapp: string | null;
  birth_date: string | null;
  shipping_address: {
    street: string;
    city: string;
    state: string;
    country: string;
    postal_code: string;
  } | null;
  nationality_country: string | null;
  desired_residency_type: 'temporary_short' | 'temporary_long' | 'permanent_investment' | null;
  birth_country: string | null;
  primary_residency_country: string | null;
  residency_goal: 'tax_residency' | 'plan_b' | 'relocation' | null;
  marital_status: 'single' | 'married' | 'divorced' | 'widowed' | null;
  email: string;
  created_at: string;
  updated_at: string;
}

export interface ShippingAddress {
  street: string;
  city: string;
  state: string;
  country: string;
  postal_code: string;
}

export interface DocumentRequirement {
  id: string;
  name: string;
  description: string;
  required: boolean;
  condition?: (profile: UserProfile) => boolean;
}

export const SUPPORTED_COUNTRIES = [
  'Argentina', 'Australia', 'Austria', 'Bahamas', 'Barbados', 'Belgium',
  'Bolivia', 'Brazil', 'Brunei', 'Bulgaria', 'Canada', 'Chile', 'Colombia',
  'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Ecuador', 'El Salvador',
  'Estonia', 'Faroe Islands', 'Finland', 'France', 'Georgia', 'Germany',
  'Greece', 'Honduras', 'Hong Kong', 'Hungary', 'Iceland', 'Ireland', 'Israel',
  'Italy', 'Japan', 'Latvia', 'Liechtenstein', 'Lithuania', 'Luxembourg',
  'Malaysia', 'Malta', 'Mexico', 'Monaco', 'Netherlands', 'New Zealand',
  'Nicaragua', 'Norway', 'Panama', 'Peru', 'Poland', 'Portugal', 'Romania',
  'Russia', 'Singapore', 'Slovakia', 'Slovenia', 'South Korea', 'South Africa',
  'Spain', 'St Kitts and Nevis', 'Sweden', 'Switzerland', 'Taiwan', 'Turkey',
  'United Kingdom', 'United States', 'Uruguay'
];
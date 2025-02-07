export interface Organization {
  id: string;
  name: string;
  email: string | null;
  address: string | null;
  phone: string | null;
  registration_number: string;
  tax_number: string;
  subscription_plan_id: string | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserDetails {
  id: string;
  user_id: string;
  full_name: string | null;
  active_organization_id: string | null;
  last_active_at: string | null;
  created_at: string;
  updated_at: string;
}
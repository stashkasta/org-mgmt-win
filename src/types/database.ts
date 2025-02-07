export interface Organization {
  id: string;
  name: string;
  email: string | null;
  address: string | null;
  phone: string | null;
  registration_number: string;
  tax_number: string;
  subscription_plan_id: string | null;
  subscription_start_date: string | null;
  subscription_end_date: string | null;
  is_expired: boolean;
  is_blocked: boolean;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserOrganization {
  id: string;
  user_id: string;
  organization_id: string;
  role_id: string;
  role_name: string;
  is_blocked: boolean;
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

export interface SubscriptionPlan {
  id: string;
  name: string;
  price: number;
  currency: string;
  max_users: number;
  created_at: string;
  updated_at: string;
}
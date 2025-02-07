/*
  # Update subscription plans policy

  1. Changes
    - Drop existing subscription plans policy
    - Create new policy to allow public read access to subscription plans
    
  2. Security
    - Allows anonymous access to subscription plans table for SELECT operations only
    - Maintains existing RLS
*/

-- Drop existing subscription plans policy
DROP POLICY IF EXISTS "subscription_plans_read" ON subscription_plans;
DROP POLICY IF EXISTS "subscription_plans_select" ON subscription_plans;
DROP POLICY IF EXISTS "allow_read_subscription_plans" ON subscription_plans;

-- Create new public access policy
CREATE POLICY "allow_public_read_subscription_plans"
    ON subscription_plans FOR SELECT
    USING (true);
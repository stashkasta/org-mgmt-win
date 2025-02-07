/*
  # Update Starter plan max users

  1. Changes
    - Update max_users from 10 to 3 for the Starter plan
*/

UPDATE subscription_plans
SET max_users = 3
WHERE name = 'Starter';
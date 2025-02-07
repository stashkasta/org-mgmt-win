/*
  # Update Starter plan user limit
  
  Updates the max_users limit for the Starter subscription plan from 5 to 7 users.
*/

UPDATE subscription_plans
SET max_users = 7
WHERE name = 'Starter';
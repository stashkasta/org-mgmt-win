/*
  # Update Starter plan user limit

  Changes:
  - Updates the max_users limit for the Starter plan from 3 to 5 users
*/

UPDATE subscription_plans
SET max_users = 5
WHERE name = 'Starter';
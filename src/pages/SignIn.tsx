import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { AlertCircle, Building2, ChevronDown } from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { Organization, SubscriptionPlan } from '../types/database';

interface SignInFormData {
  email: string;
  password: string;
}

interface OrganizationSelectionData {
  organizationId: string;
}

interface OrganizationWithPlan extends Organization {
  subscription_plans: SubscriptionPlan;
  member_count: number;
}

export default function SignIn() {
  const [error, setError] = useState<string>('');
  const [organizations, setOrganizations] = useState<OrganizationWithPlan[]>([]);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [selectedOrgId, setSelectedOrgId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const { register: registerAuth, handleSubmit: handleAuthSubmit } = useForm<SignInFormData>();
  const { register: registerOrg, handleSubmit: handleOrgSubmit } = useForm<OrganizationSelectionData>();
  const navigate = useNavigate();

  const onAuthSubmit = async (data: SignInFormData) => {
    try {
      setError('');
      setLoading(true);
      
      // First, sign out to clear any existing session
      await supabase.auth.signOut();
      
      // Then attempt to sign in
      const { data: authData, error: signInError } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      });

      if (signInError) {
        if (signInError.message === 'Invalid login credentials') {
          throw new Error('Invalid email or password');
        }
        throw signInError;
      }

      if (!authData.user) {
        throw new Error('No user data returned after sign in');
      }

      // Fetch user's organizations with subscription plans and member count
      const { data: userOrgs, error: orgsError } = await supabase
        .from('user_organizations')
        .select(`
          organization:organizations (
            id,
            name,
            subscription_plans (*),
            member_count:user_organizations(count)
          )
        `)
        .eq('user_id', authData.user.id)
        .order('created_at');

      if (orgsError) throw orgsError;

      const userOrganizations = userOrgs
        .map(org => {
          if (!org.organization || !org.organization.subscription_plans) return null;
          return {
            ...org.organization,
            member_count: org.organization.member_count[0].count,
            subscription_plans: org.organization.subscription_plans
          };
        })
        .filter((org): org is OrganizationWithPlan => org !== null);

      if (userOrganizations.length === 0) {
        throw new Error('You are not a member of any organization');
      }

      setOrganizations(userOrganizations);
      setSelectedOrgId(userOrganizations[0].id);
      setIsAuthenticated(true);

    } catch (err) {
      console.error('Sign in error:', err);
      setError(err instanceof Error ? err.message : 'Failed to sign in');
      // Sign out on error to ensure clean state
      await supabase.auth.signOut();
    } finally {
      setLoading(false);
    }
  };

  const onOrganizationSubmit = async (data: OrganizationSelectionData) => {
    try {
      setError('');
      setLoading(true);

      if (!selectedOrgId) {
        throw new Error('Please select an organization');
      }

      // Get user ID
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('No user found');

      // Update active organization
      const { error: updateError } = await supabase
        .from('user_details')
        .update({ active_organization_id: selectedOrgId })
        .eq('user_id', user.id);

      if (updateError) throw updateError;

      navigate('/');

    } catch (err) {
      console.error('Organization selection error:', err);
      setError(err instanceof Error ? err.message : 'Failed to select organization');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          {isAuthenticated ? 'Select Organization' : 'Sign in to your account'}
        </h2>
        {!isAuthenticated && (
          <p className="mt-2 text-center text-sm text-gray-600">
            Or{' '}
            <Link to="/signup" className="font-medium text-indigo-600 hover:text-indigo-500">
              create a new account
            </Link>
          </p>
        )}
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          {error && (
            <div className="mb-4 p-4 bg-red-50 rounded-md">
              <div className="flex">
                <AlertCircle className="h-5 w-5 text-red-400" />
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-red-800">{error}</h3>
                </div>
              </div>
            </div>
          )}

          {!isAuthenticated ? (
            <form onSubmit={handleAuthSubmit(onAuthSubmit)} className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Email
                </label>
                <input
                  type="email"
                  {...registerAuth('email', { required: true })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Password
                </label>
                <input
                  type="password"
                  {...registerAuth('password', { required: true })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                />
              </div>

              <div>
                <button
                  type="submit"
                  disabled={loading}
                  className={`w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white ${
                    loading
                      ? 'bg-indigo-400 cursor-not-allowed'
                      : 'bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
                  }`}
                >
                  {loading ? 'Signing in...' : 'Sign in'}
                </button>
              </div>
            </form>
          ) : (
            <form onSubmit={handleOrgSubmit(onOrganizationSubmit)} className="space-y-6">
              <div className="space-y-4">
                <label className="block text-sm font-medium text-gray-700">
                  Select Organization
                </label>
                <div className="relative">
                  <select
                    value={selectedOrgId}
                    onChange={(e) => setSelectedOrgId(e.target.value)}
                    className="block w-full pl-3 pr-10 py-2 text-base border border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md appearance-none"
                  >
                    {organizations.map((org) => (
                      <option key={`org-${org.id}`} value={org.id}>
                        {org.name} - {org.member_count}/{org.subscription_plans.max_users} members
                      </option>
                    ))}
                  </select>
                  <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
                    <ChevronDown className="h-4 w-4" />
                  </div>
                </div>
              </div>

              <div>
                <button
                  type="submit"
                  disabled={loading}
                  className={`w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white ${
                    loading
                      ? 'bg-indigo-400 cursor-not-allowed'
                      : 'bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
                  }`}
                >
                  {loading ? 'Processing...' : 'Continue'}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
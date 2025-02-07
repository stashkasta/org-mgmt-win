import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { Building2, UserPlus, AlertCircle, LogIn, ChevronDown } from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { Organization } from '../types/database';

type SignUpMode = 'organization' | 'member';
type JoinMode = 'new' | 'existing';

interface OrganizationFormData {
  organizationName: string;
  registrationNumber: string;
  taxNumber: string;
  address: string;
  phone: string;
  email: string;
  fullName: string;
  password: string;
}

interface MemberFormData {
  email: string;
  password: string;
  fullName: string;
  organizationId?: string;
}

export default function SignUp() {
  const [mode, setMode] = useState<SignUpMode>('organization');
  const [joinMode, setJoinMode] = useState<JoinMode>('new');
  const [error, setError] = useState<string>('');
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [selectedOrgId, setSelectedOrgId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const { register, handleSubmit, reset, formState: { errors } } = useForm<OrganizationFormData | MemberFormData>();
  const navigate = useNavigate();

  const handleModeChange = async (newMode: SignUpMode) => {
    setMode(newMode);
    reset();
    setError('');
    setSelectedOrgId('');
    setOrganizations([]);

    if (newMode === 'member') {
      setLoading(true);
      try {
        const { data, error: fetchError } = await supabase
          .from('organizations')
          .select('*')
          .eq('is_default', false)
          .order('name');

        if (fetchError) throw fetchError;

        if (data && data.length > 0) {
          setOrganizations(data);
          setSelectedOrgId(data[0].id);
        } else {
          setError('No organizations available for joining');
        }
      } catch (err) {
        console.error('Error fetching organizations:', err);
        setError('Failed to load organizations. Please try again later.');
      } finally {
        setLoading(false);
      }
    }
  };

  const handleJoinModeChange = (newJoinMode: JoinMode) => {
    setJoinMode(newJoinMode);
    reset();
    setError('');
  };

  const onSubmit = async (data: OrganizationFormData | MemberFormData) => {
    try {
      setError('');
      setLoading(true);

      if (mode === 'member' && !selectedOrgId) {
        setError('Please select an organization');
        return;
      }

      if (mode === 'organization') {
        const orgData = data as OrganizationFormData;

        // Check if organization exists
        const { data: existingOrgs, error: checkError } = await supabase
          .from('organizations')
          .select('id')
          .or(`registration_number.eq.${orgData.registrationNumber},tax_number.eq.${orgData.taxNumber}`);

        if (checkError) throw checkError;
        if (existingOrgs && existingOrgs.length > 0) {
          throw new Error('An organization with this registration number or tax number already exists');
        }

        // Try to sign in first to check if user exists
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email: orgData.email,
          password: orgData.password,
        });

        let userId: string;

        if (signInError && signInError.message !== 'Invalid login credentials') {
          throw signInError;
        }

        if (!signInError) {
          // User exists, get their ID
          const { data: { user } } = await supabase.auth.getUser();
          if (!user) throw new Error('Failed to get user information');
          userId = user.id;
        } else {
          // User doesn't exist, create new account
          const { data: authData, error: signUpError } = await supabase.auth.signUp({
            email: orgData.email,
            password: orgData.password,
          });

          if (signUpError) throw signUpError;
          if (!authData.user) throw new Error('Failed to create user');
          userId = authData.user.id;

          // Create user details for new user
          const { error: userDetailsError } = await supabase
            .from('user_details')
            .insert([{
              user_id: userId,
              full_name: orgData.fullName,
            }]);

          if (userDetailsError) {
            await supabase.auth.admin.deleteUser(userId);
            throw userDetailsError;
          }
        }

        // Create organization
        const { data: newOrg, error: orgError } = await supabase
          .from('organizations')
          .insert([{
            name: orgData.organizationName,
            registration_number: orgData.registrationNumber,
            tax_number: orgData.taxNumber,
            address: orgData.address || null,
            phone: orgData.phone || null,
            is_default: false
          }])
          .select()
          .single();

        if (orgError) throw orgError;

        // Update user's active organization
        const { error: updateError } = await supabase
          .from('user_details')
          .update({ active_organization_id: newOrg.id })
          .eq('user_id', userId);

        if (updateError) throw updateError;

        // Get the Admin role
        const { data: adminRole, error: roleError } = await supabase
          .from('roles')
          .select('id')
          .eq('name', 'Admin')
          .single();

        if (roleError || !adminRole) {
          throw new Error('Failed to get role information');
        }

        // Create admin membership
        const { error: membershipError } = await supabase
          .from('user_organizations')
          .insert([{
            user_id: userId,
            organization_id: newOrg.id,
            role_id: adminRole.id,
            role_name: 'Admin'
          }]);

        if (membershipError) throw membershipError;

      } else {
        const memberData = data as MemberFormData;
        
        if (joinMode === 'new') {
          const { data: authData, error: authError } = await supabase.auth.signUp({
            email: memberData.email,
            password: memberData.password,
          });

          if (authError) {
            if (authError.message === 'User already registered') {
              throw new Error('An account with this email already exists. Please sign in or use a different email.');
            }
            throw authError;
          }
          if (!authData.user) throw new Error('Failed to create user');

          // Create user details
          const { error: userDetailsError } = await supabase
            .from('user_details')
            .insert([{
              user_id: authData.user.id,
              full_name: memberData.fullName,
              active_organization_id: selectedOrgId
            }]);

          if (userDetailsError) {
            await supabase.auth.admin.deleteUser(authData.user.id);
            throw userDetailsError;
          }

          // Get the Member role
          const { data: memberRole, error: roleError } = await supabase
            .from('roles')
            .select('id')
            .eq('name', 'Member')
            .single();

          if (roleError || !memberRole) {
            throw new Error('Failed to get role information');
          }

          // Create membership
          const { error: membershipError } = await supabase
            .from('user_organizations')
            .insert([{
              user_id: authData.user.id,
              organization_id: selectedOrgId,
              role_id: memberRole.id,
              role_name: 'Member'
            }]);

          if (membershipError) {
            await supabase.auth.admin.deleteUser(authData.user.id);
            throw membershipError;
          }

        } else {
          // Existing user flow
          if (!selectedOrgId) {
            throw new Error('Please select an organization');
          }

          const { error: signInError } = await supabase.auth.signInWithPassword({
            email: memberData.email,
            password: memberData.password,
          });

          if (signInError) {
            throw new Error('Invalid email or password');
          }

          const { data: { user }, error: userError } = await supabase.auth.getUser();
          if (userError || !user) {
            throw new Error('Failed to get user information');
          }

          // Check existing membership
          const { data: existingMembership } = await supabase
            .from('user_organizations')
            .select('id')
            .eq('user_id', user.id)
            .eq('organization_id', selectedOrgId);

          if (existingMembership && existingMembership.length > 0) {
            throw new Error('You are already a member of this organization');
          }

          // Get Member role
          const { data: memberRole, error: roleError } = await supabase
            .from('roles')
            .select('id')
            .eq('name', 'Member')
            .single();

          if (roleError || !memberRole) {
            throw new Error('Failed to get role information');
          }

          // Create membership
          const { error: membershipError } = await supabase
            .from('user_organizations')
            .insert([{
              user_id: user.id,
              organization_id: selectedOrgId,
              role_id: memberRole.id,
              role_name: 'Member'
            }]);

          if (membershipError) {
            throw membershipError;
          }

          // Update active organization
          const { error: updateError } = await supabase
            .from('user_details')
            .update({ active_organization_id: selectedOrgId })
            .eq('user_id', user.id);

          if (updateError) {
            throw updateError;
          }
        }
      }

      navigate('/signin');
    } catch (err) {
      console.error('Signup error:', err);
      setError(err instanceof Error ? err.message : 'An error occurred during sign up. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Create your account
        </h2>
        <p className="mt-2 text-center text-sm text-gray-600">
          Already have an account?{' '}
          <Link to="/signin" className="font-medium text-indigo-600 hover:text-indigo-500">
            Sign in
          </Link>
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div className="flex space-x-4 mb-6">
            <button
              onClick={() => handleModeChange('organization')}
              className={`flex-1 py-2 px-4 rounded-md ${
                mode === 'organization'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              } transition-colors duration-200`}
            >
              <Building2 className="inline-block w-5 h-5 mr-2" />
              Register Organization
            </button>
            <button
              onClick={() => handleModeChange('member')}
              className={`flex-1 py-2 px-4 rounded-md ${
                mode === 'member'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              } transition-colors duration-200`}
            >
              <UserPlus className="inline-block w-5 h-5 mr-2" />
              Join Organization
            </button>
          </div>

          {mode === 'member' && (
            <div className="flex space-x-4 mb-6">
              <button
                onClick={() => handleJoinModeChange('new')}
                className={`flex-1 py-2 px-4 rounded-md ${
                  joinMode === 'new'
                    ? 'bg-green-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                } transition-colors duration-200`}
              >
                <UserPlus className="inline-block w-5 h-5 mr-2" />
                New User
              </button>
              <button
                onClick={() => handleJoinModeChange('existing')}
                className={`flex-1 py-2 px-4 rounded-md ${
                  joinMode === 'existing'
                    ? 'bg-green-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                } transition-colors duration-200`}
              >
                <LogIn className="inline-block w-5 h-5 mr-2" />
                Existing User
              </button>
            </div>
          )}

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

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {mode === 'member' && (
              <div className="space-y-4">
                <label className="block text-sm font-medium text-gray-700">
                  Select Organization <span className="text-red-500">*</span>
                </label>
                {loading ? (
                  <div className="text-center py-4 text-gray-500">Loading organizations...</div>
                ) : (
                  <div className="relative">
                    <select
                      value={selectedOrgId}
                      onChange={(e) => setSelectedOrgId(e.target.value)}
                      className={`block w-full pl-3 pr-10 py-2 text-base border ${
                        !selectedOrgId ? 'border-red-500' : 'border-gray-300'
                      } focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md appearance-none`}
                    >
                      <option value="">Select an organization</option>
                      {organizations.map((org) => (
                        <option key={org.id} value={org.id}>
                          {org.name} - Reg: {org.registration_number}
                        </option>
                      ))}
                    </select>
                    <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
                      <ChevronDown className="h-4 w-4" />
                    </div>
                  </div>
                )}
              </div>
            )}

            {mode === 'organization' && (
              <>
                <div className="space-y-6">
                  <h3 className="text-lg font-medium text-gray-900">Organization Information</h3>
                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Organization Name <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      {...register('organizationName', { 
                        required: 'Organization name is required' 
                      })}
                      className={`mt-1 block w-full border ${
                        errors.organizationName ? 'border-red-500' : 'border-gray-300'
                      } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
                    />
                    {errors.organizationName && (
                      <p className="mt-1 text-sm text-red-600">{errors.organizationName.message}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Registration Number <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      {...register('registrationNumber', { 
                        required: 'Registration number is required' 
                      })}
                      className={`mt-1 block w-full border ${
                        errors.registrationNumber ? 'border-red-500' : 'border-gray-300'
                      } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
                    />
                    {errors.registrationNumber && (
                      <p className="mt-1 text-sm text-red-600">{errors.registrationNumber.message}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Tax Number <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      {...register('taxNumber', { 
                        required: 'Tax number is required' 
                      })}
                      className={`mt-1 block w-full border ${
                        errors.taxNumber ? 'border-red-500' : 'border-gray-300'
                      } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
                    />
                    {errors.taxNumber && (
                      <p className="mt-1 text-sm text-red-600">{errors.taxNumber.message}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Address
                    </label>
                    <input
                      type="text"
                      {...register('address')}
                      className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Phone
                    </label>
                    <input
                      type="text"
                      {...register('phone')}
                      className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                </div>

                <div className="relative py-3">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-gray-300" />
                  </div>
                  <div className="relative flex justify-center">
                    <span className="px-2 bg-white text-sm text-gray-500">
                      Administrator Information
                    </span>
                  </div>
                </div>
              </>
            )}

            {(mode === 'organization' || joinMode === 'new') && (
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Your Full Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  {...register('fullName', { 
                    required: 'Full name is required' 
                  })}
                  className={`mt-1 block w-full border ${
                    errors.fullName ? 'border-red-500' : 'border-gray-300'
                  } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
                />
                {errors.fullName && (
                  <p className="mt-1 text-sm text-red-600">{errors.fullName.message}</p>
                )}
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Email <span className="text-red-500">*</span>
              </label>
              <input
                type="email"
                {...register('email', { 
                  required: 'Email is required',
                  pattern: {
                    value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                    message: 'Invalid email address'
                  }
                })}
                className={`mt-1 block w-full border ${
                  errors.email ? 'border-red-500' : 'border-gray-300'
                } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
              />
              {errors.email && (
                <p className="mt-1 text-sm text-red-600">{errors.email.message}</p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Password <span className="text-red-500">*</span>
              </label>
              <input
                type="password"
                {...register('password', { 
                  required: 'Password is required',
                  minLength: {
                    value: 6,
                    message: 'Password must be at least 6 characters'
                  }
                })}
                className={`mt-1 block w-full border ${
                  errors.password ? 'border-red-500' : 'border-gray-300'
                } rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500`}
              />
              {errors.password && (
                <p className="mt-1 text-sm text-red-600">{errors.password.message}</p>
              )}
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
                {loading ? 'Processing...' : mode === 'organization' ? 'Create Organization' : (joinMode === 'new' ? 'Join Organization' : 'Add Organization')}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, CircleUser, Building2, LogOut, CheckCircle2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { Organization, UserDetails } from '../types/database';
import Header from '../components/Header';

interface UserOrganization {
  organization: Organization;
  role_name: string;
}

export default function Profile() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [userDetails, setUserDetails] = useState<UserDetails | null>(null);
  const [activeOrganization, setActiveOrganization] = useState<Organization | null>(null);
  const [userOrganizations, setUserOrganizations] = useState<UserOrganization[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchProfileData() {
      if (!user) {
        navigate('/signin');
        return;
      }

      try {
        // Fetch user details
        const { data: userDetailsData } = await supabase
          .from('user_details')
          .select('*')
          .eq('user_id', user.id)
          .single();

        if (userDetailsData) {
          setUserDetails(userDetailsData);

          // Fetch active organization
          if (userDetailsData.active_organization_id) {
            const { data: orgData } = await supabase
              .from('organizations')
              .select('*')
              .eq('id', userDetailsData.active_organization_id)
              .single();

            setActiveOrganization(orgData);
          }
        }

        // Fetch all user organizations with roles
        const { data: userOrgsData, error: userOrgsError } = await supabase
          .from('user_organizations')
          .select(`
            organization:organizations (
              id,
              name,
              registration_number,
              tax_number,
              address,
              phone
            ),
            role_name
          `)
          .eq('user_id', user.id)
          .order('created_at');

        if (userOrgsError) throw userOrgsError;
        setUserOrganizations(userOrgsData);

      } catch (error) {
        console.error('Error fetching profile data:', error);
      } finally {
        setLoading(false);
      }
    }

    fetchProfileData();
  }, [user, navigate]);

  const handleSwitchOrganization = async (organizationId: string) => {
    try {
      if (!user) return;

      const { error: updateError } = await supabase
        .from('user_details')
        .update({ active_organization_id: organizationId })
        .eq('user_id', user.id);

      if (updateError) throw updateError;

      // Refresh the page to update the active organization
      window.location.reload();
    } catch (error) {
      console.error('Error switching organization:', error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <div className="flex items-center justify-center h-[calc(100vh-64px)]">
          <div className="text-gray-500">Loading...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <div className="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto space-y-8">
          {/* Profile Information */}
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6">
              <div className="flex items-center">
                <CircleUser className="h-8 w-8 text-gray-400" />
                <h3 className="ml-3 text-lg leading-6 font-medium text-gray-900">
                  Profile Information
                </h3>
              </div>
            </div>
            <div className="border-t border-gray-200 px-4 py-5 sm:px-6">
              <dl className="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
                <div className="sm:col-span-1">
                  <dt className="text-sm font-medium text-gray-500 flex items-center">
                    <User className="h-4 w-4 mr-2" />
                    Full Name
                  </dt>
                  <dd className="mt-1 text-sm text-gray-900">
                    {userDetails?.full_name || 'Not set'}
                  </dd>
                </div>
                <div className="sm:col-span-1">
                  <dt className="text-sm font-medium text-gray-500 flex items-center">
                    <Building2 className="h-4 w-4 mr-2" />
                    Active Organization
                  </dt>
                  <dd className="mt-1 text-sm text-gray-900">
                    {activeOrganization?.name || 'No active organization'}
                  </dd>
                </div>
                <div className="sm:col-span-2">
                  <dt className="text-sm font-medium text-gray-500">Email Address</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user?.email}</dd>
                </div>
              </dl>
            </div>
          </div>

          {/* Organizations List */}
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6">
              <div className="flex items-center">
                <Building2 className="h-6 w-6 text-gray-400" />
                <h3 className="ml-3 text-lg leading-6 font-medium text-gray-900">
                  Your Organizations
                </h3>
              </div>
              <p className="mt-1 max-w-2xl text-sm text-gray-500">
                Organizations you are a member of
              </p>
            </div>
            <div className="border-t border-gray-200">
              <ul className="divide-y divide-gray-200">
                {userOrganizations.map(({ organization, role_name }) => (
                  <li key={organization.id} className="px-4 py-4 sm:px-6">
                    <div className="flex items-center justify-between">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center">
                          {activeOrganization?.id === organization.id && (
                            <CheckCircle2 className="h-5 w-5 text-green-500 mr-2" />
                          )}
                          <div>
                            <h4 className="text-sm font-medium text-gray-900">
                              {organization.name}
                            </h4>
                            <p className="text-sm text-gray-500">
                              Registration: {organization.registration_number}
                            </p>
                          </div>
                        </div>
                        <div className="mt-2">
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            {role_name}
                          </span>
                          {organization.address && (
                            <p className="mt-1 text-sm text-gray-500">
                              Address: {organization.address}
                            </p>
                          )}
                        </div>
                      </div>
                      {activeOrganization?.id !== organization.id && (
                        <button
                          onClick={() => handleSwitchOrganization(organization.id)}
                          className="ml-4 px-3 py-1 text-sm font-medium text-indigo-600 hover:text-indigo-900 focus:outline-none focus:underline"
                        >
                          Switch to this organization
                        </button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          {/* Active Organization Details */}
          {activeOrganization && (
            <div className="bg-white shadow overflow-hidden sm:rounded-lg">
              <div className="px-4 py-5 sm:px-6">
                <div className="flex items-center">
                  <Building2 className="h-6 w-6 text-gray-400" />
                  <h3 className="ml-3 text-lg leading-6 font-medium text-gray-900">
                    Active Organization Details
                  </h3>
                </div>
              </div>
              <div className="border-t border-gray-200 px-4 py-5 sm:px-6">
                <dl className="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
                  <div className="sm:col-span-1">
                    <dt className="text-sm font-medium text-gray-500">Registration Number</dt>
                    <dd className="mt-1 text-sm text-gray-900">
                      {activeOrganization.registration_number}
                    </dd>
                  </div>
                  <div className="sm:col-span-1">
                    <dt className="text-sm font-medium text-gray-500">Tax Number</dt>
                    <dd className="mt-1 text-sm text-gray-900">
                      {activeOrganization.tax_number}
                    </dd>
                  </div>
                  {activeOrganization.address && (
                    <div className="sm:col-span-2">
                      <dt className="text-sm font-medium text-gray-500">Address</dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {activeOrganization.address}
                      </dd>
                    </div>
                  )}
                  {activeOrganization.phone && (
                    <div className="sm:col-span-2">
                      <dt className="text-sm font-medium text-gray-500">Phone</dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {activeOrganization.phone}
                      </dd>
                    </div>
                  )}
                </dl>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
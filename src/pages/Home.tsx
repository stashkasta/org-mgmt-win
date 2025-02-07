import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AlertTriangle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';

export default function Home() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [isBlocked, setIsBlocked] = useState(false);
  const [organizationName, setOrganizationName] = useState<string | null>(null);

  useEffect(() => {
    const checkBlockStatus = async () => {
      if (!user) {
        navigate('/signin');
        return;
      }

      try {
        // Get user's active organization
        const { data: userDetails } = await supabase
          .from('user_details')
          .select('active_organization_id')
          .eq('user_id', user.id)
          .single();

        if (userDetails?.active_organization_id) {
          // Check if user is blocked in active organization
          const { data: membership } = await supabase
            .from('user_organizations')
            .select('is_blocked, organization:organizations(name, is_blocked)')
            .eq('user_id', user.id)
            .eq('organization_id', userDetails.active_organization_id)
            .single();

          if (membership) {
            setIsBlocked(membership.is_blocked || membership.organization.is_blocked);
            setOrganizationName(membership.organization.name);
          }
        }
      } catch (error) {
        console.error('Error checking block status:', error);
      }
    };

    checkBlockStatus();
  }, [user, navigate]);

  if (isBlocked) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div className="h-[calc(100vh-10rem)] flex items-center justify-center">
            <div className="bg-red-50 p-8 rounded-lg shadow-sm max-w-lg w-full">
              <div className="flex items-center space-x-3">
                <AlertTriangle className="h-8 w-8 text-red-500" />
                <h1 className="text-xl font-semibold text-red-800">Access Blocked</h1>
              </div>
              <p className="mt-4 text-red-700">
                Your access to {organizationName ? <strong>{organizationName}</strong> : 'this organization'} has been blocked. 
                Please contact your organization administrator for assistance.
              </p>
              <button
                onClick={() => supabase.auth.signOut()}
                className="mt-6 w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              >
                Sign Out
              </button>
            </div>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <div className="h-[calc(100vh-10rem)] flex items-center justify-center">
          <div className="text-center max-w-lg mx-auto px-4 sm:px-6 lg:px-8">
            <h1 className="text-xl sm:text-2xl font-medium text-gray-800 mb-4">
              Welcome to your organization dashboard
            </h1>
            <p className="text-sm sm:text-base text-gray-600">
              Manage your organization's settings, users, and subscriptions all in one place.
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
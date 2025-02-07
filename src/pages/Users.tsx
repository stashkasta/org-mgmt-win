import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Edit2, Save, X, Mail, Building2, Calendar, Clock, Users as UsersIcon } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';

interface UserOrganization {
  organization: {
    id: string;
    name: string;
    registration_number: string;
    tax_number: string;
    address: string | null;
    phone: string | null;
    is_blocked: boolean;
    subscription_plans: {
      name: string;
      max_users: number;
    };
  };
  role_name: string;
  is_blocked: boolean;
}

interface UserData {
  id: string;
  email: string;
  user_details: {
    id: string;
    full_name: string | null;
    active_organization_id: string | null;
    last_active_at: string | null;
  } | null;
  organizations: UserOrganization[];
}

interface EditingUser {
  id: string;
  full_name: string;
}

export default function Users() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [editingUser, setEditingUser] = useState<EditingUser | null>(null);
  const [error, setError] = useState<string>('');
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);

  useEffect(() => {
    checkSuperAdminStatus();
  }, [user]);

  useEffect(() => {
    if (isSuperAdmin) {
      fetchUsers();
    }
  }, [isSuperAdmin]);

  const checkSuperAdminStatus = async () => {
    if (!user) {
      navigate('/signin');
      return;
    }

    try {
      const { data, error } = await supabase
        .from('user_organizations')
        .select('role_name')
        .eq('user_id', user.id)
        .eq('role_name', 'Super-admin')
        .single();

      if (error) throw error;
      setIsSuperAdmin(!!data);

      if (!data) {
        navigate('/');
      }
    } catch (error) {
      console.error('Error checking super admin status:', error);
      navigate('/');
    }
  };

  const ensureUserDetails = async (userId: string) => {
    try {
      const { data: existingDetails, error: fetchError } = await supabase
        .from('user_details')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

      if (fetchError) throw fetchError;

      if (!existingDetails) {
        const { data: newDetails, error: insertError } = await supabase
          .from('user_details')
          .insert([{
            user_id: userId,
            full_name: null,
            active_organization_id: null,
            last_active_at: null
          }])
          .select()
          .single();

        if (insertError) throw insertError;
        return newDetails;
      }

      return existingDetails;
    } catch (error) {
      console.error('Error ensuring user details:', error);
      return null;
    }
  };

  const fetchUsers = async () => {
    try {
      const { data: viewUsers, error: viewError } = await supabase
        .from('users_view')
        .select('id, email, sort_name')
        .order('sort_name');

      if (viewError) throw viewError;

      if (!viewUsers) {
        setUsers([]);
        return;
      }

      const usersWithDetails = await Promise.all(
        viewUsers.map(async (viewUser) => {
          const userDetails = await ensureUserDetails(viewUser.id);

          const { data: userOrgs, error: orgsError } = await supabase
            .from('user_organizations')
            .select(`
              role_name,
              is_blocked,
              organization:organizations (
                id,
                name,
                registration_number,
                tax_number,
                address,
                phone,
                is_blocked,
                is_default,
                subscription_plans (
                  name,
                  max_users
                )
              )
            `)
            .eq('user_id', viewUser.id);

          if (orgsError) {
            console.error('Error fetching user organizations:', orgsError);
            return null;
          }

          return {
            id: viewUser.id,
            email: viewUser.email,
            user_details: userDetails,
            organizations: userOrgs || []
          };
        })
      );

      setUsers(usersWithDetails.filter((user): user is UserData => user !== null));
    } catch (error) {
      console.error('Error fetching users:', error);
      setError('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (user: UserData) => {
    setEditingUser({
      id: user.id,
      full_name: user.user_details?.full_name || user.email.split('@')[0]
    });
  };

  const handleSave = async () => {
    if (!editingUser) return;

    try {
      setError('');

      const userDetails = await ensureUserDetails(editingUser.id);
      
      if (!userDetails) {
        throw new Error('Failed to create or update user details');
      }

      const { error: updateError } = await supabase
        .from('user_details')
        .update({ full_name: editingUser.full_name })
        .eq('user_id', editingUser.id);

      if (updateError) throw updateError;

      await fetchUsers();
      setEditingUser(null);
    } catch (error) {
      console.error('Error updating user:', error);
      setError(error instanceof Error ? error.message : 'Failed to update user');
    }
  };

  const getUserDisplayName = (user: UserData): string => {
    if (user.user_details?.full_name) {
      return user.user_details.full_name;
    }
    const emailName = user.email.split('@')[0];
    return emailName
      .replace(/[._]/g, ' ')
      .replace(/\b\w/g, letter => letter.toUpperCase());
  };

  const formatDate = (date: string | null): string => {
    if (!date) return 'Never';
    return new Date(date).toLocaleString();
  };

  const filteredUsers = users.filter(user => 
    user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.user_details?.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.organizations.some(org => 
      org.organization.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      org.role_name.toLowerCase().includes(searchTerm.toLowerCase())
    )
  );

  if (!isSuperAdmin) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <div className="space-y-6">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <h2 className="text-xl sm:text-2xl font-semibold text-gray-900">User Management</h2>
            <UsersIcon className="h-6 w-6 sm:h-8 sm:w-8 text-gray-400" />
          </div>
          
          <div className="relative">
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Search className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                placeholder="Search users by name, email, organization, or role..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
            </div>
          </div>

          {error && (
            <div className="p-4 bg-red-50 rounded-md">
              <div className="flex">
                <div className="flex-shrink-0">
                  <X className="h-5 w-5 text-red-400" aria-hidden="true" />
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-red-800">{error}</h3>
                </div>
              </div>
            </div>
          )}

          {loading ? (
            <div className="text-center py-12">
              <p className="text-gray-500">Loading users...</p>
            </div>
          ) : filteredUsers.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500">No users found</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {filteredUsers.map((user) => (
                <div key={user.id} className="bg-white shadow rounded-lg overflow-hidden">
                  {/* User Header */}
                  <div className="px-4 py-5 sm:px-6 border-b border-gray-200">
                    {editingUser?.id === user.id ? (
                      <input
                        type="text"
                        value={editingUser.full_name}
                        onChange={(e) => setEditingUser({ ...editingUser, full_name: e.target.value })}
                        className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                        placeholder="Full Name"
                      />
                    ) : (
                      <div className="flex justify-between items-start">
                        <div>
                          <h3 className="text-lg font-medium text-gray-900">
                            {getUserDisplayName(user)}
                          </h3>
                          <div className="mt-1 flex items-center text-sm text-gray-500">
                            <Mail className="h-4 w-4 mr-1" />
                            {user.email}
                          </div>
                        </div>
                        {!editingUser && (
                          <button
                            onClick={() => handleEdit(user)}
                            className="ml-2 inline-flex items-center p-1.5 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                          >
                            <Edit2 className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    )}
                  </div>

                  {/* User Details */}
                  <div className="px-4 py-5 sm:px-6 space-y-4">
                    {/* Organizations */}
                    <div className="space-y-3">
                      <h4 className="text-sm font-medium text-gray-700">Organizations & Roles</h4>
                      {user.organizations.map((org, index) => (
                        <div key={index} className="flex items-start justify-between">
                          <div className="flex items-start space-x-2 text-sm">
                            <Building2 className="h-4 w-4 text-gray-400 mt-0.5" />
                            <div>
                              <span className="font-medium">{org.organization.name}</span>
                              <div className="flex flex-wrap gap-2 mt-1">
                                <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                  {org.role_name}
                                </span>
                                {org.organization.id === user.user_details?.active_organization_id && (
                                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                    Active
                                  </span>
                                )}
                                {(org.is_blocked || org.organization.is_blocked) && (
                                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                    Blocked
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>
                          {!org.organization.is_blocked && !org.organization.is_default && (
                            <button
                              onClick={async () => {
                                try {
                                  const { error } = await supabase
                                    .from('user_organizations')
                                    .update({ is_blocked: !org.is_blocked })
                                    .eq('user_id', user.id)
                                    .eq('organization_id', org.organization.id);

                                  if (error) throw error;
                                  await fetchUsers();
                                } catch (error) {
                                  console.error('Error toggling user block status:', error);
                                  setError('Failed to update user block status');
                                }
                              }}
                              className={`text-xs font-medium px-2 py-1 rounded ${
                                org.is_blocked
                                  ? 'bg-red-100 text-red-800 hover:bg-red-200'
                                  : 'bg-green-100 text-green-800 hover:bg-green-200'
                              } transition-colors duration-200`}
                            >
                              {org.is_blocked ? 'Blocked' : 'Active'}
                            </button>
                          )}
                        </div>
                      ))}
                    </div>

                    {/* Activity Info */}
                    <div className="space-y-2">
                      <div className="flex items-center text-sm">
                        <Calendar className="h-4 w-4 text-gray-400 mr-2" />
                        <span className="text-gray-600">
                          Joined: {formatDate(user.user_details?.created_at || null)}
                        </span>
                      </div>
                      <div className="flex items-center text-sm">
                        <Clock className="h-4 w-4 text-gray-400 mr-2" />
                        <span className="text-gray-600">
                          Last active: {formatDate(user.user_details?.last_active_at || null)}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Edit Actions */}
                  {editingUser?.id === user.id && (
                    <div className="px-4 py-4 sm:px-6 bg-gray-50 border-t border-gray-200">
                      <div className="flex justify-end space-x-3">
                        <button
                          onClick={() => setEditingUser(null)}
                          className="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Cancel
                        </button>
                        <button
                          onClick={handleSave}
                          className="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Save Changes
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
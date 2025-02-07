import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Edit2, Save, X, Building2, Mail, Phone, MapPin, CreditCard, Users, Calendar, UserPlus, UserMinus } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';
import type { Organization, SubscriptionPlan } from '../types/database';

interface OrganizationWithPlan extends Organization {
  subscription_plans: SubscriptionPlan;
  member_count: number;
  members?: Array<{
    id: string;
    user_id: string;
    email?: string;
    full_name?: string | null;
    role_name: string;
    is_blocked: boolean;
  }>;
}

interface EditingOrg {
  id: string;
  name: string;
  email: string | null;
  address: string | null;
  phone: string | null;
  subscription_plan_id: string;
  subscription_start_date: string | null;
  subscription_end_date: string | null;
  is_blocked: boolean;
}

interface AddMemberForm {
  email: string;
  organizationId: string;
}

interface AvailableUser {
  id: string;
  email: string;
  full_name: string | null;
}

export default function Organizations() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [organizations, setOrganizations] = useState<OrganizationWithPlan[]>([]);
  const [subscriptionPlans, setSubscriptionPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [editingOrg, setEditingOrg] = useState<EditingOrg | null>(null);
  const [error, setError] = useState<string>('');
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [addingMember, setAddingMember] = useState<AddMemberForm | null>(null);
  const [availableUsers, setAvailableUsers] = useState<AvailableUser[]>([]);
  const [searchingUsers, setSearchingUsers] = useState(false);

  useEffect(() => {
    checkSuperAdminStatus();
  }, [user]);

  useEffect(() => {
    if (isSuperAdmin) {
      fetchOrganizations();
      fetchSubscriptionPlans();
    }
  }, [isSuperAdmin]);

  useEffect(() => {
    if (addingMember && addingMember.email.length >= 2) {
      searchUsers(addingMember.email);
    } else {
      setAvailableUsers([]);
    }
  }, [addingMember?.email]);

  const searchUsers = async (searchTerm: string) => {
    try {
      setSearchingUsers(true);
      const { data: users, error: usersError } = await supabase
        .from('users_view')
        .select('id, email, sort_name')
        .ilike('email', `%${searchTerm}%`)
        .limit(5);

      if (usersError) throw usersError;

      setAvailableUsers(users.map(u => ({
        id: u.id,
        email: u.email,
        full_name: u.sort_name
      })));
    } catch (error) {
      console.error('Error searching users:', error);
    } finally {
      setSearchingUsers(false);
    }
  };

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

  const fetchSubscriptionPlans = async () => {
    try {
      const { data: plans, error } = await supabase
        .from('subscription_plans')
        .select('*')
        .order('price');

      if (error) throw error;
      setSubscriptionPlans(plans);
    } catch (error) {
      console.error('Error fetching subscription plans:', error);
      setError('Failed to load subscription plans');
    }
  };

  const fetchOrganizations = async () => {
    try {
      const { data, error } = await supabase
        .from('organizations')
        .select(`
          *,
          subscription_plans (*),
          member_count:user_organizations(count)
        `)
        .order('name');

      if (error) throw error;

      if (data) {
        const orgsWithDetails = await Promise.all(data.map(async (org) => {
          const { data: membersData, error: membersError } = await supabase
            .from('users_view')
            .select(`
              user_organizations!inner (
                id,
                user_id,
                role_name,
                is_blocked
              ),
              id,
              email,
              sort_name
            `)
            .eq('user_organizations.organization_id', org.id);

          if (membersError) throw membersError;

          const members = membersData?.map(member => ({
            id: member.user_organizations[0].id,
            user_id: member.user_organizations[0].user_id,
            email: member.email,
            full_name: member.sort_name,
            role_name: member.user_organizations[0].role_name,
            is_blocked: member.user_organizations[0].is_blocked
          }));

          return {
            ...org,
            member_count: org.member_count[0].count,
            is_expired: org.subscription_end_date ? new Date(org.subscription_end_date) < new Date() : false,
            members
          };
        }));

        setOrganizations(orgsWithDetails);
      }
    } catch (error) {
      console.error('Error fetching organizations:', error);
      setError('Failed to load organizations');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (org: OrganizationWithPlan) => {
    setEditingOrg({
      id: org.id,
      name: org.name,
      email: org.email,
      address: org.address,
      phone: org.phone,
      subscription_plan_id: org.subscription_plan_id || '',
      subscription_start_date: org.subscription_start_date,
      subscription_end_date: org.subscription_end_date,
      is_blocked: org.is_blocked
    });
  };

  const handleSave = async () => {
    if (!editingOrg) return;

    try {
      setError('');

      if (editingOrg.subscription_start_date && editingOrg.subscription_end_date) {
        const startDate = new Date(editingOrg.subscription_start_date);
        const endDate = new Date(editingOrg.subscription_end_date);
        
        if (endDate <= startDate) {
          throw new Error('Subscription end date must be after start date');
        }
      }

      const { error: updateError } = await supabase
        .from('organizations')
        .update({
          name: editingOrg.name,
          email: editingOrg.email,
          address: editingOrg.address,
          phone: editingOrg.phone,
          subscription_plan_id: editingOrg.subscription_plan_id,
          subscription_start_date: editingOrg.subscription_start_date,
          subscription_end_date: editingOrg.subscription_end_date,
          is_blocked: editingOrg.is_blocked
        })
        .eq('id', editingOrg.id);

      if (updateError) throw updateError;

      await fetchOrganizations();
      setEditingOrg(null);
    } catch (error) {
      console.error('Error updating organization:', error);
      setError(error instanceof Error ? error.message : 'Failed to update organization');
    }
  };

  const handleToggleBlock = async (organizationId: string, isBlocked: boolean) => {
    try {
      const { error: updateError } = await supabase
        .from('organizations')
        .update({ is_blocked: !isBlocked })
        .eq('id', organizationId);

      if (updateError) throw updateError;

      await fetchOrganizations();
    } catch (error) {
      console.error('Error toggling organization block status:', error);
      setError('Failed to update organization block status');
    }
  };

  const handleToggleMemberBlock = async (memberId: string, isBlocked: boolean) => {
    try {
      const { error: updateError } = await supabase
        .from('user_organizations')
        .update({ is_blocked: !isBlocked })
        .eq('id', memberId);

      if (updateError) throw updateError;

      await fetchOrganizations();
    } catch (error) {
      console.error('Error toggling member block status:', error);
      setError('Failed to update member block status');
    }
  };

  const handleRemoveMember = async (memberId: string) => {
    try {
      const { error: deleteError } = await supabase
        .from('user_organizations')
        .delete()
        .eq('id', memberId);

      if (deleteError) throw deleteError;

      await fetchOrganizations();
    } catch (error) {
      console.error('Error removing member:', error);
      setError('Failed to remove member');
    }
  };

  const handleAddMember = async (organizationId: string) => {
    setAddingMember({ email: '', organizationId });
  };

  const handleAddMemberSubmit = async (userId?: string) => {
    if (!addingMember) return;

    try {
      setError('');

      let targetUserId = userId;

      if (!targetUserId) {
        const { data: userData, error: userError } = await supabase
          .from('users_view')
          .select('id')
          .eq('email', addingMember.email)
          .single();

        if (userError) throw new Error('User not found');
        targetUserId = userData.id;
      }

      const { data: memberRole, error: roleError } = await supabase
        .from('roles')
        .select('id')
        .eq('name', 'Member')
        .single();

      if (roleError) throw new Error('Failed to get role information');

      const { error: membershipError } = await supabase
        .from('user_organizations')
        .insert([{
          user_id: targetUserId,
          organization_id: addingMember.organizationId,
          role_id: memberRole.id,
          role_name: 'Member'
        }]);

      if (membershipError) {
        if (membershipError.code === '23505') {
          throw new Error('User is already a member of this organization');
        }
        throw membershipError;
      }

      await fetchOrganizations();
      setAddingMember(null);
      setAvailableUsers([]);
    } catch (error) {
      console.error('Error adding member:', error);
      setError(error instanceof Error ? error.message : 'Failed to add member');
    }
  };

  const formatDate = (date: string | null) => {
    if (!date) return 'Not set';
    return new Date(date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const filteredOrganizations = organizations.filter(org => 
    org.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    org.registration_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
    org.tax_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (org.email && org.email.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (org.address && org.address.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (org.phone && org.phone.toLowerCase().includes(searchTerm.toLowerCase()))
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
            <h2 className="text-xl sm:text-2xl font-semibold text-gray-900">Organizations</h2>
            <Building2 className="h-6 w-6 sm:h-8 sm:w-8 text-gray-400" />
          </div>
          
          <div className="relative">
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Search className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                placeholder="Search organizations..."
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
              <p className="text-gray-500">Loading organizations...</p>
            </div>
          ) : filteredOrganizations.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500">No organizations found</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {filteredOrganizations.map((org) => (
                <div key={org.id} className="bg-white shadow rounded-lg overflow-hidden">
                  <div className="px-4 py-5 sm:px-6 border-b border-gray-200">
                    {editingOrg?.id === org.id ? (
                      <input
                        type="text"
                        value={editingOrg.name}
                        onChange={(e) => setEditingOrg({ ...editingOrg, name: e.target.value })}
                        className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                        placeholder="Organization Name"
                      />
                    ) : (
                      <div className="flex justify-between items-start">
                        <div>
                          <h3 className="text-lg font-medium text-gray-900">{org.name}</h3>
                          <p className="mt-1 text-sm text-gray-500">
                            Reg: {org.registration_number}
                            <br />
                            Tax: {org.tax_number}
                          </p>
                        </div>
                        {!editingOrg && (
                          <button
                            onClick={() => handleEdit(org)}
                            className="ml-2 inline-flex items-center p-1.5 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                          >
                            <Edit2 className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="px-4 py-5 sm:px-6 space-y-4">
                    {editingOrg?.id === org.id ? (
                      <div className="space-y-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                          <input
                            type="email"
                            value={editingOrg.email || ''}
                            onChange={(e) => setEditingOrg({ ...editingOrg, email: e.target.value })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                            placeholder="Email"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Address</label>
                          <input
                            type="text"
                            value={editingOrg.address || ''}
                            onChange={(e) => setEditingOrg({ ...editingOrg, address: e.target.value })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                            placeholder="Address"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                          <input
                            type="text"
                            value={editingOrg.phone || ''}
                            onChange={(e) => setEditingOrg({ ...editingOrg, phone: e.target.value })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                            placeholder="Phone"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Subscription Plan</label>
                          <select
                            value={editingOrg.subscription_plan_id}
                            onChange={(e) => setEditingOrg({ ...editingOrg, subscription_plan_id: e.target.value })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                          >
                            {subscriptionPlans.map((plan) => (
                              <option key={plan.id} value={plan.id}>
                                {plan.name} - {new Intl.NumberFormat('en-US', {
                                  style: 'currency',
                                  currency: plan.currency,
                                  minimumFractionDigits: 0
                                }).format(plan.price / 100)}/mo
                              </option>
                            ))}
                          </select>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            Subscription Start Date
                          </label>
                          <input
                            type="datetime-local"
                            value={editingOrg.subscription_start_date ? new Date(editingOrg.subscription_start_date).toISOString().slice(0, 16) : ''}
                            onChange={(e) => setEditingOrg({ 
                              ...editingOrg, 
                              subscription_start_date: e.target.value ? new Date(e.target.value).toISOString() : null 
                            })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            Subscription End Date
                          </label>
                          <input
                            type="datetime-local"
                            value={editingOrg.subscription_end_date ? new Date(editingOrg.subscription_end_date).toISOString().slice(0, 16) : ''}
                            onChange={(e) => setEditingOrg({ 
                              ...editingOrg, 
                              subscription_end_date: e.target.value ? new Date(e.target.value).toISOString() : null 
                            })}
                            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                          />
                        </div>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {org.email && (
                          <div className="flex items-center text-sm">
                            <Mail className="h-4 w-4 text-gray-400 mr-2" />
                            <span>{org.email}</span>
                          </div>
                        )}
                        {org.address && (
                          <div className="flex items-center text-sm">
                            <MapPin className="h-4 w-4 text-gray-400 mr-2" />
                            <span>{org.address}</span>
                          </div>
                        )}
                        {org.phone && (
                          <div className="flex items-center text-sm">
                            <Phone className="h-4 w-4 text-gray-400 mr-2" />
                            <span>{org.phone}</span>
                          </div>
                        )}
                        <div className="flex items-center text-sm">
                          <CreditCard className="h-4 w-4 text-gray-400 mr-2" />
                          <span>
                            {org.subscription_plans.name} ({new Intl.NumberFormat('en-US', {
                              style: 'currency',
                              currency: org.subscription_plans.currency,
                              minimumFractionDigits: 0
                            }).format(org.subscription_plans.price / 100)}/mo)
                          </span>
                        </div>
                        <div className="flex items-center text-sm">
                          <Users className="h-4 w-4 text-gray-400 mr-2" />
                          <span className={org.member_count >= org.subscription_plans.max_users ? 'text-red-600' : 'text-green-600'}>
                            {org.member_count}/{org.subscription_plans.max_users} members
                          </span>
                        </div>
                        <div className="flex items-center text-sm">
                          <Calendar className="h-4 w-4 text-gray-400 mr-2" />
                          <div>
                            <p>
                              <span className="font-medium">Subscription Start:</span>{' '}
                              {formatDate(org.subscription_start_date)}
                            </p>
                            <p>
                              <span className="font-medium">Subscription End:</span>{' '}
                              {formatDate(org.subscription_end_date)}
                            </p>
                            {org.subscription_end_date && (
                              <p className={`mt-1 ${org.is_expired ? 'text-red-600' : 'text-green-600'}`}>
                                Status: {org.is_expired ? 'Expired' : 'Active'}
                              </p>
                            )}
                          </div>
                        </div>

                        {!org.is_default && (
                          <div className="flex items-center justify-between pt-4 border-t border-gray-200">
                            <span className="text-sm font-medium">Organization Status</span>
                            <button
                              onClick={() => handleToggleBlock(org.id, org.is_blocked)}
                              className={`inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium ${
                                org.is_blocked
                                  ? 'bg-red-100 text-red-800 hover:bg-red-200'
                                  : 'bg-green-100 text-green-800 hover:bg-green-200'
                              } transition-colors duration-200`}
                            >
                              {org.is_blocked ? 'Blocked' : 'Active'}
                            </button>
                          </div>
                        )}

                        {org.members && (
                          <div className="pt-4 border-t border-gray-200">
                            <div className="flex items-center justify-between mb-3">
                              <h4 className="text-sm font-medium text-gray-900">Members</h4>
                              {org.member_count < org.subscription_plans.max_users && (
                                <button
                                  onClick={() => handleAddMember(org.id)}
                                  className="inline-flex items-center px-2 py-1 text-xs font-medium text-indigo-600 hover:text-indigo-900"
                                >
                                  <UserPlus className="h-4 w-4 mr-1" />
                                  Add Member
                                </button>
                              )}
                            </div>
                            {addingMember?.organizationId === org.id ? (
                              <div className="mb-4 space-y-2">
                                <div className="relative">
                                  <input
                                    type="email"
                                    value={addingMember.email}
                                    onChange={(e) => setAddingMember({ ...addingMember, email: e.target.value })}
                                    placeholder="Search user by email"
                                    className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
                                  />
                                  {searchingUsers && (
                                    <div className="absolute right-3 top-2 text-gray-400">
                                      Searching...
                                    </div>
                                  )}
                                  {availableUsers.length > 0 && (
                                    <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
                                      {availableUsers.map((user) => (
                                        <button
                                          key={user.id}
                                          onClick={() => {
                                            setAddingMember({ ...addingMember, email: user.email });
                                            handleAddMemberSubmit(user.id);
                                          }}
                                          className="w-full px-4 py-2 text-left hover:bg-gray-50 flex flex-col"
                                        >
                                          <span className="font-medium">{user.full_name}</span>
                                          <span className="text-sm text-gray-500">{user.email}</span>
                                        </button>
                                      ))}
                                    </div>
                                  )}
                                </div>
                                <div className="flex justify-end space-x-2">
                                  <button
                                    onClick={() => {
                                      setAddingMember(null);
                                      setAvailableUsers([]);
                                    }}
                                    className="px-3 py-1 text-sm text-gray-600 hover:text-gray-900"
                                  >
                                    Cancel
                                  </button>
                                  <button
                                    onClick={() => handleAddMemberSubmit()}
                                    className="px-3 py-1 text-sm text-white bg-indigo-600 rounded hover:bg-indigo-700"
                                  >
                                    Add
                                  </button>
                                </div>
                              </div>
                            ) : (
                              <div className="space-y-2">
                                {org.members.map((member) => (
                                  <div key={member.id} className="flex items-center justify-between text-sm">
                                    <div>
                                      <span className="font-medium">
                                        {member.full_name || member.email?.split('@')[0]}
                                      </span>
                                      <span className="text-gray-500 ml-2">({member.role_name})</span>
                                    </div>
                                    {member.role_name !== 'Super-admin' && (
                                      <div className="flex items-center space-x-2">
                                        <button
                                          onClick={() => handleToggleMemberBlock(member.id, member.is_blocked)}
                                          className={`px-2 py-1 rounded text-xs font-medium ${
                                            member.is_blocked
                                              ? 'bg-red-100 text-red-800 hover:bg-red-200'
                                              : 'bg-green-100 text-green-800 hover:bg-green-200'
                                          } transition-colors duration-200`}
                                        >
                                          {member.is_blocked ? 'Blocked' : 'Active'}
                                        </button>
                                        <button
                                          onClick={() => handleRemoveMember(member.id)}
                                          className="p-1 text-gray-400 hover:text-red-600 transition-colors duration-200"
                                          title="Remove member"
                                        >
                                          <UserMinus className="h-4 w-4" />
                                        </button>
                                      </div>
                                    )}
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  {editingOrg?.id === org.id && (
                    <div className="px-4 py-4 sm:px-6 bg-gray-50 border-t border-gray-200">
                      <div className="flex justify-end space-x-3">
                        <button
                          onClick={() => setEditingOrg(null)}
                          className="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Cancel
                        </button>
                        <button onClick={handleSave}
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
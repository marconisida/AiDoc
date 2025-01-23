import React, { useState, useEffect } from 'react';
import { supabase, retryOperation } from '../lib/supabase';
import { User, MapPin, Globe, Phone, Calendar, Save, AlertCircle, CheckCircle, FileCheck, Briefcase, Flag, School, MessageSquare } from 'lucide-react';
import type { UserProfile as UserProfileType } from '../types';
import { SUPPORTED_COUNTRIES } from '../types';
import { useAuth } from '../hooks/useAuth';

interface Props {
  userId: string;
  onUpdate?: () => void;
}

export default function UserProfile({ userId, onUpdate }: Props) {
  const { session } = useAuth();
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [profile, setProfile] = useState<UserProfileType | null>(null);
  const isAgency = session?.user?.user_metadata?.role === 'agency';
  
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    country: '',
    preferred_language: '',
    whatsapp: '',
    birth_date: '',
    nationality_country: '',
    desired_residency_type: 'temporary_short',
    birth_country: '',
    primary_residency_country: '',
    residency_goal: 'tax_residency',
    marital_status: 'single',
    shipping_address: {
      street: '',
      city: '',
      state: '',
      country: '',
      postal_code: ''
    },
    internal_agency_notes: '',
    client_to_agency_notes: '',
    agency_to_client_notes: ''
  });

  useEffect(() => {
    loadProfile();
  }, [userId]);

  const loadProfile = async () => {
    setIsLoading(true);
    setError(null);
    
    try {
      const { data, error } = await retryOperation(() =>
        supabase.rpc('get_user_profile', {
          p_user_id: userId
        })
      );

      if (error) throw error;

      if (data && data.length > 0) {
        const userProfile = data[0];
        setProfile(userProfile);
        
        setFormData({
          first_name: userProfile.first_name ?? '',
          last_name: userProfile.last_name ?? '',
          country: userProfile.country ?? '',
          preferred_language: userProfile.preferred_language ?? '',
          whatsapp: userProfile.whatsapp ?? '',
          birth_date: userProfile.birth_date ?? '',
          nationality_country: userProfile.nationality_country ?? '',
          desired_residency_type: userProfile.desired_residency_type ?? 'temporary_short',
          birth_country: userProfile.birth_country ?? '',
          primary_residency_country: userProfile.primary_residency_country ?? '',
          residency_goal: userProfile.residency_goal ?? 'tax_residency',
          marital_status: userProfile.marital_status ?? 'single',
          shipping_address: userProfile.shipping_address ?? {
            street: '',
            city: '',
            state: '',
            country: '',
            postal_code: ''
          },
          internal_agency_notes: userProfile.internal_agency_notes ?? '',
          client_to_agency_notes: userProfile.client_to_agency_notes ?? '',
          agency_to_client_notes: userProfile.agency_to_client_notes ?? ''
        });
      }
    } catch (error) {
      console.error('Error loading profile:', error);
      setError('Error loading profile. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setError(null);
    setSuccess(null);

    try {
      const { data, error } = await retryOperation(() =>
        supabase.rpc('update_user_profile_v2', {
          p_user_id: userId,
          p_first_name: formData.first_name,
          p_last_name: formData.last_name,
          p_country: formData.country,
          p_preferred_language: formData.preferred_language,
          p_whatsapp: formData.whatsapp,
          p_birth_date: formData.birth_date,
          p_shipping_address: formData.shipping_address,
          p_nationality_country: formData.nationality_country,
          p_desired_residency_type: formData.desired_residency_type,
          p_birth_country: formData.birth_country,
          p_primary_residency_country: formData.primary_residency_country,
          p_residency_goal: formData.residency_goal,
          p_marital_status: formData.marital_status,
          p_internal_agency_notes: formData.internal_agency_notes,
          p_client_to_agency_notes: formData.client_to_agency_notes,
          p_agency_to_client_notes: formData.agency_to_client_notes
        })
      );

      if (error) throw error;

      setSuccess('Profile updated successfully');
      setProfile(data);
      onUpdate?.();
      
      if (data) {
        setFormData(prev => ({
          ...prev,
          first_name: data.first_name ?? prev.first_name,
          last_name: data.last_name ?? prev.last_name,
          country: data.country ?? prev.country,
          preferred_language: data.preferred_language ?? prev.preferred_language,
          whatsapp: data.whatsapp ?? prev.whatsapp,
          birth_date: data.birth_date ?? prev.birth_date,
          nationality_country: data.nationality_country ?? prev.nationality_country,
          desired_residency_type: data.desired_residency_type ?? prev.desired_residency_type,
          birth_country: data.birth_country ?? prev.birth_country,
          primary_residency_country: data.primary_residency_country ?? prev.primary_residency_country,
          residency_goal: data.residency_goal ?? prev.residency_goal,
          marital_status: data.marital_status ?? prev.marital_status,
          shipping_address: data.shipping_address ?? prev.shipping_address,
          internal_agency_notes: data.internal_agency_notes ?? prev.internal_agency_notes,
          client_to_agency_notes: data.client_to_agency_notes ?? prev.client_to_agency_notes,
          agency_to_client_notes: data.agency_to_client_notes ?? prev.agency_to_client_notes
        }));
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      setError('Error updating profile. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    
    if (name.startsWith('shipping_')) {
      const field = name.replace('shipping_', '');
      setFormData(prev => ({
        ...prev,
        shipping_address: {
          ...prev.shipping_address,
          [field]: value
        }
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [name]: value
      }));
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <h2 className="text-xl font-semibold text-gray-900 mb-6 flex items-center gap-2">
        <User className="h-6 w-6 text-blue-600" />
        User Profile
      </h2>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Personal Information */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <User className="h-5 w-5 text-blue-600" />
            Personal Information
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700">
                First Name
              </label>
              <input
                type="text"
                name="first_name"
                value={formData.first_name}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Last Name
              </label>
              <input
                type="text"
                name="last_name"
                value={formData.last_name}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>

        {/* Residency Information */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <Briefcase className="h-5 w-5 text-blue-600" />
            Residency Information
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 flex items-center gap-1">
                <Flag className="h-4 w-4" />
                Country of Nationality
              </label>
              <select
                name="nationality_country"
                value={formData.nationality_country}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select country</option>
                {SUPPORTED_COUNTRIES.map(country => (
                  <option key={country} value={country}>{country}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Desired Residency Type
              </label>
              <select
                name="desired_residency_type"
                value={formData.desired_residency_type}
                onChange={handleInputChange}
                required
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="temporary_short">Temporary Residency – 1 short trip ($2,600)</option>
                <option value="temporary_long">Temporary Residency – 2 short trips or 1 long ($1,900)</option>
                <option value="permanent_investment">Permanent Residency by Investment ($3,500)</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Country of Birth
              </label>
              <select
                name="birth_country"
                value={formData.birth_country}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select country</option>
                {SUPPORTED_COUNTRIES.map(country => (
                  <option key={country} value={country}>{country}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Primary Residency Country (last 3 years)
              </label>
              <select
                name="primary_residency_country"
                value={formData.primary_residency_country}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select country</option>
                {SUPPORTED_COUNTRIES.map(country => (
                  <option key={country} value={country}>{country}</option>
                ))}
              </select>
              <p className="mt-1 text-sm text-gray-500">
                If you don't have official residency, choose your nationality country
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Marital Status
              </label>
              <select
                name="marital_status"
                value={formData.marital_status}
                onChange={handleInputChange}
                required
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="single">Single</option>
                <option value="married">Married</option>
                <option value="divorced">Divorced</option>
                <option value="widowed">Widowed</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Residency Goal
              </label>
              <select
                name="residency_goal"
                value={formData.residency_goal}
                onChange={handleInputChange}
                required
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="tax_residency">Tax Residency</option>
                <option value="plan_b">Have a Plan B</option>
                <option value="relocation">Relocate to Paraguay</option>
              </select>
            </div>
          </div>
        </div>

        {/* Contact and Preferences */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <Phone className="h-5 w-5 text-blue-600" />
            Contact and Preferences
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 flex items-center gap-1">
                <Globe className="h-4 w-4" />
                Current Country of Residence
              </label>
              <select
                name="country"
                value={formData.country}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select country</option>
                {SUPPORTED_COUNTRIES.map(country => (
                  <option key={country} value={country}>{country}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Preferred Language
              </label>
              <select
                name="preferred_language"
                value={formData.preferred_language}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select language</option>
                <option value="es">Spanish</option>
                <option value="en">English</option>
                <option value="pt">Portuguese</option>
                <option value="it">Italian</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 flex items-center gap-1">
                <Phone className="h-4 w-4" />
                WhatsApp
              </label>
              <input
                type="tel"
                name="whatsapp"
                value={formData.whatsapp}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 flex items-center gap-1">
                <Calendar className="h-4 w-4" />
                Date of Birth
              </label>
              <input
                type="date"
                name="birth_date"
                value={formData.birth_date}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>

        {/* Shipping Address */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <MapPin className="h-5 w-5 text-blue-600" />
            Shipping Address
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700">
                Street Address
              </label>
              <input
                type="text"
                name="shipping_street"
                value={formData.shipping_address.street}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                City
              </label>
              <input
                type="text"
                name="shipping_city"
                value={formData.shipping_address.city}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                State/Province
              </label>
              <input
                type="text"
                name="shipping_state"
                value={formData.shipping_address.state}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Country
              </label>
              <select
                name="shipping_country"
                value={formData.shipping_address.country}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select country</option>
                {SUPPORTED_COUNTRIES.map(country => (
                  <option key={country} value={country}>{country}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Postal Code
              </label>
              <input
                type="text"
                name="shipping_postal_code"
                value={formData.shipping_address.postal_code}
                onChange={handleInputChange}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>

        {/* Required Documents Section */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <FileCheck className="h-5 w-5 text-blue-600" />
            Required Documents
          </h3>

          <div className="space-y-4">
            {/* Birth Certificate */}
            {formData.birth_country && (
              <div className="p-4 bg-blue-50 rounded-lg">
                <h4 className="font-medium text-blue-900">Birth Certificate</h4>
                <p className="text-blue-700">
                  Birth certificate from {formData.birth_country} with apostille
                </p>
              </div>
            )}

            {/* Criminal Records */}
            {formData.primary_residency_country && (
              <div className="p-4 bg-blue-50 rounded-lg">
                <h4 className="font-medium text-blue-900">Criminal Records</h4>
                <p className="text-blue-700">
                  Criminal record certificate from {formData.primary_residency_country}
                  {formData.birth_country !== formData.primary_residency_country && 
                    ` or from ${formData.birth_country} if address not included`}
                </p>
              </div>
            )}

            {/* Marriage Certificate */}
            {formData.marital_status === 'married' && (
              <div className="p-4 bg-blue-50 rounded-lg">
                <h4 className="font-medium text-blue-900">Marriage Certificate</h4>
                <p className="text-blue-700">
                  Marriage certificate with apostille
                </p>
              </div>
            )}

            {/* Citizenship Certificate */}
            {formData.birth_country !== formData.nationality_country && (
              <div className="p-4 bg-blue-50 rounded-lg">
                <h4 className="font-medium text-blue-900">Citizenship Certificate</h4>
                <p className="text-blue-700">
                  Citizenship or naturalization certificate with apostille
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Notes Section */}
        <div className="border-t pt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <MessageSquare className="h-5 w-5 text-blue-600" />
            Communication
          </h3>

          <div className="space-y-4">
            {/* Client to Agency Notes */}
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Message to Agency
              </label>
              <textarea
                name="client_to_agency_notes"
                value={formData.client_to_agency_notes}
                onChange={handleInputChange}
                rows={3}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            {/* Agency to Client Notes */}
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Message from Agency
              </label>
              <textarea
                name="agency_to_client_notes"
                value={formData.agency_to_client_notes}
                onChange={handleInputChange}
                rows={3}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                readOnly={!isAgency}
              />
            </div>

            {/* Internal Agency Notes - Only visible to agency */}
            {isAgency && (
              <div className="bg-yellow-50 p-4 rounded-lg border border-yellow-200">
                <label className="block text-sm font-medium text-yellow-800">
                  Internal Agency Notes (Only visible to agency)
                </label>
                <textarea
                  name="internal_agency_notes"
                  value={formData.internal_agency_notes}
                  onChange={handleInputChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-yellow-300 bg-white shadow-sm focus:border-yellow-500 focus:ring-yellow-500 sm:text-sm"
                />
              </div>
            )}
          </div>
        </div>

        {error && (
          <div className="bg-red-50 text-red-700 p-4 rounded-lg text-sm flex items-center gap-2">
            <AlertCircle className="h-5 w-5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="bg-green-50 text-green-700 p-4 rounded-lg text-sm flex items-center gap-2">
            <CheckCircle className="h-5 w-5 flex-shrink-0" />
            <span>{success}</span>
          </div>
        )}

        <div className="flex justify-end">
          <button
            type="submit"
            disabled={isSaving}
            className={`inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white 
              ${isSaving 
                ? 'bg-gray-400 cursor-not-allowed' 
                : 'bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500'
              }`}
          >
            <Save className="h-4 w-4 mr-2" />
            {isSaving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </form>
    </div>
  );
}
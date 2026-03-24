import { SupabaseClient, Session, User } from '@supabase/supabase-js';
import { Profile } from '../types/index.js';

export class AuthModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async signUp(email: string, password: string, fullName: string): Promise<User> {
    const { data, error } = await this.supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName } },
    });
    if (error) throw error;
    return data.user!;
  }

  async signIn(email: string, password: string): Promise<Session> {
    const { data, error } = await this.supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
    return data.session!;
  }

  async signOut(): Promise<void> {
    const { error } = await this.supabase.auth.signOut();
    if (error) throw error;
  }

  async getProfile(): Promise<Profile> {
    const { data: { user } } = await this.supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');
    const { data, error } = await this.supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();
    if (error) throw error;
    return data as Profile;
  }

  async updateProfile(updates: Partial<Pick<Profile, 'full_name' | 'avatar_url' | 'phone'>>): Promise<Profile> {
    const { data: { user } } = await this.supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');
    const { data, error } = await this.supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();
    if (error) throw error;
    return data as Profile;
  }
}

"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/lib/supabase";

export default function Page() {
  const [user, setUser] = useState<any>(null);

  // 1. Fetch user data on mount and listen for changes
  useEffect(() => {

    const fetchUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      setUser(user);
    };
    fetchUser();

    // Listen for auth state changes (e.g., sign in/out)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  async function handleSignIn() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/`,
      },
    });
    if (error) console.error('Error:', error.message);
  }

  async function handleSignOut() {
    await supabase.auth.signOut();
    setUser(null);
  }

  return (
    <div className="p-8">
      {user ? (
        <div className="space-y-4">
          <h1 className="text-xl font-bold">Welcome, {user.email}!</h1>
          <div className="bg-gray-100 p-4 rounded-md">
            <h2 className="font-semibold mb-2">Your Raw Data:</h2>
            <pre className="text-xs overflow-auto max-h-60">
              {JSON.stringify(user, null, 2)}
            </pre>
          </div>
          <Button variant="destructive" onClick={handleSignOut}>Sign Out</Button>
        </div>
      ) : (
        <Button onClick={handleSignIn}>Sign In with Google</Button>
      )}
    </div>
  );
}

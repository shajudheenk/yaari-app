import { useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from './lib/supabase';
import Login from './pages/Login';
import Layout from './components/Layout';
import Compliance from './pages/Compliance';
import Queue from './pages/Queue';
import Incidents from './pages/Incidents';

export type Tab = 'compliance' | 'queue' | 'incidents';

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [checking, setChecking] = useState(true);
  const [tab, setTab] = useState<Tab>('compliance');

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setChecking(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  if (checking) return <div className="loading">Checking session…</div>;
  if (!session) return <Login />;

  return (
    <Layout tab={tab} onTab={setTab} email={session.user.email ?? ''}>
      {tab === 'compliance' && <Compliance />}
      {tab === 'queue' && <Queue />}
      {tab === 'incidents' && <Incidents />}
    </Layout>
  );
}

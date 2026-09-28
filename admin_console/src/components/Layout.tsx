import { useEffect, useState, type ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import type { Tab } from '../App';

type Props = {
  tab: Tab;
  onTab: (t: Tab) => void;
  email: string;
  children: ReactNode;
};

export default function Layout({ tab, onTab, email, children }: Props) {
  const [blocked, setBlocked] = useState<number | null>(null);
  const [pending, setPending] = useState<number | null>(null);
  const [openIncidents, setOpenIncidents] = useState<number | null>(null);

  useEffect(() => {
    let live = true;

    async function counts() {
      const [board, docs, inc] = await Promise.all([
        supabase.from('provider_compliance_board').select('is_compliant,status'),
        supabase.from('provider_documents').select('id').eq('status', 'pending'),
        supabase.from('incidents').select('id').in('status', ['open', 'investigating']),
      ]);
      if (!live) return;
      const rows = board.data ?? [];
      setBlocked(rows.filter((r) => !r.is_compliant && r.status === 'approved').length);
      setPending(docs.data?.length ?? 0);
      setOpenIncidents(inc.data?.length ?? 0);
    }

    counts();
    const t = setInterval(counts, 20000);
    return () => {
      live = false;
      clearInterval(t);
    };
  }, [tab]);

  const item = (id: Tab, label: string, count: number | null, urgent = false) => (
    <a
      className={`navlink ${tab === id ? 'on' : ''}`}
      onClick={() => onTab(id)}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && onTab(id)}
    >
      <span>{label}</span>
      {count !== null && count > 0 && (
        <span className={`count ${urgent ? '' : 'quiet'}`}>{count}</span>
      )}
    </a>
  );

  return (
    <div className="shell">
      <nav className="side">
        <div className="brand">
          <div className="mk">Y</div>
          <div>
            <div className="nm">Yaari</div>
            <div className="sb">TRUST &amp; SAFETY</div>
          </div>
        </div>

        {item('compliance', 'Compliance', blocked, true)}
        {item('queue', 'Verification queue', pending)}
        {item('incidents', 'Incidents', openIncidents, true)}


        <div className="foot">
          <div className="who">{email}</div>
          <button onClick={() => supabase.auth.signOut()}>Sign out</button>
        </div>
      </nav>

      <main className="main">{children}</main>
    </div>
  );
}

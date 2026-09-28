import { useEffect, useState } from 'react';
import {
  supabase, asArray, DOC_LABEL,
  type ComplianceRow, type ExpiringRow, type DocType,
} from '../lib/supabase';

export default function Compliance() {
  const [rows, setRows] = useState<ComplianceRow[] | null>(null);
  const [expiring, setExpiring] = useState<ExpiringRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let live = true;
    (async () => {
      const [board, exp] = await Promise.all([
        supabase.from('provider_compliance_board').select('*'),
        supabase.from('expiring_documents').select('*'),
      ]);
      if (!live) return;
      if (board.error) setError(board.error.message);
      setRows((board.data as ComplianceRow[]) ?? []);
      setExpiring((exp.data as ExpiringRow[]) ?? []);
    })();
    return () => { live = false; };
  }, []);

  if (error) return <div className="alert bad">{error}</div>;
  if (!rows) return <div className="loading">Loading compliance board…</div>;

  const approved = rows.filter((r) => r.status === 'approved');
  const bookable = approved.filter((r) => r.is_compliant && r.is_online);
  const blocked = approved.filter((r) => !r.is_compliant);
  const soon = (expiring ?? []).filter((e) => e.days_left >= 0 && e.days_left <= 30);
  const awaiting = rows.filter((r) => r.status === 'applied' || r.status === 'in_review');

  // blocked first, then by how soon they lose a credential
  const ordered = [...rows].sort((a, b) => {
    if (a.is_compliant !== b.is_compliant) return a.is_compliant ? 1 : -1;
    const av = a.days_to_next_expiry ?? 99999;
    const bv = b.days_to_next_expiry ?? 99999;
    return av - bv;
  });

  return (
    <>
      <div className="head">
        <h1>Compliance</h1>
        <p>
          A provider can only be offered work while every credential their trade
          requires is verified and unexpired. This is enforced in the database at
          query time, so a lapse removes them from search immediately — no nightly
          job, no manual review.
        </p>
      </div>

      <div className="tiles">
        <div className="tile ok">
          <div className="v">{bookable.length}</div>
          <div className="k">Bookable now</div>
          <div className="sub">Approved, online and compliant</div>
        </div>
        <div className="tile bad">
          <div className="v">{blocked.length}</div>
          <div className="k">Blocked</div>
          <div className="sub">Approved but missing a credential</div>
        </div>
        <div className="tile warn">
          <div className="v">{soon.length}</div>
          <div className="k">Expiring ≤ 30 days</div>
          <div className="sub">Chase before they stop working</div>
        </div>
        <div className="tile">
          <div className="v">{awaiting.length}</div>
          <div className="k">Awaiting verification</div>
          <div className="sub">New applications</div>
        </div>
      </div>

      <section className="panel">
        <header>
          <h2>Providers</h2>
          <span className="note">Blocked shown first, then soonest expiry</span>
        </header>
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Provider</th>
                <th>Trade</th>
                <th>Status</th>
                <th>Availability</th>
                <th>Can take work</th>
                <th>Next credential expiry</th>
                <th className="num">Jobs</th>
              </tr>
            </thead>
            <tbody>
              {ordered.map((r) => {
                const missing = asArray(r.missing_docs) as DocType[];
                const isBlocked = r.status === 'approved' && !r.is_compliant;
                return (
                  <tr key={r.provider_id} className={isBlocked ? 'blocked' : ''}>
                    <td className="who-cell">
                      <div className="n">{r.full_name ?? '—'}</div>
                      <div className="m mono">{r.phone}</div>
                    </td>
                    <td>{r.trade ?? '—'}</td>
                    <td><StatusChip status={r.status} /></td>
                    <td>
                      <span className={`chip ${r.is_online ? 'slate' : 'mute'}`}>
                        <span className="dot" />{r.is_online ? 'Online' : 'Offline'}
                      </span>
                    </td>
                    <td>
                      {r.is_compliant ? (
                        <span className="chip ok">Yes</span>
                      ) : (
                        <div>
                          <span className="chip bad">No</span>
                          {missing.length > 0 && (
                            <div className="why">
                              Missing: {missing.map((d) => DOC_LABEL[d] ?? d).join(', ')}
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                    <td><Expiry days={r.days_to_next_expiry} on={r.next_expiry} /></td>
                    <td className="num">{r.jobs_completed}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel">
        <header>
          <h2>Credentials expiring or lapsed</h2>
          <span className="note">Next 30 days</span>
        </header>
        {expiring && expiring.length > 0 ? (
          <table>
            <thead>
              <tr>
                <th>Provider</th>
                <th>Credential</th>
                <th>Reference</th>
                <th>Expires</th>
                <th>Countdown</th>
              </tr>
            </thead>
            <tbody>
              {expiring.map((e) => (
                <tr key={e.id} className={e.days_left < 0 ? 'blocked' : ''}>
                  <td className="who-cell">
                    <div className="n">{e.full_name ?? '—'}</div>
                    <div className="m mono">{e.phone}</div>
                  </td>
                  <td>{DOC_LABEL[e.doc_type] ?? e.doc_type}</td>
                  <td className="mono" style={{ fontSize: 12 }}>{e.reference ?? '—'}</td>
                  <td className="mono" style={{ fontSize: 12.5 }}>{e.expires_on}</td>
                  <td><Expiry days={e.days_left} on={e.expires_on} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <div className="empty">Nothing expiring in the next 30 days.</div>
        )}
      </section>
    </>
  );
}

function StatusChip({ status }: { status: ComplianceRow['status'] }) {
  const map: Record<string, string> = {
    approved: 'ok', applied: 'mute', in_review: 'warn',
    suspended: 'bad', rejected: 'bad',
  };
  const label = status.replace('_', ' ');
  return <span className={`chip ${map[status] ?? 'mute'}`}>{label}</span>;
}

function Expiry({ days, on }: { days: number | null; on: string | null }) {
  if (days === null || on === null) return <span className="chip mute">No expiry</span>;
  if (days < 0) return <span className="chip bad">Lapsed {Math.abs(days)}d ago</span>;
  if (days <= 14) return <span className="chip bad">{days}d left</span>;
  if (days <= 30) return <span className="chip warn">{days}d left</span>;
  return <span className="hint mono">{on}</span>;
}

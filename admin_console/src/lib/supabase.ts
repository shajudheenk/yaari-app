import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;

if (!url || !key) {
  throw new Error(
    'Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY. Copy .env.example to .env at the repo root.',
  );
}

export const supabase = createClient(url, key, {
  auth: { persistSession: true, autoRefreshToken: true },
});

// ---------- row shapes ----------

export type DocType =
  | 'photo_id'
  | 'right_to_work'
  | 'public_liability_insurance'
  | 'gas_safe'
  | 'part_p'
  | 'dbs_basic'
  | 'trade_qualification';

export const DOC_LABEL: Record<DocType, string> = {
  photo_id: 'Photo ID',
  right_to_work: 'Right to work',
  public_liability_insurance: 'Public liability',
  gas_safe: 'Gas Safe',
  part_p: 'Part P',
  dbs_basic: 'Basic DBS',
  trade_qualification: 'Trade qualification',
};

export type ComplianceRow = {
  provider_id: string;
  full_name: string | null;
  phone: string;
  trade: string | null;
  status: 'applied' | 'in_review' | 'approved' | 'suspended' | 'rejected';
  is_online: boolean;
  is_compliant: boolean;
  missing_docs: DocType[] | null;
  next_expiry: string | null;
  days_to_next_expiry: number | null;
  jobs_completed: number;
  rating_avg: number | null;
};

export type ExpiringRow = {
  id: string;
  provider_id: string;
  full_name: string | null;
  phone: string;
  doc_type: DocType;
  reference: string | null;
  expires_on: string;
  days_left: number;
  status: string;
};

export type ProviderDocument = {
  id: string;
  provider_id: string;
  doc_type: DocType;
  reference: string | null;
  issued_on: string | null;
  expires_on: string | null;
  status: 'pending' | 'verified' | 'rejected' | 'expired';
  verified_at: string | null;
  rejection_reason: string | null;
  created_at: string;
};

export type Incident = {
  id: string;
  ref: string;
  booking_id: string | null;
  kind: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'open' | 'investigating' | 'resolved' | 'closed';
  description: string | null;
  created_at: string;
  acknowledged_at: string | null;
  resolved_at: string | null;
};

export type ComplianceEvent = {
  id: number;
  provider_id: string;
  action: string;
  actor_label: string | null;
  detail: Record<string, unknown>;
  created_at: string;
};

/**
 * Postgres returns arrays as a literal like `{a,b}` over some paths.
 * Normalise so the UI never has to care.
 */
export function asArray(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[];
  if (typeof value === 'string') {
    const inner = value.replace(/^\{|\}$/g, '').trim();
    return inner ? inner.split(',').map((s) => s.trim()) : [];
  }
  return [];
}

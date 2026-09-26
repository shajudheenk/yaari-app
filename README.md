# Yaari — UK home services marketplace

Birmingham MVP. Two mobile apps (customer, provider) and a Trust & Safety
console, on a Supabase backend.

> **Name is not final.** `yaari` appears in the Supabase project name and will
> appear in bundle identifiers. Renaming is nearly free today and expensive
> once the apps are submitted to either store — decide before first submission.

## The idea in one paragraph

Every safety credential in this trade expires: public liability insurance
renews annually, Gas Safe registration renews annually, DBS certificates go
stale. UK competitors verify once at sign-up and never look again, so a
tradesperson whose insurance lapsed eight months ago still shows as "verified".
Here, **the right to receive work is gated in real time on documents being
valid today**. Insurance lapses at midnight, the provider stops receiving jobs
at midnight — automatically, with no cron job and no manual review.

## Layout

```
supabase/          database migrations (source of truth lives in the project)
admin_console/     React + Vite — the Trust & Safety console
customer_app/      Flutter (iOS + Android)      [pending Flutter SDK]
provider_app/      Flutter (iOS + Android)      [pending Flutter SDK]
packages/          shared Flutter UI package    [pending Flutter SDK]
docs/              specification and screen PDFs
```

## Backend

| | |
|---|---|
| Project | `capnsntuwdhxrxjfhrgr` |
| Region | `eu-west-2` (London) — UK data residency |
| Cost | £0/month, free tier |

### How the compliance gate works

`nearby_providers()` is the only non-CRUD query in the system. It returns a
provider only when **all** of these hold at the moment of the query:

- provider status is `approved`
- the provider has toggled themselves `is_online`
- the account is not blocked
- `provider_is_compliant()` — every credential their trade mandates is
  `verified` and not past `expires_on`
- they are within range, by PostGIS `ST_DWithin`

Credential requirements are per trade, in `trade_required_docs`. Everyone needs
identity, right to work and public liability. Electricians additionally need
Part P; gas engineers need Gas Safe (legally required for gas work in the UK);
cleaners and handymen need a basic DBS.

> **On DBS:** only *basic* checks are claimed anywhere in this system. Enhanced
> DBS eligibility is restricted by statute and general home-services work very
> likely does not qualify. Do not advertise enhanced checks without confirming
> eligibility with an umbrella body first.

### Seeded demo state

Seven providers exist so the gate is demonstrable rather than theoretical:

| Provider | Trade | State | Appears in search? |
|---|---|---|---|
| Rahul Krishnan | Electrician | fully compliant | yes |
| Dan Adeyemi | Electrician | fully compliant | yes |
| Sam Novak | Plumber | fully compliant | yes |
| Priya Mistry | Cleaner | compliant, incl. basic DBS | yes |
| Aisha Rahman | Gas engineer | compliant, Gas Safe expires in 12 days | yes, and flagged on the expiry board |
| **Tom Baxter** | Electrician | approved + online, **insurance lapsed yesterday** | **no — blocked by the gate** |
| **Mo Karim** | Plumber | applied, documents unverified | **no — not approved** |

Phone numbers use Ofcom's reserved `07700 900xxx` drama range, so none of them
can ring a real person.

### Verifying the gate

```sql
-- 6 providers are approved and online, but only 2 electricians are bookable
select count(*) from nearby_providers('electrician', -1.9385, 52.4409, 12000);

-- and the console can say exactly why
select full_name, is_compliant, missing_docs, days_to_next_expiry
from provider_compliance_board order by is_compliant;
```

## Security posture

- Row level security on every table.
- `otp_codes` has an explicit deny-all policy: no client can read or write it,
  only edge functions holding the service role.
- Credential documents live in a **private** storage bucket readable only by
  the owning provider and staff. A customer can see the compliance *badge* but
  can never fetch someone's passport or DBS scan.
- Provider home coordinates are never returned to clients. Discovery returns a
  distance in metres only — exposing a lone worker's home address would be a
  safety failure in itself.
- `booking_events` and `compliance_events` are append-only audit trails.

The database linter reports no errors. It still warns that several
`SECURITY DEFINER` functions are executable — that is by design: `is_admin()`
and `shares_booking_with()` are called *inside* RLS policies, so the querying
role must be able to execute them, and they only reveal facts about the caller.

## Getting set up

```bash
cp .env.example .env   # then paste the real values
cd admin_console && npm install && npm run dev
```

The service role key is deliberately absent from this repo. It bypasses RLS
entirely and belongs only in Supabase edge function secrets.

# Real-Time Sync Checklist — Akhiyan

**Goal:** every change in any client (Flutter admin app, ecommerce
storefront, or web admin dashboard) reflects in every other client within
~1 second, without a manual refresh.

This doc is a handoff to the **backend** and **storefront** developers.
The Flutter side is already fully wired — no app changes needed once the
backend pieces below are in place.

---

## Architecture (already in place)

```
                ┌────────────── Backend (Next.js, Vercel) ──────────────┐
                │                                                        │
   Mutation ───►│   POST/PATCH/DELETE /api/v1/m/<resource>               │
   (any client) │              │                                         │
                │              ▼                                         │
                │           DB write                                     │
                │              │                                         │
                │              ▼                                         │
                │      bumpVersion('<channel>', notify?)                 │
                │              │                                         │
                │              ▼                                         │
                │   ┌──────────────────────────────────────┐             │
                │   │  GET /api/v1/m/sync/stream  (SSE)    │             │
                │   └──────────────────────────────────────┘             │
                │       │           │             │                       │
                └───────┼───────────┼─────────────┼───────────────────────┘
                        ▼           ▼             ▼
                   Flutter app  Web admin    Storefront
                   (refetch)    (refetch)    (refetch)
```

The pattern: **mutation → bump → SSE push → every connected client
invalidates its cache and refetches.** If any step is missing for a given
resource, that resource won't be real-time bidirectionally.

---

## Backend tasks (Next.js API)

### 1. Every admin write route must call `bumpVersion(channel)` after a successful DB write

The helper is already in `src/lib/sync.ts`. Every `POST`, `PATCH`,
`PUT`, `DELETE` route under `/api/v1/m/*` (mobile namespace) and
`/api/v1/admin/*` (web namespace) needs one line after the DB call:

```ts
// Example: PATCH /api/v1/m/staff/:id
const updated = await db.staff.update(...);
await bumpVersion('staff', {
  kind: 'staff_updated',
  title: 'Staff updated',
  body: `${updated.name} was updated`,
});
return ok({ data: updated });
```

**Audit checklist** — for each resource, confirm both web-admin and mobile
routes bump after every write:

| Channel | Routes to verify |
|---|---|
| `products` | `POST/PATCH/DELETE /api/v1/m/products`, same on `/admin/products` |
| `orders` | `POST/PATCH/DELETE /api/v1/m/orders`, status updates, courier assignment |
| `customers` | Customer create/update/delete (when added) |
| `staff` | `POST/PATCH/DELETE /api/v1/m/staff` |
| `categories` | Create/update/delete |
| `brands` | Create/update/delete |
| `coupons` | Create/update/delete/toggle-active |
| `flash-sales` | Create/update/delete/start/stop |
| `banners` | Create/update/delete/reorder |
| `menus` | Create/update/delete/reorder |
| `reviews` | Create/update/delete/approve |
| `theme` | Customizer save (any `theme.*` setting change) |
| `settings` | Non-theme settings (courier API keys, payment, shipping) |
| `shortlinks` | Create/update/delete |
| `notifications` | Send / mark-read |

> **Tip:** grep the API folder for routes that mutate the DB but don't call
> `bumpVersion`. Every one is a real-time gap.

### 2. SSE endpoint must run on Vercel Edge Runtime (or a long-lived host)

Vercel **serverless functions time out at 10s (Hobby) / 60s (Pro)** —
fatal for SSE which needs to live for hours.

In `src/app/api/v1/m/sync/stream/route.ts`:

```ts
export const runtime = 'edge'; // ← required for long-lived SSE
export const dynamic = 'force-dynamic';
```

Edge Runtime has no execution timeout for streamed responses. If you
can't use Edge (e.g. you need Node-only deps), move the SSE endpoint to
a small dedicated service (Fly.io, Railway, or a separate Vercel project
on Pro+ with `maxDuration: 300`).

### 3. Heartbeat every 25s to keep proxies alive

Already in place — confirm it's still firing. The Flutter client has a
60s silence watchdog that force-reconnects if it stops hearing pings.
Standard SSE comment frame:

```ts
controller.enqueue(encoder.encode(': ping\n\n'));
```

### 4. Authenticate the SSE connection

Already done — `getSessionUser()` reads cookie OR `Authorization: Bearer`
header. Mobile uses bearer; web uses cookie. Don't break this.

### 5. Per-tenant scoping (forward-compat for SaaS)

When the SaaS multi-tenant migration lands, the bump payload should
include the tenant slug, and the SSE endpoint should filter events by
the connecting user's tenant. Until then this is a no-op.

---

## Storefront tasks (ecommerce website)

### 1. SSE consumer at app boot

Open one connection to `/api/v1/sync/stream` for the lifetime of the
session. Browser-native `EventSource` works:

```ts
const es = new EventSource('/api/v1/sync/stream', {
  withCredentials: true, // sends the auth cookie
});

es.addEventListener('message', (evt) => {
  const { channel, version, notify } = JSON.parse(evt.data);
  store.applyBump(channel, version, notify);
});

es.addEventListener('error', () => {
  // Browser auto-reconnects; the server can advise a retry interval
  // via the `retry:` SSE field.
});
```

Mount this once at the top of the React tree (e.g. a `<SyncProvider>`
context, or in a Zustand/Redux slice) so a single connection serves the
whole app.

### 2. Per-channel cache invalidation

When a bump arrives, invalidate the relevant data cache. Pattern depends
on your data layer:

**React Query / TanStack Query:**
```ts
function applyBump(channel: string) {
  switch (channel) {
    case 'products':
      queryClient.invalidateQueries({ queryKey: ['products'] });
      queryClient.invalidateQueries({ queryKey: ['categories'] });
      break;
    case 'theme':
      queryClient.invalidateQueries({ queryKey: ['theme'] });
      break;
    case 'banners':
      queryClient.invalidateQueries({ queryKey: ['banners'] });
      break;
    // …one case per channel the storefront cares about
  }
}
```

**SWR:**
```ts
import { mutate } from 'swr';
mutate('/api/v1/products');
```

**Next.js App Router with server components:**
You can't directly invalidate server data, but you can call
`router.refresh()` from a client component to re-run the server fetch:

```ts
'use client';
const router = useRouter();
useEffect(() => {
  // listen to SSE
  return () => router.refresh();
}, []);
```

### 3. Channels the storefront should listen to

| Channel | Why the storefront cares |
|---|---|
| `products` | Stock changes, new arrivals, price updates |
| `categories` | Menu rendering |
| `brands` | Brand pages |
| `banners` | Hero carousel |
| `menus` | Header navigation |
| `coupons` | Coupon code validation, promo banners |
| `flash-sales` | Live sale countdowns, price overrides |
| `theme` | Brand color, fonts, logo (already wired in Flutter — same pattern) |
| `settings` | Currency, shipping, contact info |
| `reviews` | PDP rating refresh |

`orders`, `customers`, `staff`, `notifications` — backend admin only;
storefront usually doesn't need these unless you have a customer
self-service area.

---

## Flutter app status

**Already done. No changes needed once the backend is bumping correctly.**

For reference:
- SSE consumer: [lib/src/core/sync/sync_client.dart](lib/src/core/sync/sync_client.dart) — auto-reconnects with exponential backoff, 60s silence watchdog.
- Per-channel refresh: [lib/src/core/sync/sync_invalidation.dart](lib/src/core/sync/sync_invalidation.dart) — switch statement maps channel name to provider invalidation. Add a `case` here when you wire a new resource.
- Live theme: [lib/src/core/theme/live_theme.dart](lib/src/core/theme/live_theme.dart) — refetches on `theme` channel bumps.
- Notifications: [lib/src/features/notifications/](lib/src/features/notifications/) — pushes the `notify` metadata to the in-app bell + panel.

---

## Acceptance test (run this end-to-end before declaring done)

For each channel below, perform the round-trip and confirm both other
clients update within ~1 second:

- [ ] **Edit a product on web admin** → Flutter products list and storefront PDP both refresh.
- [ ] **Update a staff member in Flutter** → web admin Staff page and storefront (if it shows staff anywhere) refresh.
- [ ] **Toggle a coupon active on web admin** → storefront coupon-code validation immediately reflects the new state.
- [ ] **Change brand primary color in customizer** → Flutter app theme + storefront theme repaint without reload.
- [ ] **Place an order on storefront** → Flutter orders list shows the new order; dashboard counters bump.
- [ ] **Update banner order on web admin** → storefront hero carousel re-renders.
- [ ] **Disconnect Flutter from network for 30s, reconnect** → SSE auto-reconnects, missed bumps catch up via the connection snapshot.

If any item fails, the failure is in one of these three places:
1. Backend route doesn't call `bumpVersion` after the DB write.
2. SSE endpoint dropped the event (check Edge Runtime / timeout settings).
3. Client doesn't have an invalidation handler for that channel.

---

## Adjacent backend ask: order statuses endpoint

> The Flutter Orders screen has filter chips at the top (All / Pending /
> Confirmed / …). Today they fall back to a hardcoded list because no
> backend route exposes the canonical set — the web admin appears to
> read its own copy. This route makes both clients agree.

### Contract Flutter expects

```
GET /api/v1/m/orders/statuses
Authorization: Bearer <access token>

200 OK
{
  "data": [
    { "key": "pending",      "label": "Pending" },
    { "key": "processing",   "label": "Processing" },
    { "key": "on_hold",      "label": "On Hold" },
    { "key": "confirmed",    "label": "Confirmed" },
    { "key": "courier_sent", "label": "Courier Sent" },
    { "key": "shipped",      "label": "Shipped" },
    { "key": "delivered",    "label": "Delivered" },
    { "key": "cancelled",    "label": "Cancelled" }
  ]
}
```

`key` is the stable slug stored on `Order.status`. `label` is the
human string. Optional `color` field (hex) is accepted by the model
if you ever want admin-customizable chip / badge tints — Flutter just
ignores it today.

### Why this matters

- Adding a new status (e.g. `returned`) on the backend instantly shows
  up as a filter chip in the Flutter app — no app release.
- The web admin and Flutter agree on the canonical set; no drift.
- The order create form's status dropdown (when added later) reads the
  same source.

The set should match the same enum / table the web admin uses to
populate its own status filter. If the web admin reads from a backend
constant, expose that constant via this route. If it reads from a
DB-stored config, return the rows.

---

## Adjacent backend ask: order creation endpoint

> The Flutter app has a working order-creation form (manual entry for
> phone-in / WhatsApp / in-store orders). It posts to the route below.
> Until this ships, tapping **Create Order** surfaces a friendly 404
> snackbar and the form stays interactive.

### Contract Flutter expects

```
POST /api/v1/m/orders
Authorization: Bearer <access token>
Content-Type: application/json

{
  "customerName":    "Ilhaan Siddique",
  "customerPhone":   "01731492117",
  "customerEmail":   "ilhaan@example.com",   // optional
  "customerAddress": "House 5, Road 2, Dhaka",
  "city":            "Dhaka",                // optional
  "zipCode":         "1207",                 // optional
  "items": [
    { "productId": "abc-123", "quantity": 2, "price": 410 }
  ],
  "shippingCost":  60,
  "discount":      0,
  "paymentMethod": "cod",                    // cod | bkash | nagad | card
  "notes":         "Deliver after 6 PM"      // optional
}

200 OK
{ "data": <full Order object, same shape as GET /orders/:id> }
```

### What the backend route should do

1. **Validate stock** for each `productId` (and `variantId` if you add
   variants later). Reject with 409 if any line is oversold.
2. **Compute totals server-side** — don't trust client `subtotal` /
   `total`. Subtotal = sum(items[i].price × quantity). Total = subtotal
   + shippingCost − discount.
3. **Insert** the order + line items in one transaction.
4. **Decrement stock** atomically with the insert.
5. **Bump `orders` channel** so Flutter, web admin, and storefront
   refresh:
   ```ts
   await bumpVersion('orders', {
     kind: 'order_created',
     title: 'New manual order',
     body: `${order.customerName} • ৳${order.total}`,
   });
   ```
6. **Return** the full Order object (matches `GET /orders/:id` shape) so
   the Flutter form can surface the assigned order ID if needed.

### Acceptance test

- Create an order from the Flutter app on a real device.
- Within 1 second:
  - Order appears in the Flutter Orders list (already wired via SSE).
  - Order appears on the web admin's order list.
  - Storefront stock for the ordered products decrements.
- Bonus: cancel the order from web admin → Flutter Orders list shows
  the cancellation within 1 second.

---

## Adjacent backend ask: image upload endpoint

> Not strictly part of real-time sync — but the backend dev is the right
> person for it, and the Flutter product form is already wired to expect
> this exact route. Including here so it doesn't fall through the cracks.

The Flutter product form lets admins pick images from device gallery,
shows live previews, supports a primary + up to 4 additional images,
and sends them as `image` (primary URL) + `images` (CSV) on the product
payload. **The picker works today; the upload call 404s** because the
route below isn't deployed yet.

### Contract Flutter expects

```
POST /api/v1/m/uploads
Authorization: Bearer <access token>
Content-Type: multipart/form-data
field name: "file"

200 OK
{ "data": { "url": "https://cdn.example.com/products/xyz.jpg" } }

401  → returns to login (existing handler)
413  → "File too large"
4xx  → { "error": "..." } surfaces as snackbar in the form
```

The path lives under the mobile namespace (`/api/v1/m/`) so it picks up
the same auth/tenant headers as every other route.

### Drop-in implementation (Vercel Blob)

Place at `src/app/api/v1/m/uploads/route.ts` on the backend repo. Free
tier of Vercel Blob easily covers a small store; URLs are auto-CDN
cached and on a `*.public.blob.vercel-storage.com` domain.

```ts
import { put } from '@vercel/blob';
import { NextRequest, NextResponse } from 'next/server';
import { getSessionUser } from '@/lib/auth'; // existing helper

export const runtime = 'edge';

export async function POST(req: NextRequest) {
  const user = await getSessionUser(req);
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const form = await req.formData();
  const file = form.get('file');
  if (!(file instanceof File)) {
    return NextResponse.json({ error: 'No file provided' }, { status: 400 });
  }

  // Cap at 5 MB. Flutter side already downscales to 2048px @ 88%, so
  // typical product photos land around 200–500 KB. Adjust if you accept
  // larger originals.
  if (file.size > 5 * 1024 * 1024) {
    return NextResponse.json(
      { error: 'File too large (max 5 MB)' },
      { status: 413 },
    );
  }

  // Sanity-check MIME so the bucket only stores images.
  if (!file.type.startsWith('image/')) {
    return NextResponse.json(
      { error: 'Only image uploads are accepted' },
      { status: 415 },
    );
  }

  const blob = await put(`products/${Date.now()}-${file.name}`, file, {
    access: 'public',
    addRandomSuffix: true,
  });

  return NextResponse.json({ data: { url: blob.url } });
}

// Optional: 1 MB form-data limit override; Edge default is 4 MB body
export const config = { api: { bodyParser: false } };
```

### Setup steps

1. **Install:** `pnpm add @vercel/blob` (or yarn / npm).
2. **Connect Blob storage** on Vercel: Project → Storage → Blob →
   *Connect*. This adds `BLOB_READ_WRITE_TOKEN` automatically to the
   project's env vars.
3. **Deploy.** No additional config — the `runtime: 'edge'` line is
   what keeps multipart uploads from hitting the 4.5 MB Node serverless
   request body limit.
4. **Verify:** in the Flutter app, open Add Product, tap **Add Image**,
   pick a photo. The tile should show the upload spinner, then render
   the actual image with a "Primary" pill badge.

### If you'd rather use a different store

The Flutter side only cares about the response shape. Any of these work
identically as long as the route returns `{ "data": { "url": "..." } }`:

- **AWS S3 / R2:** sign requests server-side; response is the public URL.
- **Cloudinary:** server-side `cloudinary.uploader.upload(buffer)` →
  return `result.secure_url`.
- **Supabase Storage:** `supabase.storage.from('products').upload(...)`
  → return the public URL.
- **Self-hosted (e.g. on the Coolify box):** save to disk, return
  `https://<host>/uploads/<filename>`.

### Tie-in with sync

The upload route itself doesn't bump anything — uploading a file
doesn't change a product. The product **save** (`POST/PATCH /products`)
already includes `image` + `images` in the payload, and that route
already calls `bumpVersion('products')` per the audit table above. So
the moment a Flutter admin saves a product with new images, the web
admin's products list and the storefront's PDP refresh within a second
— no extra bump needed for uploads.

---

## Common pitfalls

- **Bumping before the DB write commits.** If the bump fires before the
  transaction commits, clients refetch and see stale data. Always bump
  *after* the await on the DB call resolves.
- **Bumping inside transactions that get rolled back.** If a route
  bumps, then the transaction errors and rolls back, every client
  refetches and sees no change — confusing. Bump only on success path.
- **Missing `Cache-Control: no-store, no-cache, no-transform` on the SSE
  response.** Some proxies (Cloudflare on free, certain corporate
  middleboxes) buffer the stream and break real-time. Set explicitly.
- **Flooding bumps on bulk operations.** If you import 1000 products,
  don't bump 1000 times. Batch the writes, then bump once at the end.
- **Forgetting to bump `theme` on customizer saves.** The most-changed
  resource by far. Every theme/brand setting save must bump.

---

## Done means

A user editing the brand color in the customizer sees:
1. Their save complete in the web admin (own client).
2. The Flutter app's pills, buttons, and headers repaint within 1s.
3. The storefront hero, header, and CTAs repaint within 1s.

All three, every time, with no manual refresh anywhere.

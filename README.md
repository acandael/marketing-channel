# Marketing Channel

Rails 8 app for the Alternative Health Practitioner Directory (Germany). See
`_build_plan/prd.html` for the project brief and `_build_plan/milestones/` for
per-milestone build notes. The `_build_plan/` folder is documentation only and
will be deleted once the initial build-out is complete — nothing in the app
should reference it.

## Stack

- Ruby 3.4, Rails 8.1 (Propshaft, Hotwire/Turbo, Stimulus via importmap)
- PostgreSQL
- Solid Queue / Solid Cache / Solid Cable
- Rails 8 built-in authentication
- `pagy` for pagination
- `geocoder` for Nominatim geocoding
- Leaflet + OpenStreetMap tiles (loaded via CDN in the admin layout)

## Local setup

1. Install dependencies:

   ```
   bundle install
   ```

2. Create the databases and run migrations:

   ```
   bin/rails db:create db:migrate
   ```

3. Create the first admin user:

   ```
   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=changeme123 bin/rails admin:create
   ```

   Or run `bin/rails admin:create` interactively.

4. Start the server:

   ```
   bin/rails server
   ```

5. Visit http://localhost:3000/ (placeholder) and sign in at
   http://localhost:3000/session/new. Admins land on `/admin`.

## Transactional email

Development uses the `letter_opener` gem — every mail sent via
`deliver_now`/`deliver_later` opens in a new browser tab (the
`tmp/letter_opener` directory holds the message HTML). No SMTP setup is needed
locally.

Production is wired to send through Resend's SMTP endpoint. Set the API key via
credentials:

```
bin/rails credentials:edit
```

```yaml
resend:
  api_key: re_xxxxxxxxxxxx
mail:
  from: "Marketing Channel <no-reply@your-domain.example>"
```

Or provide `RESEND_API_KEY` as an environment variable as a fallback, and set
`APP_HOST` to the deployed hostname so links in emails resolve.

## Image processing

The practitioner profile photo and gallery images are stored via Active Storage
and rendered through named variants (`:square`, `:thumb`, `:preview`) using the
`image_processing` gem, which needs **libvips** or **ImageMagick** on the host.
On macOS: `brew install vips` (or `imagemagick`).

## Cloudflare R2 (production Active Storage)

Development stores uploads on the local disk under `storage/`. Production is
wired to Cloudflare R2 (`config.active_storage.service = :cloudflare` in
`config/environments/production.rb`, service defined in `config/storage.yml`).

Provide credentials via `bin/rails credentials:edit`:

```yaml
cloudflare_r2:
  access_key_id:     R2_XXXXXXXXXXXX
  secret_access_key: XXXXXXXXXXXXXXXX
  bucket:            marketing-channel-prod
  endpoint:          https://<account-id>.r2.cloudflarestorage.com
```

Or via environment variables: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
`R2_BUCKET`, `R2_ENDPOINT`.

## Nominatim usage

The geocoder initializer at `config/initializers/geocoder.rb` sends a
Mozilla-style User-Agent identifying this app. Nominatim's usage policy limits
throughput to 1 request/second and asks that requests identify the application
— for admin-scale usage (one address at a time on save) this is fine. In
production the User-Agent should be updated with the real deployed URL.

## Milestone 1 verification

The full acceptance walk is:

1. Sign in at `/session/new` → admin lands on `/admin` (dashboard, 5 status
   tiles).
2. `/admin/specialties` → add a few specialties.
3. `/admin/practitioners/new` → fill in a German address (e.g. Alexanderplatz
   1, 10178 Berlin) → save → edit page shows a Leaflet map with a draggable
   pin near the address.
4. Drag the pin, save, reopen — pin stays where it was dragged.
5. Filter and search on `/admin/practitioners`. Bulk publish/unpublish/delete
   works via the checkbox column.
6. No public pages exist yet besides the placeholder root.

## Tests

```
bin/rails test
```

Rails' default Minitest is installed. Adding tests is deferred to a later
milestone unless a change specifically warrants one.

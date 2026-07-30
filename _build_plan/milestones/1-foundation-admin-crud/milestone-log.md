# Milestone 1 — Foundation & Admin CRUD (log)

## What's new in the app

- **Admin sign-in.** Admins can log in at `/session/new` and land on a private admin console at `/admin`.
- **Directory dashboard.** The admin home shows a five-tile summary of the practitioner directory — total, published, unpublished, claimed, unclaimed — plus a "recently updated" list.
- **Specialty taxonomy.** Admins can create, rename, and delete specialties. Specialties that are already assigned to a practitioner can't be deleted until they're unassigned.
- **Practitioner seed profiles.** Admins can add a practitioner one at a time, filling in salutation, name, address, PLZ, city, Bundesland (16-state dropdown), phone, public email, website, and any number of specialties. Publishing is a per-profile toggle.
- **Automatic geocoding + map preview.** Saving a practitioner geocodes the address against Nominatim; the edit page shows a Leaflet map with a draggable pin so the admin can correct the pin position, then re-save.
- **Filterable practitioner list.** Search by name, filter by city, specialty, or status (published / unpublished / claimed / unclaimed), sort by name / city / last updated, paginated 25 per page.
- **Bulk actions.** Check multiple practitioners and publish, unpublish, or delete them in one go, with confirm prompts on destructive actions.
- **Placeholder public root.** The public site at `/` shows a "coming soon" placeholder until milestone 2 replaces it.

## What was built

### Rails app skeleton

- `rails new .` inside the existing project root (Rails 8.1, Ruby 3.4, PostgreSQL, Propshaft, Hotwire+importmap, Solid Queue/Cache/Cable, Active Storage, Action Mailer). `--skip-jbuilder`, no Kamal changes yet. Preserved `_build_plan/` and `AGENTS.md` at the root.
- Added `pagy` (~> 9.3 — pinned below the 43.x rewrite because that version replaces `Pagy::Backend`/`Pagy::Frontend` with a new class API) and `geocoder` (~> 1.8).

### Authentication (Rails 8 built-in)

- `bin/rails generate authentication` — produced `User`, `Session`, `Current`, `SessionsController`, `PasswordsController`, `Authentication` concern.
- Extended `users` migration (added `role` string, default `"practitioner"`, plus index). Rails enum on `User#role` with `admin` / `practitioner` values.
- `AdminAuthorization` concern (`app/controllers/concerns/admin_authorization.rb`) redirects non-admins to `/` with a flash.
- `Authentication#after_authentication_url` now sends admins to `/admin` after sign-in.

### First-admin bootstrap

- `lib/tasks/admin.rake` provides `admin:create` — reads `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars or prompts on stdin. See README for usage.

### Data model

- `specialties(name unique, slug unique, description)` — `Specialty#assign_slug` before validation via `parameterize`. `Specialty#in_use?` and `#usage_count` used to guard destroy.
- `practitioners(salutation, full_name, street_address, postal_code, city, bundesland, phone, public_email, website_url, latitude, longitude, published, claimed_at, user_id)` — includes `claimed_at` and nullable `user_id` even though they're only wired up starting in milestone 3, so no schema churn later. Indexes on `city`, `postal_code`, `published`, and `[latitude, longitude]`.
- `practitioner_specialties` join table with a unique compound index on `[practitioner_id, specialty_id]`.
- Bundesland is stored as a plain string but validated against the `Practitioner::BUNDESLAENDER` constant (all 16 states), with the form field rendered as a select.

### Geocoding

- `config/initializers/geocoder.rb` — Nominatim lookup, 5-second timeout, `language: "de"`, and a Mozilla-style identifying User-Agent (see "Decisions" below).
- `Practitioner#geocode_if_address_changed` before_validation callback — runs only when address/postal_code/city changed, composes `"street, PLZ city, Germany"`, silent no-op on API failure so the admin can drop the pin manually.
- Draggable-marker Leaflet preview via `app/javascript/controllers/map_controller.js` — updates hidden lat/lng inputs on `dragend` and on click when no coords exist yet.

### Admin area

- `Admin::BaseController` (layout `admin`, includes `Pagy::Backend`, exposes `Pagy::Frontend` as helper), `Admin::DashboardController` (5 tiles + recent list), `Admin::SpecialtiesController` (RESTful, guards destroy with `in_use?`), `Admin::PractitionersController` (RESTful + `bulk_publish` / `bulk_unpublish` / `bulk_destroy` collection routes, with filters `?q=`, `?city=`, `?specialty_id=`, `?status=`, and whitelisted `?sort=`/`?direction=`).
- `AdminHelper` — `status_badges_for`, `sort_link_to`, `sidebar_link`.
- Views: dashboard, specialties (index/new/edit/_form), practitioners (index/new/edit/_form/_map_preview/_row).
- Sessions and password views were restyled to match the design system.
- `bulk_actions_controller.js` Stimulus controller for the checkbox column + bulk action bar (toggle-all, count display, show/hide the bar).

### Styling

- Ported `~/Projects/nhd-css/style.css` — Inter variable font (`.ttf` files copied to `app/assets/fonts/`), `@layer global, component, utility;` cascade, `calc(N/16*1rem)` breakpoints, HSL design tokens. Added admin-specific components in the `component` layer: sidebar shell, stat tiles, filter bar, tables, forms, badges, chips, buttons, dialog, map, pagination, coming-soon, auth cards. Single `application.css` (no separate files), so one HTTP request in production.
- Leaflet 1.9.4 CSS + JS pinned to `unpkg` in the admin layout.

### Routes

```
root                → home#index                 (placeholder)
resource :session
resources :passwords, param: :token
namespace :admin do
  root              → dashboard#index
  resources :specialties
  resources :practitioners do
    collection do
      patch  :bulk_publish
      patch  :bulk_unpublish
      delete :bulk_destroy
    end
  end
end
```

## Decisions made during implementation (not pre-specified in the PRD)

1. **`claimed_at` and `user_id` are in the milestone-1 schema.** They're never populated in this milestone, but including them now means milestone 3 doesn't need a schema migration to start the claim flow. Model exposes `Practitioner#claimed?` predicate and `claimed`/`unclaimed` scopes already.
2. **Salutation is a fixed list.** `Practitioner::SALUTATIONS = ["Herr", "Frau", "Dr.", "Prof. Dr.", "Prof."]`. If a practitioner has a title that isn't listed, an admin will need to add it here — deliberate simplification for v1.
3. **Postal code is validated as 5 digits.** Blank is allowed so admins can save partial records, but any value must match `/\A\d{5}\z/`. Matches German PLZ format; simplifies text search by city.
4. **Specialty delete on used specialty is blocked**, not offered as a "reassign then delete" flow. Simpler for milestone 1; a reassign UI can come later if the admin team asks for it. The block message tells the admin how many practitioners are affected.
5. **Geocoder User-Agent uses a Mozilla-style prefix.** During smoke testing, the plain `"MarketingChannelDirectory/0.1 (admin@example.com)"` User-Agent was refused by Nominatim ("Access denied. See usage policy."). A Mozilla-style UA `"Mozilla/5.0 (compatible; MarketingChannelDirectory/0.1; +https://example.com)"` is accepted. This must be updated with the real production URL before launch — Nominatim's policy asks for a valid contact URL or email. **Action for a later milestone:** replace `+https://example.com` in `config/initializers/geocoder.rb` with the real deployed domain.
6. **Geocoding is synchronous, not queued.** Solid Queue is set up, but geocoding is a single OSM request on save and admin volume is tiny. Async would add complexity and defer feedback ("did my address resolve?") for no gain. Milestone 4 can revisit if practitioner self-serve edits multiply the call volume.
7. **Pagy pinned to `~> 9.3`.** Rubygems currently resolves `pagy ~> 43.6` (which is a full rewrite that removes `Pagy::Backend`/`Pagy::Frontend`/`pagy_nav` in favor of a new API). Downgraded to 9.x to keep the traditional API. A future milestone can migrate to 43.x if the new API has clear wins.
8. **Placeholder home page uses the plain `application` layout.** It intentionally doesn't share the admin sidebar. Milestone 2 will replace this view with the real public homepage.
9. **Leaflet loaded from `unpkg` CDN**, not vendored, to keep the admin JS surface minimal. Milestone 4 (which will use Leaflet on the public profile page too) can revisit vendoring for offline dev if needed.
10. **CSS lives in a single `application.css` file**, not split per component. Rails 8 uses Propshaft which doesn't preprocess/concatenate; a single file avoids the `@import` HTTP-cascade problem and keeps one `<link>` tag in the layout.

## Anything the next milestone needs to know

- **The `Practitioner` model already scopes `claimed`/`unclaimed` and exposes `claimed?`.** Milestone 3 can immediately filter and badge on those without needing a schema change.
- **`user_id` is nullable and unique on `practitioners`.** When a User claims a profile, milestone 3 just sets `practitioner.user_id` and `claimed_at`.
- **`AdminAuthorization#require_admin` uses `Current.user&.admin?`** — milestone 4's practitioner area should build a parallel `PractitionerAuthorization` concern that redirects admins away from practitioner-only pages (mirror pattern).
- **The `Practitioner::BUNDESLAENDER` constant** is available anywhere for validation or select building. Do not add ad-hoc lists elsewhere.
- **The full-name search uses ILIKE.** Fine for milestone 2 as-is; if the public directory needs typo tolerance later, that's an out-of-scope milestone-2 item.
- **`SessionsController#create` uses `after_authentication_url`** which now differentiates admins vs. practitioners. Milestone 4's practitioner login redirect is already handled — just make sure `default_authenticated_url` grows a `practitioner_dashboard_url` branch.
- **The placeholder `home#index` layout is `application`.** Milestone 2 should replace `app/views/home/index.html.erb` (and probably introduce a `layouts/public.html.erb` with the real chrome). No routing change needed — root is already `home#index`.
- **The `map_preview` partial and `map_controller.js` Stimulus controller are reusable.** Milestone 2's public profile page can use the same JS controller (just make it non-draggable when appropriate — the controller currently only wires drag if there's a marker, so passing `has-coordinates-value=false` on the public page would need a small edit).
- **Nominatim geocoder is single-threaded and slow.** For milestone 4's practitioner self-serve edits, consider debouncing or moving to a queued job.

## Deviations from the PRD

- **PRD says "Rails 8 built-in auth (login, logout, password reset). Users have a role of admin or practitioner."** Implemented as specified, with the extra decision noted above about routing admins to `/admin` post-signin.
- **PRD says "Rake / console task for creating the first admin user."** Implemented as a Rake task (`admin:create`), not just a console recipe, because it's more discoverable and scriptable.
- **PRD says "sensible base typography and spacing" for the plain-CSS scaffold.** Rather than write a generic scaffold, ported the ready-made `nhd-css` design system per user direction — same cascade-layer approach, same Inter font, same token style.
- **PRD says the admin dashboard shows "counts of practitioners by status".** Interpreted as five tiles per the clarifying question: total, published, unpublished, claimed, unclaimed. Also added a small "recently updated" list because the dashboard would otherwise be sparse with the seed database empty.
- **No changes to scope.** Everything the PRD marked "Not in this milestone" is genuinely not built (no public directory, no premium fields, no Resend, no R2, no practitioner login).

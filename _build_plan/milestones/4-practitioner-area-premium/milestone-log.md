# Milestone 4 — Practitioner area & premium content (log)

## What's new in the app

- **Real practitioner dashboard.** After signing in, a claimed practitioner lands on `/dashboard` with a hero (photo/initial + name + city), a profile-completeness meter with the list of missing fields, quick-link tiles to Edit profile / Settings / View public profile, and a publish toggle.
- **Full self-serve profile editor.** One page groups Basic info (identity, address that re-geocodes on save, specialties multi-select) and Premium content (photo upload, rich-text bio via Trix, services list, opening-hours grid, languages, qualifications, years, gallery uploads).
- **Public profile now shows premium content.** Uploaded photo replaces the initial avatar. Tagline appears as a subtitle. Bio, services list, gallery grid, opening-hours table, languages chips, qualifications list, and years-in-practice all render — each only when populated.
- **Directory cards use uploaded photos.** On the homepage grid, practitioners with a photo show it (thumbnail); the initial-avatar fallback stays for those without.
- **Publish/unpublish toggle for the practitioner.** From the dashboard, a practitioner can hide their listing from the public directory. Admins can override from admin.
- **Settings area.** Change password (with current-password check), change email (via a confirmation link sent to the new address, valid for 24 hours), and delete account (soft-delete with the profile reverting to unclaimed; an admin is notified).
- **Uploads stored in Cloudflare R2 in production.** Local disk in development; production Active Storage is wired to Cloudflare R2 via S3-compatible endpoints.

## What was built

### Data model & migrations

- `db/migrate/*_create_active_storage_tables.active_storage.rb` and `*_create_action_text_tables.action_text.rb` from `bin/rails action_text:install` (installs both Active Storage variant/records support and Action Text).
- `db/migrate/*_add_premium_fields_to_practitioners.rb`:
  - `short_tagline:string`, `services_offered:text`, `languages_spoken:text`, `qualifications:text`, `years_in_practice:integer`
  - `opening_hours:jsonb NOT NULL DEFAULT '{}'`
- `db/migrate/*_add_email_change_and_deletion_to_users.rb`:
  - `pending_email_address:string`, `email_change_token:string` (unique index), `email_change_sent_at:datetime`
  - `deleted_at:datetime` (indexed)

### Model changes

**`app/models/practitioner.rb`**
- `has_rich_text :long_bio` (Action Text).
- `has_one_attached :profile_photo` with named variants: `:square` (400×400 webp) and `:thumb` (96×96 webp).
- `has_many_attached :gallery_images` with `:preview` (800×800 fit) and `:thumb` (200×200 fill).
- Validations: `short_tagline` length ≤ 140, `years_in_practice` 0–100 integer.
- Custom `validate :validate_profile_photo` / `validate :validate_gallery_images` — enforce content-type ∈ {jpeg, png, webp}, ≤ 5 MB per image, ≤ 10 gallery images (Rails 8's inline `content_type:` / `size:` validator API changes between versions; a hand-rolled validator is stable across versions).
- `PREMIUM_FIELDS` constant + `DAYS_OF_WEEK` constant.
- Custom `opening_hours=` writer — accepts the form's `{ "monday" => { "open" => ..., "close" => ..., "closed" => "1"|"0" } }` shape and normalizes to `{ "monday" => { "open", "close" } }` or drops the day entirely if closed/blank.
- Helpers: `services_list`, `languages_list`, `qualifications_list` (split-on-newline + reject blanks), `opening_hours_for(day)`, `has_any_opening_hours?`, `profile_completeness` (0–100 across 9 premium fields), `missing_premium_fields` (list of human-readable labels).

**`app/models/user.rb`**
- `active` scope (`where(deleted_at: nil)`).
- Overrides `self.authenticate_by` to scope the lookup to `active` — deleted users can't log in.
- `normalizes :pending_email_address` (same lowercasing rule as `email_address`).
- `start_email_change!(new_email)` — sets `pending_email_address`, generates a unique `email_change_token`, timestamps `email_change_sent_at`.
- `confirm_email_change!` — swaps the pending value into `email_address`, clears the pending fields; refuses if expired (24h) or if pending is blank.
- `email_change_expired?`, `deleted?` predicates.
- `EMAIL_CHANGE_LIFETIME = 24.hours` constant.

### Cloudflare R2 storage

- `Gemfile` — `gem "aws-sdk-s3", require: false` in the `:production` group (Active Storage uses it for S3-compatible endpoints).
- `config/storage.yml` — new `cloudflare` service (`service: S3`, `region: auto`, credentials via `credentials.dig(:cloudflare_r2, ...)` with `R2_*` env-var fallback, `endpoint`, `force_path_style: true`, `request_checksum_calculation: when_required`, `response_checksum_validation: when_required` — the last two are important for R2 which doesn't implement newer AWS-CRC headers).
- `config/environments/production.rb` — `config.active_storage.service = :cloudflare`.
- `README.md` — new "Cloudflare R2" section documenting credentials.

### Routes

New `scope "/dashboard", module: "practitioner", as: "practitioner"` block:
- `GET  /dashboard`               → `Practitioner::DashboardController#show`  (`practitioner_root_path`)
- `GET  /dashboard/profile/edit`  → `Practitioner::ProfilesController#edit`   (`edit_practitioner_profile_path`)
- `PATCH /dashboard/profile`      → `Practitioner::ProfilesController#update`
- `GET  /dashboard/settings`      → `Practitioner::SettingsController#show`
- `PATCH /dashboard/settings`     → `Practitioner::SettingsController#update`
- `DELETE /dashboard/account`     → `Practitioner::AccountsController#destroy`
- `PATCH /dashboard/publish` / `/unpublish` → profile publish toggle actions

Plus `GET /email_changes/:token` → `Public::EmailChangesController#show` (`confirm_email_change_path`).

The old `get "/dashboard" → practitioner/dashboard#show` route was replaced by the scoped block. Old helper `practitioner_dashboard_url` → `practitioner_root_url`.

### Controllers

- **`Practitioner::BaseController`** — includes `PractitionerAuthorization` (from milestone 3), sets `@practitioner` in a before_action, uses `layout "practitioner"`.
- **`Practitioner::DashboardController#show`** — trivial; delegates to view.
- **`Practitioner::ProfilesController`** — `edit`, `update`, `publish`, `unpublish`. Strong params permit all basic + premium fields, `long_bio` (Action Text handles the rich text under the same key), `profile_photo`, `gallery_images[]`, `opening_hours` (nested hash whitelist built dynamically from `DAYS_OF_WEEK`).
- **`Practitioner::SettingsController`** — `show` + `update` (branches on `params[:section]` = `"password"` | `"email"`). Password update requires current password + 8+ char new password + matching confirmation. Email change validates format + uniqueness across active users, then calls `user.start_email_change!` and enqueues the confirmation mailer.
- **`Practitioner::AccountsController#destroy`** — soft-deletes the user (sets `deleted_at`), clears `practitioner.user_id` and `practitioner.claimed_at`, sends `AdminNotificationMailer.account_deleted` (recipient from credentials/env or the first admin user), terminates the session, redirects to `/`.
- **`Public::EmailChangesController#show`** — looks up user by token; 404 if not found, 410 if expired, 302 → `/session/new` with success flash on confirm.

### Mailers & templates

- `EmailChangeMailer#confirm` → `to: user.pending_email_address`. HTML + text templates showing old vs new email, the confirm link, and the expiry date.
- `AdminNotificationMailer#account_deleted` → `to: admin_email`. Explains the practitioner is now unclaimed and the profile data remains intact for re-invitation.
- Previews at `test/mailers/previews/{email_change_mailer,admin_notification_mailer}_preview.rb` for `/rails/mailers`.

### Views

- **`app/views/layouts/practitioner.html.erb`** — sticky top bar with brand, Dashboard/Edit/Settings links, current email badge, Sign out. Loads Leaflet CDN (needed for the map preview on the edit form).
- **`app/views/practitioner/dashboard/show.html.erb`** — hero card with photo/initial, "signed in as" line, name + city, "Visible on directory" badge, completeness card (percentage + gradient bar + missing-fields sentence), action-tile grid, publish-toggle card.
- **`app/views/practitioner/profiles/edit.html.erb`** + partials `_basic_info.html.erb`, `_premium_content.html.erb`.
- **`app/views/practitioner/settings/show.html.erb`** — three form-section cards; the delete-account card has the `danger-zone` class.
- **`app/views/public/practitioners/show.html.erb`** — extended with premium sections in this order: photo header (falls back to initial avatar), tagline as subtitle, specialties, About (Trix rich text via `<%= @practitioner.long_bio %>` inside `.trix-content`), Services (bullet list), Gallery (image grid using `:preview` variant), Opening hours (table with day labels + "Closed" markers), Languages (chip row), Qualifications (bullet list), Experience (years-in-practice sentence), then the existing Contact + Address + map.
- **`app/views/public/home/_practitioner_card.html.erb`** — uses `profile_photo.variant(:thumb)` when attached, initial avatar otherwise.
- **`app/views/public/email_changes/error.html.erb`** — reuses the claim-card shell.

### JavaScript

- Action Text auto-adds Trix imports to `app/javascript/application.js` and pins in `config/importmap.rb`. No custom JS needed beyond that; the map controller from milestone 1/2 is reused for the edit-form pin preview.

### CSS

Added to `application.css` `component` layer:
- Dashboard: `.practitioner-hero`, `.practitioner-hero__photo`, `.avatar-large`, `.completeness-card`, `.completeness-bar` + `__fill` (green gradient), `.dashboard-tiles`, `.dashboard-tile`, `.publish-toggle`.
- Form: `.photo-preview`, `.gallery-preview` + `__img`, `.opening-hours-grid`, `.opening-hours-row` (responsive: collapses on small screens), `.settings-card`, `.danger-zone` (red-tinted border/background).
- Public profile: `.public-profile__photo`, `.practitioner-card__photo`, `.public-profile__tagline` (italic subtitle), `.bulleted-list`, `.gallery` + `__img`, `.hours-table` + `__day` / `__time`.
- Rich text: `.trix-content` (headings, ul/ol, links, paragraphs) and `trix-editor` / `trix-toolbar` styling to fit the existing form controls.

### Helper

- `app/helpers/practitioner_helper.rb` — `day_label(day)` (Mon/Tue/…), `format_opening_hours(entry)` ("09:00 – 17:00" or "Closed").

## Decisions made during implementation (not pre-specified in the PRD)

1. **Hand-rolled Active Storage validators.** Rails' inline `validates :attachment, content_type:, size:` is available in some versions but the exact API drifted between 7.1 / 7.2 / 8.x. To insulate ourselves from that, custom `validate :validate_profile_photo` / `validate :validate_gallery_images` methods enforce content-type + size + 10-image cap explicitly.
2. **`opening_hours` JSONB with `NOT NULL DEFAULT '{}'`.** Makes `Practitioner.opening_hours` always a hash — no `nil` checks in view code. Closed days are represented by absence from the hash (or explicit `null` value); the `opening_hours=` writer normalizes both forms.
3. **`missing_premium_fields` returns human-readable labels**, not attribute names. The dashboard uses `.to_sentence` on the list, so the user reads "Add the following to reach 100%: profile photo, short tagline, long bio." Not "profile_photo, short_tagline, long_bio."
4. **Password change requires current password.** Not strictly in the PRD but standard hygiene — prevents a session-hijack from silently rotating the password.
5. **Password minimum length 8 (same as claim flow).** Consistent with milestone 3.
6. **Email change is deferred, not immediate.** The user's `email_address` doesn't change until the new address confirms. Nothing to roll back if the user typoed. Old email keeps working until confirmation.
7. **Account deletion is soft.** Set `users.deleted_at`; sessions terminate. `User.authenticate_by` is overridden to filter `active`. Rows are kept for auditability and to preserve `Practitioner.updated_by`-style history if we ever add it. Practitioner reverts to unclaimed but the profile data (specialties, address, premium content) stays; admin can re-invite.
8. **Admin notification recipient falls back gracefully.** `credentials.dig(:admin, :notification_email)` → `ENV["ADMIN_NOTIFICATION_EMAIL"]` → first admin user's email. No configuration needed for the dev flow to work.
9. **R2 config uses S3 service.** Rails 8's built-in `:s3` service works with Cloudflare's endpoint. `request_checksum_calculation: when_required` and `response_checksum_validation: when_required` are added — R2 doesn't fully implement AWS's newer CRC checksum handshake and will 400-out without these settings on recent aws-sdk-s3 versions.
10. **Practitioners cannot create new specialties.** Only `specialty_ids: []` is permitted in strong params — no way to create a new `Specialty` from this form. Matches PRD.
11. **Practitioner-editable geocoding reuses the admin flow.** The same `before_validation :geocode_if_address_changed` callback fires on the practitioner's save. The same `map_preview` partial and Stimulus controller show a draggable pin.
12. **Old dashboard route removed cleanly.** The milestone-3 stub view (`app/views/practitioner/dashboard/show.html.erb`) was overwritten in-place. `Authentication#default_authenticated_url` updated to `practitioner_root_url` (the new named helper).
13. **`link_to` block form gotcha fixed once.** `link_to(text, path, options) do ... end` was crashing at runtime (`String#stringify_keys` NoMethodError) because passing both a string arg and a block confuses the signature. The correct form is `link_to(path, options) do ... end` — text goes inside the block. Called out here in case another view hits the same crash.

## Anything the next milestone needs to know

There is no next milestone in the current PRD; the four-milestone build-out is complete. If further milestones are added, the following are worth knowing:

- **`Practitioner` is now the source of truth for premium content**, and the model exposes helpers (`services_list`, `has_any_opening_hours?`, `profile_completeness`, `missing_premium_fields`) that both the practitioner dashboard and the public profile use. Any new premium field should:
  1. Add a column via migration.
  2. Add to `PREMIUM_FIELDS`, `profile_completeness`, and `missing_premium_fields`.
  3. Add a form field to `_premium_content.html.erb`.
  4. Add a conditional section to `public/practitioners/show.html.erb`.
- **`User.authenticate_by` is overridden** to scope to `active`. Any future login pathway that doesn't go through `authenticate_by` needs to check `!user.deleted?` explicitly.
- **Cloudflare R2 credentials are unset in dev.** Anything that touches Active Storage from the production environment without R2 credentials will 500 at upload time. This is intentional — set the credentials before deploying.
- **`image_processing` needs libvips or ImageMagick on the host.** README calls this out. If deploying without either, variant generation will crash at first access.
- **Opening-hours schema is intentionally flat.** No support for split shifts (e.g. 9-12 + 15-19) or holiday overrides. If we need those, expand the JSONB shape.
- **Long bio uses Action Text.** If we swap editors, the `has_rich_text` association can be replaced with a plain text column and a migration to move `ActionText::RichText.body` into it. Public profile currently uses `<%= @practitioner.long_bio %>` inside a `.trix-content` div — the CSS class name should be renamed if Trix goes away.
- **Public profile currently renders `long_bio` inline.** The Trix output is server-sanitized by Action Text (it strips scripts/etc.), so this is safe. If untrusted authors are ever added, revisit.

## Deviations from the PRD

- **PRD says the settings area should "delete account (soft-delete User, profile reverts to unclaimed and admin is notified)"** — implemented exactly.
- **PRD says "change login email (with re-verification)".** Implemented as a confirmation link sent to the new address; the old email remains active until the link is clicked. This is stronger than just re-verification: the new address must prove itself before the old one is retired.
- **PRD says "profile-completeness indicator based on premium fields".** Implemented as a bar + percentage + explicit list of missing fields.
- **PRD says the profile edit form should re-geocode on address change.** Achieved for free by reusing the existing `before_validation :geocode_if_address_changed` callback on `Practitioner`.
- **PRD says "specialties multi-selectable from the admin-managed list; practitioners cannot create new ones".** Enforced by strong params + form (checkbox list from `Specialty.alphabetical`).
- **PRD lists all premium fields**: photo, tagline, long bio (rich text), services, opening hours (per-day), languages, qualifications, years-in-practice, gallery — every one is present.
- **PRD says "Cloudflare R2 configured as the Active Storage backend for production; local disk continues in dev".** Implemented exactly; no live R2 test in dev (no credentials), but the production env boots with `active_storage.service = :cloudflare` and the config parses with dummy `R2_*` env vars.
- **PRD says public profile "renders premium sections when populated (and only when populated)".** Every premium section is wrapped in `if <field>.present?` — no empty blocks.
- **PRD says the ribbon should disappear on claimed profiles.** Already handled in milestone 3; verified still working (an unclaimed profile shows the ribbon, a claimed one doesn't).
- **No scope additions.** Everything the PRD flagged out of scope (2FA, social login, drafts, autosave, gallery reorder, verification badges, multiple locations, analytics, German I18n) is genuinely not built.

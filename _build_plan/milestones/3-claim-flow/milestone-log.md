# Milestone 3 — Claim flow (log)

## What's new in the app

- **Admins can send claim invitations.** On any unclaimed practitioner's row (and on the edit page) there's a "Send / Re-send invitation" button. A confirm dialog pops with the practitioner's contact email pre-filled and editable.
- **Practitioners get a friendly claim email.** Each invitation email includes a big "Claim my profile" button, a fallback plain-text URL, an expiration date, and a plain-text alternative for accessibility.
- **One-click claim landing page.** The URL in the email lands the practitioner on `/claim/<token>` showing a preview of their profile (name, city, up to 3 specialty chips) plus a simple form to choose a password. Email is pre-filled and editable.
- **Instant sign-in on completion.** Setting a password creates a practitioner-role user, links the profile, marks it claimed, and drops the practitioner on a stub dashboard, already signed in.
- **Stub practitioner dashboard.** After claiming (or on future sign-in), practitioners land on `/dashboard` — a welcome card with their name, a link to their public profile, a sign-out button, and a note explaining that the full dashboard arrives next milestone.
- **Friendly error pages.** Invalid tokens show a 404 "not valid" page; expired invitations show a 410 page with the expiry date; already-claimed invitations show a 410 page with a "Sign in" link.
- **Admin sees invitation state on every row.** A chip in the practitioners list shows "Never invited" / "Invited N days ago" / "Invite expired" / "Claimed on <date>". Re-inviting from any state invalidates any previously-pending token for that practitioner.
- **Softer "Basic listing" ribbon copy.** Unclaimed public profiles now say "this profile hasn't been claimed by <Name> yet" — no misleading self-serve link, since the claim flow is admin-triggered per PRD.

## What was built

### Data model

- `db/migrate/20260730100311_create_claim_invitations.rb` — `claim_invitations(practitioner_id, unique_token, email_sent_to, sent_at, expires_at, claimed_at)`. Unique index on `unique_token`, composite index on `(practitioner_id, sent_at)`.
- `app/models/claim_invitation.rb`:
  - `belongs_to :practitioner`.
  - Constants `TOKEN_BYTES = 32` (43 char URL-safe base64) and `LIFETIME = 30.days`.
  - `before_validation on: :create` — `generate_token` (retry loop on collision), `set_default_expiration` (30d), `set_default_sent_at` (now).
  - Validations: presence and format of `email_sent_to`, presence and uniqueness of `unique_token`, presence of `expires_at`/`sent_at`.
  - Instance `#status` → `:claimed | :expired | :pending` derived from `claimed_at` + `expires_at`. Predicates follow.
  - Scopes: `pending`, `expired`, `claimed`.
  - Class method `ClaimInvitation.invalidate_pending_for(practitioner)` — bulk `update_all(expires_at: 1.second.ago)` for that practitioner's pending rows.
  - `to_param` returns `unique_token` (though claim routes explicitly use the `:token` param name).
- `app/models/practitioner.rb`:
  - `has_many :claim_invitations, dependent: :destroy`.
  - `has_one :latest_claim_invitation, -> { order(sent_at: :desc) }, class_name: "ClaimInvitation"` (eager-loaded in the admin index to avoid N+1 on the status chip).

### Mailer

- `app/mailers/application_mailer.rb` — updated `default from:` to look up `credentials[:mail][:from]`, then `ENV["MAIL_FROM"]`, then a fallback address.
- `app/mailers/claim_invitation_mailer.rb` — single `invite` action reading `params[:invitation]`.
- HTML template (`invite.html.erb`) styled inline for email-client compatibility: greeting, one-paragraph explanation, big green "Claim my profile" button, fallback URL, expiration date.
- Plain-text template (`invite.text.erb`) — same content, plain.
- `test/mailers/previews/claim_invitation_mailer_preview.rb` — browsable at `/rails/mailers/claim_invitation_mailer/invite`. Falls back to a new-in-memory `ClaimInvitation` if there aren't any in the DB, so the template renders in any environment.

### Mailer configuration

- `config/environments/development.rb`:
  - `config.action_mailer.delivery_method = :letter_opener`
  - `config.action_mailer.perform_deliveries = true`
  - `config.active_job.queue_adapter = :inline` — `deliver_later` runs synchronously so `letter_opener` opens the email instantly during admin testing.
- `config/environments/production.rb`:
  - `delivery_method = :smtp`, `smtp_settings` pointing at `smtp.resend.com:587` with password read from `credentials.dig(:resend, :api_key)` or `ENV["RESEND_API_KEY"]`.
  - `default_url_options` reads `APP_HOST` env var, forces `https`.
  - `raise_delivery_errors = true` so send failures surface loudly.

### Admin invitation flow

- Route: `namespace :admin do; resources :practitioners do; member { post :send_claim_invitation }; end; end`.
- `Admin::PractitionersController#send_claim_invitation`:
  1. Look up practitioner by slug.
  2. Refuse if already claimed.
  3. Validate submitted email (regex).
  4. `ClaimInvitation.invalidate_pending_for(practitioner)` (defensive — only one live token per practitioner).
  5. `practitioner.claim_invitations.create!(email_sent_to: email)` — model callbacks fill token/expiry/sent_at.
  6. `ClaimInvitationMailer.with(invitation: invitation).invite.deliver_later`.
  7. Redirect back to edit with success flash including expiry date.
- Admin index eager-loads `:latest_claim_invitation` alongside `:specialties`.
- `AdminHelper#invitation_status_chip(practitioner)` — renders the "Never invited" / "Invited Xd ago" / "Invite expired" / "Claimed on <date>" chip. Uses badge classes `badge--muted` (new), `badge--unclaimed` (pending, amber), `badge--unpublished` (expired, muted), `badge--published` (claimed, green).
- Row partial (`_row.html.erb`) — new "Invitation" column showing the chip. `index.html.erb` — new column header, colspan bumped on empty state.
- Edit page — new `_invitation_panel.html.erb` partial rendered above the main form. Shows current state ("Invited N days ago to name@example.com, expires <date>", "Invite expired on <date>", "Claimed by <email> N days ago", or "No invitation has been sent yet"). Includes a "Send / Re-send invitation" button that opens a `<dialog>` with an editable email field pre-populated from `practitioner.public_email`.
- Stimulus `invite_dialog_controller.js` — `open`/`close` actions using the native `<dialog>` element (`showModal`, `close`), focuses the email field on open.

### Public claim flow

- Routes:
  - `get  "/claim/:token" → public/claims#show`, named `claim`.
  - `post "/claim/:token" → public/claims#create`, named `submit_claim`.
  - Both constrained to `[A-Za-z0-9_\-]+`.
- `Public::ClaimsController < Public::BaseController` (inherits `allow_unauthenticated_access`, `layout "public"`).
- `#show`:
  - Not found → renders `error` (404) "Invitation not found".
  - Claimed → renders `error` (410) with a "Sign in" button.
  - Expired → renders `error` (410) mentioning the expiry date.
  - Pending → renders `show` with practitioner preview + password form.
- `#create`:
  - Re-checks state (guards against races).
  - Validates email format and password length (`min 8` chars).
  - Transaction: creates `User(role: :practitioner)`, updates `Practitioner(user_id, claimed_at)`, updates `ClaimInvitation(claimed_at)`, invalidates any other pending rows for the same practitioner.
  - `start_new_session_for(user)` (existing Authentication concern helper) → redirect to `/dashboard`.
  - Errors (`ActiveRecord::RecordInvalid`, e.g. email already taken) → re-render `show` with the submitted email preserved.
- `app/views/public/claims/show.html.erb` — centered card, practitioner preview (avatar-initial + name + city + up to 3 chips), email + password form, expiry note.
- `app/views/public/claims/error.html.erb` — centered card, title + body from `locals`, "Sign in" and "Back to directory" actions.

### Practitioner stub area

- Route: `get "/dashboard" → practitioner/dashboard#show`, named `practitioner_dashboard`.
- `app/controllers/concerns/practitioner_authorization.rb` — `require_practitioner` sends admins to `admin_root_path` (with flash) and unauthenticated visitors to sign-in.
- `app/controllers/practitioner/dashboard_controller.rb` — includes `PractitionerAuthorization`, uses `layout "public"`, sets `@practitioner = Current.user.practitioner`.
- `app/views/practitioner/dashboard/show.html.erb` — welcome copy, "View your public profile" link (only when published), sign-out button, and a paragraph noting that the full dashboard arrives in milestone 4.
- `app/controllers/concerns/authentication.rb` — `default_authenticated_url` now routes practitioner-role users to `/dashboard`.

### CSS additions

Inside the `component` layer of `app/assets/stylesheets/application.css`:
- `.badge--muted` — "Never invited" chip.
- `.invitation-panel__header` — flex layout for the panel header + button.
- `.claim-shell`, `.claim-card`, `.claim-card--error`, `.claim-preview`, `.claim-preview__avatar`, `.claim-preview__label`, `.claim-preview__name` — public claim landing pages.
- `.dashboard-welcome`, `.dashboard-welcome__note` — stub dashboard card.

### Public profile ribbon

- Updated `_show` view copy — no more "claim your profile" call-to-action (the flow is admin-driven), just a matter-of-fact "hasn't been claimed by <Name> yet." to explain the visual difference between claimed and unclaimed listings.

### README

- New "Transactional email" section documenting `letter_opener` in dev and the Resend credentials layout in production.

## Decisions made during implementation (not pre-specified in the PRD)

1. **Password minimum length is 8.** Rails' `has_secure_password` default is 6; bumped to 8 in the claim create action for a nudge above the norm without piling on complexity requirements.
2. **`active_job.queue_adapter = :inline` in development.** Without this, `deliver_later` would push to Solid Queue and wait for `bin/jobs`. Inline is fine for admin-scale volume, keeps the dev flow one-step ("click, see email pop"), and doesn't touch production behavior.
3. **Invitation state is derived from timestamps, not stored.** Model has a `#status` method but no `status` column. Simpler, no cache drift, admin queries via scopes are one line.
4. **`invalidate_pending_for` sets `expires_at: 1.second.ago`.** Chose a timestamp-based invalidation over a status column or a deletion so historical invitations remain queryable (dashboard/analytics later). One-second-ago avoids clock-skew flakiness with the `expires_at > NOW()` scope predicate.
5. **`Practitioner.claim_invitations` has `dependent: :destroy`.** Deleting a practitioner cascades. The alternative (nullify) would leave orphan invitations pointing at a non-existent practitioner; that's not useful and complicates cleanup.
6. **Claim URL constraints allow `_` and `-`.** SecureRandom.urlsafe_base64 produces `[A-Za-z0-9_-]`, so the route constraint mirrors that exactly. Anything not matching returns a routing 404 before hitting the controller.
7. **`Practitioner::DashboardController` uses `layout "public"`.** Reuses the public header so the practitioner sees the same brand chrome they see on the marketing site. Milestone 4 can move it to its own layout when the dashboard has enough surface to justify.
8. **Ribbon copy no longer says "claim your profile".** PRD scope note explicitly excludes self-serve claiming from public profiles. The old copy was a placeholder; it now describes state instead of prompting action.
9. **Bulk send is explicitly not built.** PRD flags it out of scope. Present bulk-actions bar in admin (from milestone 1) is unchanged.
10. **Resend uses SMTP, not the `resend` gem's ActionMailer::Base subclass.** SMTP works out of the box with any ActionMailer template and doesn't couple the mailer to the vendor. If Resend-specific features (batch sends, custom headers) come up later, migrating to their gem is a two-line change.
11. **`ClaimInvitationMailerPreview` handles empty DB.** If no ClaimInvitation exists (fresh clone), the preview builds an in-memory record so the preview page still renders. Useful when introducing a mailer to a codebase before real data exists.
12. **`Practitioner.claim_invitations` associations are eager-loaded on the admin index.** Prevents N+1 on the status chip per row. On a 25-row page this alone would be 25 extra queries.

## Anything the next milestone needs to know

- **A practitioner-role User's account already has `user.practitioner`** available via the `has_one :practitioner, dependent: :nullify` association on User (added way back in milestone 1). Milestone 4's dashboard should use `Current.user.practitioner` for all self-serve reads.
- **The stub dashboard lives at `Practitioner::DashboardController#show`** and uses `PractitionerAuthorization`. Add sibling controllers (settings, profile edit) under the same `Practitioner::` namespace and include the same concern to gate them.
- **`default_authenticated_url` in `Authentication` concern** routes admins to `/admin` and practitioners to `/dashboard`. New authenticated areas should either extend that method or override `after_authentication_url` per controller.
- **Claim invitations are per-practitioner and time-boxed.** `Practitioner#latest_claim_invitation` is the row admins care about; older ones are history. Don't rely on `claim_invitations.first` — it's unordered.
- **Password requirements are enforced in the controller** (`length >= 8`), not on the User model. Milestone 4's practitioner "change password" settings screen should apply the same rule (or centralize it in `User` if the constraint drifts).
- **`letter_opener` writes to `tmp/letter_opener/`.** Nothing there is committed. If you switch away in development (e.g. to `letter_opener_web`), be sure to `rm -rf tmp/letter_opener`.
- **Sign-out from the dashboard already works** via the existing `session_path` DELETE route. Milestone 4 doesn't need to redo it.
- **The `Practitioner` claimed ribbon disappears the moment `claimed_at` is set.** Public views read `practitioner.claimed?`. Milestone 4 doesn't have to touch the ribbon logic.

## Deviations from the PRD

- **PRD data-model table lists a `status` column** on `ClaimInvitation`. Went with a derived `#status` method instead. No column added; scopes stay clean. If we later want to track "manually cancelled by admin" as a distinct state, we can add a column then.
- **PRD says "1-click claim button".** Implemented as a link to `/claim/:token` that shows the password form. The click-through is still one — the practitioner clicks the button in the email, lands on the form, sets a password. There's no auto-claim on click (which would be insecure).
- **PRD says invitation should include a "plain-text version".** Delivered — both HTML and plain-text templates exist; ActionMailer sends both parts. Verified via the mailer log dump in the smoke test.
- **PRD says admin can see "invited on X, not claimed / claimed on Y" state.** Delivered as chip on list + full narrative on edit page's invitation panel. The edit-page narrative includes email address, expiry date, and days since sent — more detail than PRD requires but useful for admin support.
- **PRD asks for a "welcome screen or their (minimal, stub) dashboard"** post-claim. Went with the stub dashboard at a stable URL (`/dashboard`) — no separate welcome screen. A one-time flash "Welcome — your profile is now yours." makes the moment feel intentional; subsequent visits show the dashboard directly.
- **Production Resend integration is code-correct but not live-tested.** In dev, `letter_opener` handles every email; no Resend API key exists in credentials yet. This is the same posture as milestone 1's Nominatim — infrastructure config is in place, real-world credentials get wired up at deploy time.

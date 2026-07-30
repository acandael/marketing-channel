# Milestone 2 — Public directory (log)

## What's new in the app

- **Public homepage.** Anonymous visitors land on a real search page at `/` — brand header, search hero, and a grid of practitioner cards.
- **Search + filters.** Filter published practitioners by specialty (dropdown) and by location (city name or postal-code prefix, combinable). Results are alphabetised, paginated 12 per page.
- **Practitioner cards.** Each result shows an initial-based avatar, name, up to 3 specialty chips (+N indicator when more), and city.
- **Public profile pages.** Each practitioner has a shareable URL like `/practitioners/dr-maria-schmidt-berlin` showing name, salutation, all specialties, contact block (phone/email/website), and address. A Leaflet map pin on the right shows where the practice is.
- **Only published practitioners are public.** Unpublished profiles return 404; nothing about them leaks into search results or profile URLs.
- **"Basic listing" ribbon on unclaimed profiles.** A subtle amber strip at the top of an unclaimed profile invites the practitioner to claim their listing (the real claim CTA lands in milestone 3).
- **Search-friendly page metadata.** Every profile has a name + city page title, a specialty-aware meta description, and a canonical URL — so links share and rank cleanly.
- **Header with sign-in link.** The site's top bar shows the brand and a sign-in link, so admins can jump straight to `/session/new` from any public page.

## What was built

### Data model

- `db/migrate/20260730094703_add_slug_to_practitioners.rb` — adds `slug` (string, unique index) and backfills existing rows in the same migration (`update_column` per row, computing `name-city` parameterized with numeric suffix on collision). Both existing seed practitioners got slugs.
- `app/models/practitioner.rb`:
  - `before_validation :assign_slug` — generates slug from `full_name-city` (parameterized). Only re-runs if slug is blank or `full_name`/`city` changed. Uniqueness enforced via a scoped query loop with `-2`, `-3`, ... suffixes.
  - `validates :slug, presence: true, uniqueness: true`.
  - `to_param` returns `slug`.
  - New `by_location(q)` scope — treats digit-only input as a postal-code prefix (`LIKE '10%'`), everything else as a city substring (`ILIKE '%berlin%'`).

### Routes & controllers

- `config/routes.rb`:
  - `root "public/home#index"` (replaces the milestone-1 placeholder).
  - `get "/practitioners/:slug" => "public/practitioners#show"`, named `public_practitioner`, constrained to `[a-z0-9\-]+`.
- `app/controllers/public/base_controller.rb` — bare `ApplicationController` subclass with `allow_unauthenticated_access`, `layout "public"`, and Pagy backend/frontend wiring.
- `app/controllers/public/home_controller.rb` — the search + results page. Chains `Practitioner.published.by_location(q).with_specialty(id)`, orders by lowercased `full_name`, paginates 12 per page.
- `app/controllers/public/practitioners_controller.rb` — `show` calls `Practitioner.published.find_by!(slug: params[:slug])` (raises `RecordNotFound` → 404 for missing or unpublished).
- Removed `app/controllers/home_controller.rb` and `app/views/home/index.html.erb`.

### Views & helpers

- `app/views/layouts/public.html.erb` — new layout with `.public-header` (brand + sign-in link), Leaflet CDN CSS/JS, standard `.wrapper` main area, and `content_for(:title|:description|:canonical)` hooks in the head.
- `app/views/public/home/index.html.erb` + `_search_form.html.erb` + `_practitioner_card.html.erb` — search hero, form, results grid, empty state, pagination.
- `app/views/public/practitioners/show.html.erb` — profile page: optional claim ribbon, two-column layout (main info left, map right on desktop / single-column on mobile), contact list rendered only when fields are present, Leaflet map rendered only when coordinates exist.
- `app/helpers/public_helper.rb` — `avatar_initial(p)` (strips common titles and returns first letter), `page_description_for(p)` (specialty-aware meta description), `display_name(p)` (salutation + name).

### JavaScript

- `app/javascript/controllers/map_controller.js` extended with `draggableValue` (default `true`). When `false` — marker isn't draggable, no click-to-drop behavior, scrollWheelZoom disabled. The admin edit form is unchanged (defaults to draggable); the public profile passes `data-map-draggable-value="false"`.

### CSS (in `app/assets/stylesheets/application.css`, `@layer component`)

- New: `.wrapper` (moved here — was previously implicit), `.public-header`, `.search-hero`, `.search-form`, `.results-header`, `.results-grid`, `.practitioner-card` (+ nested), `.practitioner-card__avatar` / `.public-profile__avatar` (shared avatar-initial styling), `.chip--muted`, `.empty-state`, `.claim-ribbon`, `.back-link`, `.public-profile` (+ nested), `.contact-list`, `.address-block`.
- Removed: `.coming-soon` styles (dead code — the placeholder home is gone).
- Reused: existing `.chip`, `.btn`, `.map-preview__canvas`, `.pagination`, `.form-field*` classes.

## Decisions made during implementation (not pre-specified in the PRD)

1. **`Practitioner#to_param` returns the slug.** This gives clean URLs both publicly and in admin (e.g. `/admin/practitioners/dr-maria-schmidt-berlin/edit`). Required updating `Admin::PractitionersController#set_practitioner` to `find_by!(slug: params[:id])` — see next note.
2. **Admin URLs now use slug instead of numeric ID.** Follow-on effect of the `to_param` override. Bulk action checkboxes still send integer IDs (unchanged in `_row.html.erb`), so `bulk_publish` / `bulk_unpublish` / `bulk_destroy` continue to work exactly as before. Milestone 3 authors: use `Practitioner.find_by!(slug: params[:id])` in any new admin/practitioner-facing controllers.
3. **Location filter treats digit-only input as a postal-code prefix.** `q=10` matches all PLZ starting with `10`; `q=10178` matches only that exact PLZ (as a prefix of one match). Non-digit input matches city with `ILIKE '%q%'`. Simple and predictable.
4. **Alphabetical sort, no user-facing sort control.** PRD calls for "sensible default sort" and doesn't ask for a sort dropdown. Alphabetical (case-insensitive on `full_name`) is stable and fair — unclaimed and claimed practitioners aren't ranked differently.
5. **Pagination, 12 per page, standard offset pagination.** PRD allows either pagination or "load more". Stayed with Pagy (already installed for the admin list). 12 per page = 3-4 rows on desktop for the auto-fill card grid.
6. **Claim ribbon has no action link yet.** PRD says the ribbon should show on unclaimed profiles. Since the claim CTA lands in milestone 3, the ribbon just displays "Basic listing — [Name], claim your profile" as static copy for now. Milestone 3 replaces the text `claim your profile` (currently a plain `<span>`) with a link to the self-serve claim page (or, if the flow stays admin-triggered per PRD, remove the ribbon phrasing that implies self-serve).
7. **No canonical for the search page.** Only the profile page emits a `<link rel="canonical">`. The homepage/search URL varies by filters; canonicalising it (or not) isn't in scope until we care about crawl budget.
8. **Public site is EN despite German audience.** PRD says the whole UI stays English in v1. Copy on the homepage ("Find an alternative health practitioner", "Any specialty", "City or postal code", "Search") is English; only user-generated content (specialty names, city names, addresses) is German.
9. **Header uses `position: sticky`.** The public header stays visible on scroll — nicer for browsing long result lists. Backdrop-filter blur too, matches modern-directory feel without being flashy.
10. **Empty premium sections are simply absent.** No hidden divs, no "Coming soon" placeholders. The profile page renders only sections whose data exists: no contact block if all three contact fields are empty, no address block if street/PLZ both empty, no map if no coordinates. Milestone 4 will just add more sections above/below without touching the structure.

## Anything the next milestone needs to know

- **Public profile URL helper is `public_practitioner_path(practitioner)`** (or `_url`). Because `to_param` returns slug, passing a `Practitioner` instance is enough — no need to pass `slug:` explicitly. When milestone 3 needs to link to a profile from an email or a claim page, use this helper.
- **The claim ribbon lives in `app/views/public/practitioners/show.html.erb`** (lines around the top `<% unless @practitioner.claimed? %>`). Milestone 3 should either:
  1. Turn the "claim your profile" span into a link if the app supports self-serve claiming, or
  2. Change the copy to just "Basic listing" if claims stay admin-triggered.
- **Slug is generated in a `before_validation` callback.** Renaming a practitioner (or moving them to a different city) will rename their slug too. If milestone 4 lets practitioners edit their own profile, that's fine — but be aware old shared links to their profile will 404 after a rename. If we want slug stability, add a `slug_locked_at` timestamp or freeze on first publish; not needed yet.
- **`Practitioner#by_location` and `#with_specialty` scopes** are the query surface for the public listing. Any new public filter (radius, "near me", etc. — all out of scope for v1) should follow the same lambda pattern with early return for blank input.
- **The map Stimulus controller now honours `data-map-draggable-value`.** Default is `true` (admin behavior); the public profile uses `false`. Milestone 4's practitioner-facing edit form should use the default (`true`), just like the admin form.
- **CSS `.wrapper` is now in the `component` layer** (was implicit before). The public header applies its own background/border and the wrapper only handles inner max-width. Admin layout is unaffected because it uses its own `.admin-shell` grid, not `.wrapper`.
- **The `Public::` namespace is a good home** for any new public-facing controllers (e.g. milestone 4's read-only enhancements to the profile page won't need a new namespace).
- **No public homepage tests yet.** As with milestone 1, all verification was manual (curl walks). Adding a Capybara system spec for the search + click flow would be a low-cost addition when the codebase can tolerate the test-time cost.

## Deviations from the PRD

- **PRD says "Public homepage that doubles as the search entry point"** — implemented as one page (`Public::HomeController#index`), no separate `/search`. The homepage always renders results (all published practitioners when no filters); the filters just narrow them.
- **PRD says "Specialty filter (dropdown / multi-select)".** Went with single-select dropdown per the clarifying question; multi-select can arrive later without breaking URLs (would use `specialty_ids[]`).
- **PRD says "Results list of practitioner cards showing photo/placeholder, name, up to 3 specialty chips, city, tagline snippet".** No photo (photo is a milestone-4 premium field — used an initial-based avatar instead). No tagline (tagline is also premium — omitted, will land in milestone 4). Everything else is present.
- **PRD says "Empty premium sections render nothing (no blank blocks)."** Enforced by design — the show page renders a section only if its data is present. When milestone 4 adds premium sections, the same pattern should apply.
- **PRD says "Subtle 'Basic listing — [Name], claim your profile' ribbon on unclaimed profiles."** Implemented verbatim as a plain informational strip (no self-serve link yet; see decision #6 above).
- **PRD says "Only published practitioners are visible publicly; unpublished ones return 404."** Enforced in `Public::PractitionersController#show` via `Practitioner.published.find_by!(...)`. Verified with curl (unpublished practitioner returns 404).
- **PRD says "Basic SEO: title with name + city, meta description drawn from tagline, clean shareable URL."** Title includes name + city. Since tagline doesn't exist yet, the description is derived from name + specialties + city (see `PublicHelper#page_description_for`). Milestone 4 should switch to tagline once it exists (fall back to the current computed description if tagline is blank).
- **No scope additions.** Reviews/ratings/contact-form/social-share/related-practitioners/structured-data all left out per PRD.

# Support, Contact, and Contribution Links

## Overview

Add links for users to support the project financially, get in touch with the maintainer, and contribute to the open-source codebase.

## Target Audience

Developers only (site uses GitHub OAuth exclusively - no other auth methods).

## UI Placement

### Header Area (Top)

Located in the top navbar, alongside or near the user auth section:

1. **Get in Touch** - LinkedIn profile link
   - URL: `https://linkedin.com/in/mkreyman`
   - Text: "Get in touch" (or just LinkedIn icon with tooltip)

2. **Support Links** - Donation/tip options
   - Stripe Payment Link (primary)
   - GitHub Sponsors link
   - Phrasing options:
     - "Support this project"
     - "☕ Buy me a coffee"
     - "❤️ Sponsor"

### Footer Area (Bottom)

At the very bottom of the page:

1. **Submit an Issue** - Link to GitHub Issues
   - URL: `https://github.com/[username]/diagram_forge/issues`
   - Text: "Report an issue" or "Submit feedback"

2. **Contribute** - Link to repo for contributions
   - URL: `https://github.com/[username]/diagram_forge`
   - Text: "Contribute" or "View source"

## Copy Options

### Support Section (Non-pushy, developer-friendly)

**Option A - Minimal:**
> If DiagramForge saves you time, consider supporting the project.

**Option B - Transparent:**
> This project is free and open source. Tips help cover hosting and development.

**Option C - Very light:**
> ☕ Buy me a coffee

### Footer Section

> Found a bug? [Submit an issue](link) · Want to contribute? [View on GitHub](link)

## Visual Design Considerations

- Keep support links subtle, not salesy
- Use recognizable icons (GitHub, LinkedIn, Stripe/heart)
- Match existing dark theme (slate-800, slate-700, etc.)
- Mobile-responsive placement

## Implementation Details

### Header Component Updates

```heex
<%!-- In navbar, after user section --%>
<div class="flex items-center gap-3 text-sm">
  <a
    href="https://linkedin.com/in/mkreyman"
    target="_blank"
    class="text-slate-400 hover:text-slate-200 transition"
    title="Get in touch"
  >
    <.icon name="hero-..." class="w-5 h-5" /> <%!-- or LinkedIn SVG --%>
  </a>

  <a
    href="[stripe-payment-link]"
    target="_blank"
    class="text-slate-400 hover:text-pink-400 transition"
    title="Support this project"
  >
    <.icon name="hero-heart" class="w-5 h-5" />
  </a>

  <a
    href="https://github.com/sponsors/mkreyman"
    target="_blank"
    class="text-slate-400 hover:text-slate-200 transition"
    title="Sponsor on GitHub"
  >
    <%!-- GitHub Sponsors icon --%>
  </a>
</div>
```

### Footer Component

```heex
<footer class="bg-slate-900 border-t border-slate-800 py-4">
  <div class="container mx-auto px-4 text-center text-sm text-slate-500">
    <div class="flex items-center justify-center gap-4">
      <a
        href="https://github.com/[username]/diagram_forge/issues"
        target="_blank"
        class="hover:text-slate-300 transition"
      >
        Report an issue
      </a>
      <span>·</span>
      <a
        href="https://github.com/[username]/diagram_forge"
        target="_blank"
        class="hover:text-slate-300 transition"
      >
        Contribute
      </a>
    </div>
  </div>
</footer>
```

## External Accounts Needed

- [x] GitHub account (have it)
- [x] Stripe account (have it)
- [ ] Stripe Payment Link created (one-time setup)
- [ ] GitHub Sponsors enabled for repo/profile

## Configuration

Consider making these URLs configurable via environment variables or runtime config:

```elixir
# config/runtime.exs
config :diagram_forge,
  linkedin_url: System.get_env("LINKEDIN_URL", "https://linkedin.com/in/mkreyman"),
  github_repo_url: System.get_env("GITHUB_REPO_URL", "https://github.com/mkreyman/diagram_forge"),
  stripe_support_url: System.get_env("STRIPE_SUPPORT_URL"),
  github_sponsors_url: System.get_env("GITHUB_SPONSORS_URL")
```

---

## Questions / Clarifications

1. **LinkedIn URL format** - You mentioned `linkedin.com/p/mkreyman` but LinkedIn profile URLs are typically `linkedin.com/in/username`. Which is correct?

2. **Header placement** - Should the support/contact links be:
   - Always visible to everyone (including non-logged-in users)?
   - Only visible to logged-in users?
   - In the main navbar or in a separate smaller bar above/below it?

3. **Support link priority** - Which should be more prominent:
   - Stripe Payment Link (one-time tips)?
   - GitHub Sponsors (recurring)?
   - Both equally?

4. **Icons vs text** - For the header links, prefer:
   - Icons only with tooltips (cleaner)?
   - Icons + short text labels (clearer)?
   - Text only?

5. **GitHub repo visibility** - Is the repo public? Need the exact repo URL for the footer links.

6. **Stripe Payment Link** - Do you already have this created, or should I include setup instructions?

7. **Footer content** - Should the footer also include:
   - Copyright notice?
   - "Built with Phoenix/Elixir" badge?
   - Version number?

8. **"Get in touch" purpose** - Is this for:
   - General networking/contact?
   - Business inquiries?
   - Should there be an email option too, or LinkedIn only?

9. **Mobile layout** - On small screens, should these links:
   - Collapse into a menu?
   - Remain visible but icon-only?
   - Move to a different location?

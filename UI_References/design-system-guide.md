# Design System Guide

## Typography Scale

Use a modular scale (ratio 1.25 — Major Third) with a 16px base.

| Token | Size | Line Height | Weight | Use Case |
|-------|------|-------------|--------|----------|
| `display-xl` | 48px / 3rem | 56px / 1.17 | 700 | Hero headlines |
| `display` | 40px / 2.5rem | 48px / 1.2 | 700 | Page titles |
| `heading-1` | 32px / 2rem | 40px / 1.25 | 600 | Section headers |
| `heading-2` | 24px / 1.5rem | 32px / 1.33 | 600 | Subsection headers |
| `heading-3` | 20px / 1.25rem | 28px / 1.4 | 600 | Card titles |
| `body-lg` | 18px / 1.125rem | 28px / 1.56 | 400 | Lead paragraphs |
| `body` | 16px / 1rem | 24px / 1.5 | 400 | Default body text |
| `body-sm` | 14px / 0.875rem | 20px / 1.43 | 400 | Secondary text, captions |
| `caption` | 12px / 0.75rem | 16px / 1.33 | 400 | Labels, timestamps, metadata |
| `overline` | 11px / 0.6875rem | 16px / 1.45 | 600 | Overlines, badges (uppercase + 0.5px tracking) |

### Font Stack

```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
--font-mono: 'JetBrains Mono', 'Fira Code', 'SF Mono', monospace;
```

---

## Spacing Scale (4px base grid)

All spacing uses multiples of 4px for visual consistency.

| Token | Value | Common Use |
|-------|-------|------------|
| `space-0` | 0px | — |
| `space-1` | 4px | Tight inline gaps, icon-to-text |
| `space-2` | 8px | Related elements, input padding-x |
| `space-3` | 12px | Compact list items, small card padding |
| `space-4` | 16px | Default padding, gap between form fields |
| `space-5` | 20px | Medium padding |
| `space-6` | 24px | Card padding, section sub-gaps |
| `space-8` | 32px | Section gaps, large card padding |
| `space-10` | 40px | Section separators |
| `space-12` | 48px | Page section spacing |
| `space-16` | 64px | Major section breaks |
| `space-20` | 80px | Page-level vertical rhythm |
| `space-24` | 96px | Hero/splash spacing |

### Usage Rules

- **Inline spacing** (icon ↔ text): `space-1` to `space-2` (4–8px)
- **Within components** (padding): `space-3` to `space-6` (12–24px)
- **Between components**: `space-4` to `space-8` (16–32px)
- **Between sections**: `space-10` to `space-16` (40–64px)
- **Page margins (mobile)**: `space-4` (16px)
- **Page margins (desktop)**: `space-6` to `space-8` (24–32px)

---

## Layout & Grid

### Container Widths

| Token | Value | Use |
|-------|-------|-----|
| `container-sm` | 640px | Narrow content (auth, settings) |
| `container-md` | 768px | Articles, forms |
| `container-lg` | 1024px | Dashboards |
| `container-xl` | 1280px | Full layouts |

### Breakpoints

| Token | Value |
|-------|-------|
| `mobile` | 0–639px |
| `tablet` | 640–1023px |
| `desktop` | 1024–1279px |
| `wide` | 1280px+ |

### Grid

- **Columns**: 12-column grid (desktop), 4-column (mobile)
- **Gutter**: 16px (mobile), 24px (desktop)
- **Margin**: 16px (mobile), 24–32px (tablet), auto-centered (desktop)

---

## Border Radius

| Token | Value | Use |
|-------|-------|-----|
| `radius-none` | 0px | Sharp edges |
| `radius-sm` | 4px | Badges, tags, chips |
| `radius-md` | 8px | Buttons, inputs, small cards |
| `radius-lg` | 12px | Cards, modals, dropdowns |
| `radius-xl` | 16px | Large cards, sheets |
| `radius-2xl` | 24px | Floating panels |
| `radius-full` | 9999px | Avatars, pills, circular buttons |

---

## Shadows / Elevation

```css
--shadow-xs:   0 1px 2px rgba(0, 0, 0, 0.05);
--shadow-sm:   0 1px 3px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.06);
--shadow-md:   0 4px 6px rgba(0, 0, 0, 0.07), 0 2px 4px rgba(0, 0, 0, 0.06);
--shadow-lg:   0 10px 15px rgba(0, 0, 0, 0.1), 0 4px 6px rgba(0, 0, 0, 0.05);
--shadow-xl:   0 20px 25px rgba(0, 0, 0, 0.1), 0 8px 10px rgba(0, 0, 0, 0.04);
--shadow-2xl:  0 25px 50px rgba(0, 0, 0, 0.15);
```

| Level | Token | Use |
|-------|-------|-----|
| 0 | none | Flat/embedded elements |
| 1 | `shadow-xs` | Subtle lift (cards on white bg) |
| 2 | `shadow-sm` | Buttons, inputs (default) |
| 3 | `shadow-md` | Dropdowns, popovers |
| 4 | `shadow-lg` | Modals, floating cards |
| 5 | `shadow-xl` | Dialogs, toasts |

---

## Color System

### Neutral Palette (use for text, backgrounds, borders)

| Token | Light Mode | Dark Mode | Use |
|-------|-----------|-----------|-----|
| `bg-primary` | `#FFFFFF` | `#0F0F0F` | App background |
| `bg-secondary` | `#F7F7F8` | `#1A1A1B` | Subtle sections |
| `bg-tertiary` | `#EFEFEF` | `#262627` | Hover/active states |
| `border-default` | `#E2E2E5` | `#2E2E30` | Default borders |
| `border-strong` | `#C8C8CC` | `#444447` | Emphasized borders |
| `text-primary` | `#111111` | `#ECECEC` | Headings, body |
| `text-secondary` | `#6B6B6B` | `#9B9B9B` | Descriptions, captions |
| `text-tertiary` | `#999999` | `#666666` | Placeholders, disabled |

### Semantic Colors

| Token | Value | Use |
|-------|-------|-----|
| `primary` | `#2563EB` | CTAs, links, active states |
| `primary-hover` | `#1D4ED8` | Primary hover |
| `primary-light` | `#EFF6FF` | Primary tint/bg |
| `success` | `#16A34A` | Confirmations |
| `success-light` | `#F0FDF4` | Success bg |
| `warning` | `#F59E0B` | Alerts, caution |
| `warning-light` | `#FFFBEB` | Warning bg |
| `error` | `#DC2626` | Errors, destructive |
| `error-light` | `#FEF2F2` | Error bg |
| `info` | `#0EA5E9` | Informational |
| `info-light` | `#F0F9FF` | Info bg |

---

## Component Sizing

### Buttons

| Size | Height | Padding-x | Font | Radius |
|------|--------|-----------|------|--------|
| `sm` | 32px | 12px | 13px / 500 | `radius-md` |
| `md` | 40px | 16px | 14px / 500 | `radius-md` |
| `lg` | 48px | 24px | 16px / 500 | `radius-md` |

- Min-width: 80px (small), 100px (medium), 120px (large)
- Icon-only buttons: square (same width as height)

### Inputs

| Size | Height | Padding-x | Font |
|------|--------|-----------|------|
| `sm` | 32px | 10px | 14px |
| `md` | 40px | 12px | 14px |
| `lg` | 48px | 16px | 16px |

- Border: 1px `border-default`
- Focus ring: 2px offset, `primary` at 25% opacity
- Label: `body-sm` (14px), `space-1` gap below

### Avatars

| Size | Dimensions | Font |
|------|------------|------|
| `xs` | 24px | 10px |
| `sm` | 32px | 12px |
| `md` | 40px | 14px |
| `lg` | 56px | 20px |
| `xl` | 80px | 28px |

### Icon Sizing

| Context | Size |
|---------|------|
| Inline with text | 16px |
| Buttons | 18–20px |
| Navigation | 24px |
| Empty states / illustrations | 48–64px |

---

## Z-Index Scale

| Token | Value | Use |
|-------|-------|-----|
| `z-base` | 0 | Default content |
| `z-dropdown` | 10 | Dropdowns, popovers |
| `z-sticky` | 20 | Sticky headers, nav |
| `z-overlay` | 30 | Overlays, backdrops |
| `z-modal` | 40 | Modals, dialogs |
| `z-toast` | 50 | Toasts, notifications |
| `z-tooltip` | 60 | Tooltips |

---

## Motion / Transitions

```css
--duration-fast:    100ms;
--duration-normal:  200ms;
--duration-slow:    300ms;
--duration-slower:  500ms;

--ease-default:     cubic-bezier(0.4, 0, 0.2, 1);   /* general UI */
--ease-in:          cubic-bezier(0.4, 0, 1, 1);       /* exits */
--ease-out:         cubic-bezier(0, 0, 0.2, 1);       /* entrances */
--ease-bounce:      cubic-bezier(0.34, 1.56, 0.64, 1); /* playful micro-interactions */
```

| Action | Duration | Easing |
|--------|----------|--------|
| Hover/focus | `fast` | `ease-default` |
| Dropdowns, tooltips | `normal` | `ease-out` |
| Modals, sheets | `slow` | `ease-out` |
| Page transitions | `slower` | `ease-default` |

---

## Accessibility Minimums

- **Touch targets**: min 44×44px (mobile), 32×32px (desktop)
- **Contrast**: 4.5:1 for body text, 3:1 for large text (18px+) and UI components
- **Focus indicators**: visible ring (2px, offset 2px) on all interactive elements
- **Motion**: respect `prefers-reduced-motion` — disable non-essential animations
- **Font size**: never below 12px for any readable text

---

## Quick Reference: Common Patterns

| Pattern | Specs |
|---------|-------|
| Card | padding: `space-6`, radius: `radius-lg`, border: 1px `border-default`, shadow: `shadow-xs` |
| Modal | padding: `space-6` to `space-8`, radius: `radius-xl`, shadow: `shadow-xl`, max-width: 480px |
| Toast | padding: `space-3` `space-4`, radius: `radius-lg`, shadow: `shadow-lg`, max-width: 400px |
| Nav item | height: 40px, padding-x: `space-3`, radius: `radius-md`, gap: `space-2` |
| Divider | 1px `border-default`, margin-y: `space-4` to `space-8` |
| Form group | gap between fields: `space-4`, gap between sections: `space-8` |
| Page layout | top padding: `space-8` to `space-12`, side padding: `space-4` (mobile) / `space-8` (desktop) |

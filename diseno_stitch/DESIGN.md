---
name: AgroDrone
colors:
  surface: '#041710'
  surface-dim: '#041710'
  surface-bright: '#293d35'
  surface-container-lowest: '#01110b'
  surface-container-low: '#0b1f18'
  surface-container: '#10231c'
  surface-container-high: '#1a2e26'
  surface-container-highest: '#253931'
  on-surface: '#d1e8dc'
  on-surface-variant: '#bec9c0'
  inverse-surface: '#d1e8dc'
  inverse-on-surface: '#21342c'
  outline: '#88938b'
  outline-variant: '#3f4943'
  surface-tint: '#85d7ad'
  primary: '#8fe2b8'
  on-primary: '#003824'
  primary-container: '#74c69d'
  on-primary-container: '#005236'
  inverse-primary: '#0e6c4a'
  secondary: '#95d4b3'
  on-secondary: '#003824'
  secondary-container: '#12533a'
  on-secondary-container: '#87c6a5'
  tertiary: '#b0dbc3'
  on-tertiary: '#0e3727'
  tertiary-container: '#95bfa8'
  on-tertiary-container: '#274e3d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#a0f4c8'
  primary-fixed-dim: '#85d7ad'
  on-primary-fixed: '#002113'
  on-primary-fixed-variant: '#005236'
  secondary-fixed: '#b1f0ce'
  secondary-fixed-dim: '#95d4b3'
  on-secondary-fixed: '#002114'
  on-secondary-fixed-variant: '#0e5138'
  tertiary-fixed: '#c1ecd4'
  tertiary-fixed-dim: '#a5d0b9'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#274e3d'
  background: '#041710'
  on-background: '#d1e8dc'
  surface-variant: '#253931'
typography:
  display:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  gutter: 16px
  margin-mobile: 20px
---

## Brand & Style

The design system is built on the "Natural Tech" aesthetic—a sophisticated intersection of precision agriculture and aerospace engineering. The brand personality is authoritative yet eco-conscious, aiming to evoke a sense of reliability and environmental stewardship. 

The visual style utilizes a **Modern Corporate** foundation with **Tactile** influences. It balances high-density data visualization with soft, organic interface elements. The UI focuses on high legibility in outdoor environments (high sun exposure) while maintaining a premium, "dark-mode first" aesthetic that reflects the advanced nature of autonomous drone flight.

## Colors

This design system uses a palette rooted in "Deep Forest" tones to ground the high-tech hardware in its natural environment.

- **Primary (#74C69D):** A vibrant "Leaf Green" used for calls to action, active states, and drone flight paths. It is optimized for high visibility against dark backgrounds.
- **Secondary/Tertiary (#2D6A4F, #1B4332):** These deeper greens form the structural layer of the app, used for containers and secondary navigation.
- **Neutral/Background (#081C15, #121212):** Rich matte blacks provide a "cockpit" feel, reducing eye strain during field operations and ensuring the green accents pop.
- **Functional Colors:** Success (Primary Green), Warning (Amber/Gold for low battery), and Danger (Bright Red for flight obstacles).

## Typography

The design system employs **Inter** for its exceptional readability and systematic feel. The type hierarchy is designed for "at-a-glance" comprehension, which is critical for field operators monitoring drone telemetry.

Headlines use tighter letter spacing to feel more "engineered," while labels utilize uppercase tracking to differentiate status indicators from descriptive text. Use high-contrast white or off-white (#F0F0F0) for body copy to ensure visibility against the deep green and black backgrounds.

## Layout & Spacing

This design system uses a **Fluid Grid** model optimized for mobile devices. 

- **Grid:** A 4-column grid for mobile with 16px gutters.
- **Safe Zones:** Generous 20px margins on the left and right to prevent accidental taps when holding mobile devices in field conditions.
- **Rhythm:** An 8px linear scale (referenced as `base * x`) governs all vertical spacing to maintain a clean, rhythmic structure.
- **Stacking:** Use "Surface-on-Surface" layouts where cards are separated by 12px or 16px to create clear logical groupings of telemetry data.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** combined with **Ambient Shadows**. 

- **Level 0 (Background):** Pure Matte Black (#121212).
- **Level 1 (Cards/Containers):** Deep Forest (#1B4332) with a very subtle, diffused black shadow (0px 4px 20px rgba(0,0,0,0.4)).
- **Level 2 (Active States/Modals):** Lighter Green (#2D6A4F) to suggest proximity to the user.
- **Interaction:** Buttons do not use heavy gradients; instead, they use a slight "inner glow" or bright borders to signify they are interactive "flight controls."

## Shapes

The shape language is defined by a consistent **16px radius (rounded-lg)** for all primary containers and cards. This softens the "industrial" feel of the app, aligning it with the "Natural" side of the brand.

Secondary elements like buttons and input fields follow an 8px radius to feel more precise and technical. Progress bars and status tags utilize a **Pill-shaped (rounded-xl)** geometry to distinguish them from structural layout components.

## Components

### Buttons
- **Primary:** Solid #74C69D with #081C15 text. Bold, sans-serif, uppercase.
- **Secondary:** Outlined with a 1.5px stroke of #74C69D.
- **Emergency:** Solid Red, reserved exclusively for "Return to Home" or "Emergency Stop."

### Cards
Cards are the primary container. They must have a 16px corner radius and a background of #1B4332. Use 16px internal padding. Data points within cards should be separated by thin, low-opacity dividers (rgba(255,255,255,0.1)).

### Input Fields
Dark backgrounds (#081C15) with a #2D6A4F border. On focus, the border transitions to #74C69D with a soft outer glow.

### Telemetry Chips
Small, pill-shaped indicators for "Battery %," "GPS Signal," and "Tank Level." Use the Primary Green for healthy levels, transitioning to Amber and Red as thresholds are crossed.

### Icons
Use **Thin-line (1.5px weight)** icons. Icons should be modern and minimalist. 
- Agriculture: Sprout, droplet, field/map.
- Aviation: Propeller, signal-strength, navigation-arrow, battery-bolt.

### Map Elements
The map should use a custom "Dark Satellite" skin. Drone flight paths are rendered as 2px solid lines in #74C69D with a soft neon outer glow to ensure visibility over varied terrain textures.
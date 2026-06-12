/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: '#050816',
        primary: '#1E1E2C',
        secondary: '#292940',
        accent: '#3B82F6', // Neon blue
        accentPurple: '#8B5CF6',
        text: '#F3F4F6',
        textMuted: '#9CA3AF',
        void: '#000000',
        carbon: '#050505',
        graphite: '#0D0D0D',
        smoke: '#1A1A1A',
        cyan: '#00FFFF',
        plasma: '#BF5AF2',
        acid: '#DFFF00',
        ember: '#FF6B35',
      },
      fontFamily: {
        hero: ['Space Grotesk', 'sans-serif'],
        body: ['DM Sans', 'sans-serif'],
        serif: ['Cormorant Garamond', 'serif'],
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'glass-gradient': 'linear-gradient(135deg, rgba(255, 255, 255, 0.05) 0%, rgba(255, 255, 255, 0.01) 100%)',
      },
      boxShadow: {
        'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
        'neon': '0 0 10px rgba(59, 130, 246, 0.5), 0 0 20px rgba(59, 130, 246, 0.3)',
      },
      backdropBlur: {
        'glass': '12px',
      }
    },
  },
  plugins: [],
}

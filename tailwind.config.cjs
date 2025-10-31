/** @type {import('tailwindcss').Config} */
export default {
  // Content paths for Tailwind to scan.
  content: [
    "./index.html",
    "./App.tsx",
    "./index.tsx",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],

  // Plugins to be loaded.
  plugins: [
    // Using the string-based import is the standard and most robust method.
    require('@tailwindcss/typography'),
  ],

  // Theme customization.
  theme: {
    // Use 'extend' to add to Tailwind's default theme
    // without overriding it.
    extend: {
      // Add custom animations.
      // This defines the animation names that can be used in your CSS/JSX.
      animation: {
        'star-movement-bottom': 'star-movement-bottom linear infinite alternate',
        'star-movement-top': 'star-movement-top linear infinite alternate',
      },

      // Define the keyframes for the custom animations above.
      // This is the actual "how-to" for the animation.
      keyframes: {
        'star-movement-bottom': {
          '0%': { transform: 'translate(0%, 0%)', opacity: '1' },
          '100%': { transform: 'translate(-100%, 0%)', opacity: '0' },
        },
        'star-movement-top': {
          '0%': { transform: 'translate(0%, 0%)', opacity: '1' },
          '100%': { transform: 'translate(100%, 0%)', opacity: '0' },
        },
      },
    },
  },
};

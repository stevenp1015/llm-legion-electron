
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

// Help React DevTools detect React
if (typeof window !== 'undefined') {
  // Only set the hook if it doesn't already exist (avoid read-only errors)
  if (!(window as any).__REACT_DEVTOOLS_GLOBAL_HOOK__) {
    try {
      (window as any).__REACT_DEVTOOLS_GLOBAL_HOOK__ = {};
    } catch (e) {
      console.log('🤷‍♂️ DevTools hook already exists and is read-only - this is normal');
    }
  }
  
  // Expose React to global scope for DevTools (these should always work)
  try {
    (window as any).React = React;
    (window as any).ReactDOM = ReactDOM;
  } catch (e) {
    console.log('🤷‍♂️ Could not expose React to global scope:', e.message);
  }
  
  console.log('🔍 React DevTools detection helpers added');
  console.log('React version:', React.version);
  console.log('DevTools hook exists:', !!(window as any).__REACT_DEVTOOLS_GLOBAL_HOOK__);
}

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
    
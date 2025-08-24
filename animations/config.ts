// Centralized animation configuration
// Because having animations scattered everywhere is fucking chaos

export const ANIMATION_DURATION = {
  instant: 0.1,
  fast: 0.2,
  normal: 0.3,
  slow: 0.5,
};

export const SPRING_CONFIG = {
  // For UI elements that need to feel responsive
  snappy: { 
    type: 'spring' as const, 
    stiffness: 500, 
    damping: 30,
    mass: 0.8
  },
  // For smooth, gentle animations
  gentle: { 
    type: 'spring' as const, 
    stiffness: 300, 
    damping: 30,
    mass: 1
  },
  // For bouncy, playful animations
  bouncy: { 
    type: 'spring' as const, 
    stiffness: 400, 
    damping: 20,
    mass: 1,
    bounce: 0.3
  },
  // For stiff, immediate responses
  stiff: {
    type: 'spring' as const,
    stiffness: 1000,
    damping: 30,
    mass: 0.5
  }
};

export const EASING = {
  easeOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  easeIn: [0.4, 0, 1, 1] as [number, number, number, number],
  easeInOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  linear: [0, 0, 1, 1] as [number, number, number, number],
};

// Reduced motion check for accessibility
export const prefersReducedMotion = () => {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
};

// Get animation config based on user preference
export const getAnimationConfig = (type: keyof typeof SPRING_CONFIG) => {
  if (prefersReducedMotion()) {
    return { duration: 0.01 }; // Nearly instant for reduced motion
  }
  return SPRING_CONFIG[type];
};

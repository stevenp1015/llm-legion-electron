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
  },
  // For satisfying button presses
  haptic: {
    type: 'spring' as const,
    stiffness: 800,
    damping: 25,
    mass: 0.6
  },
  // For morphing/shape changes
  morph: {
    type: 'spring' as const,
    stiffness: 350,
    damping: 35,
    mass: 0.9
  },
  // For elastic, rubber-band feel
  elastic: {
    type: 'spring' as const,
    stiffness: 200,
    damping: 15,
    mass: 1.2,
    bounce: 0.6
  },
  // For smooth slides and position changes
  slide: {
    type: 'spring' as const,
    stiffness: 450,
    damping: 40,
    mass: 0.7
  }
};

export const EASING = {
  easeOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  easeIn: [0.4, 0, 1, 1] as [number, number, number, number],
  easeInOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  linear: [0, 0, 1, 1] as [number, number, number, number],
};

// Cached reduced motion check for accessibility
// Listens for changes to invalidate cache
let _prefersReducedMotion: boolean | null = null;
let _motionMediaQuery: MediaQueryList | null = null;

export const prefersReducedMotion = () => {
  if (_prefersReducedMotion !== null) return _prefersReducedMotion;
  if (typeof window === 'undefined') return false;
  
  _motionMediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  _prefersReducedMotion = _motionMediaQuery.matches;
  
  // Listen for changes and invalidate cache
  _motionMediaQuery.addEventListener('change', (e) => {
    _prefersReducedMotion = e.matches;
    _cachedVariants = null; // Invalidate variants cache too
  });
  
  return _prefersReducedMotion;
};

// Get animation config based on user preference
export const getAnimationConfig = (type: keyof typeof SPRING_CONFIG) => {
  if (prefersReducedMotion()) {
    return { duration: 0.01 }; // Nearly instant for reduced motion
  }
  return SPRING_CONFIG[type];
};

// Cached animation variants - rebuilt only when motion preference changes
let _cachedVariants: ReturnType<typeof buildAnimationVariants> | null = null;

function buildAnimationVariants() {
  return {
    // Channel selection with smooth slide + morph
    channelSelection: {
      inactive: { 
        scale: 1,
        opacity: 0,
        x: -8,
        transition: getAnimationConfig('snappy')
      },
      active: { 
        scale: 1,
        opacity: 1,
        x: 0,
        transition: getAnimationConfig('morph')
      },
      hover: {
        scale: 1.02,
        transition: getAnimationConfig('haptic')
      }
    },
    
    // Message entrance with satisfying bounce
    messageEntry: {
      hidden: { 
        opacity: 0, 
        scale: 1
      },
      visible: { 
        opacity: 1, 
        scale: 1,
        transition: {
          ...getAnimationConfig('elastic'),
          filter: { duration: 0.3 }
        }
      },
      exit: { 
        opacity: 0,
        transition: getAnimationConfig('elastic')
      }
    },

    // Button interactions that feel tactile
    button: {
      idle: { scale: 1, opacity: 0.8 },
      hover: { 
        scale: 1.1, 
        opacity: 1,
        transition: getAnimationConfig('stiff')
      },
      tap: { 
        scale: 0.9,
        transition: { 
          ...getAnimationConfig('stiff'),
          duration: 0.1
        }
      }
    },

    // Typing indicator with personality
    typing: {
      animate: {
        scale: [1, 1.2, 1],
        opacity: [0.5, 1, 0.5],
        transition: {
          duration: 1.2,
          repeat: Infinity,
          ease: 'easeInOut'
        }
      }
    },

    // Modal/panel slide-in
    panel: {
      hidden: { 
        opacity: 0,
        x: 300,
        scale: 0.9
      },
      visible: { 
        opacity: 1,
        x: 0,
        scale: 1,
        transition: getAnimationConfig('slide')
      }
    }
  } as const;
}

// Getter that returns cached variants, rebuilding only when needed
export const getAnimationVariants = () => {
  if (!_cachedVariants) {
    _cachedVariants = buildAnimationVariants();
  }
  return _cachedVariants;
};

// Keep backward compat: ANIMATION_VARIANTS is still exported but now dynamic
export const ANIMATION_VARIANTS = new Proxy({} as ReturnType<typeof buildAnimationVariants>, {
  get(_target, prop: string) {
    return getAnimationVariants()[prop as keyof ReturnType<typeof buildAnimationVariants>];
  }
});

// Shimmer effect for loading states
export const shimmerKeyframes = {
  '0%': { transform: 'translateX(-100%)' },
  '100%': { transform: 'translateX(100%)' }
};

// Utility for staggered animations
export const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
      delayChildren: 0.2
    }
  }
};
